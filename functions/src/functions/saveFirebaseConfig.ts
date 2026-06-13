import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { JWT } from 'google-auth-library';

interface SaveFirebaseConfigRequest {
  serviceAccountJson: string;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * A freshly created service-account key isn't usable immediately — Google's
 * OAuth backend can take several seconds (occasionally up to ~a minute) to
 * propagate the new key, during which the JWT exchange fails with
 * `invalid_grant: Invalid JWT Signature` (or a transient 5xx). These are
 * retryable; a genuinely wrong key keeps returning the same error.
 */
function isTransientAuthError(err: unknown): boolean {
  const msg = (err instanceof Error ? err.message : String(err)).toLowerCase();
  return (
    msg.includes('invalid_grant') ||
    msg.includes('invalid jwt signature') ||
    msg.includes('invalid jwt') ||
    msg.includes('etimedout') ||
    msg.includes('econnreset')
  );
}

/**
 * Mint an access token for the service account, retrying through new-key
 * propagation delays before giving up.
 */
async function mintAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  // ~0s, 2s, 5s, 9s, 14s — covers typical new-key propagation without blowing
  // the callable function timeout.
  const delays = [0, 2000, 3000, 4000, 5000];
  let lastErr: unknown;
  for (let attempt = 0; attempt < delays.length; attempt++) {
    if (delays[attempt]) await sleep(delays[attempt]);
    const client = new JWT({
      email: clientEmail,
      key: privateKey,
      scopes: ['https://www.googleapis.com/auth/firebase.hosting'],
    });
    try {
      const tokenResponse = await client.getAccessToken();
      if (tokenResponse.token) return tokenResponse.token;
      lastErr = new Error('Could not authenticate with the provided service account.');
    } catch (err) {
      lastErr = err;
      if (!isTransientAuthError(err)) break; // permanent failure — stop early
      console.warn(`saveFirebaseConfig: token mint attempt ${attempt + 1} failed (transient), retrying: ${err instanceof Error ? err.message : err}`);
    }
  }
  const detail = lastErr instanceof Error ? lastErr.message : String(lastErr);
  if (isTransientAuthError(lastErr)) {
    throw new Error(
      'Could not authenticate with the service account yet — a newly created key can take up to a minute to activate. Please retry in a moment. ' +
      `(${detail})`
    );
  }
  throw new Error(`Could not authenticate with the provided service account: ${detail}`);
}

/**
 * Validate a service account JSON by minting a token (with retry through
 * new-key propagation) and listing Firebase Hosting sites.
 */
async function validateServiceAccount(
  projectId: string,
  clientEmail: string,
  privateKey: string
): Promise<void> {
  const token = await mintAccessToken(clientEmail, privateKey);

  // Test: list hosting sites on the project
  const response = await fetch(
    `https://firebasehosting.googleapis.com/v1beta1/projects/${projectId}/sites`,
    {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${token}` },
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    if (response.status === 403) {
      throw new Error('Service account lacks Firebase Hosting permissions. Enable the Firebase Hosting API and grant the "Firebase Hosting Admin" role.');
    }
    throw new Error(`Failed to access Firebase Hosting: ${errorText}`);
  }
}

/**
 * Save (or update) the user's Firebase project configuration.
 * Validates the service account before saving.
 */
export const saveFirebaseConfig = async (
  data: SaveFirebaseConfigRequest,
  context: functions.https.CallableContext
): Promise<any> => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }

  const { serviceAccountJson } = data;
  if (!serviceAccountJson) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing serviceAccountJson.');
  }

  let parsed: any;
  try {
    parsed = JSON.parse(serviceAccountJson);
  } catch {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid JSON.');
  }

  const { project_id, client_email, private_key, type } = parsed;

  if (type !== 'service_account') {
    throw new functions.https.HttpsError('invalid-argument', 'JSON must be a service account key (type: "service_account").');
  }
  if (!project_id || !client_email || !private_key) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: project_id, client_email, private_key.');
  }

  // Validate credentials actually work
  try {
    await validateServiceAccount(project_id, client_email, private_key);
  } catch (err) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      err instanceof Error ? err.message : 'Validation failed.'
    );
  }

  // Save to Firestore (one config per user)
  const db = admin.firestore();
  await db.collection('firebaseConfigs').doc(context.auth.uid).set({
    projectId: project_id,
    clientEmail: client_email,
    privateKey: private_key,
    savedAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  });

  return {
    success: true,
    projectId: project_id,
    clientEmail: client_email,
    message: `Firebase config saved for project "${project_id}".`,
  };
};
