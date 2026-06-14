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

class AuthError extends Error {
  readonly transient: boolean;
  constructor(message: string, transient: boolean) {
    super(message);
    this.transient = transient;
  }
}

const errMsg = (e: unknown) => (e instanceof Error ? e.message : String(e));

/**
 * Mint an access token for the service account, retrying through new-key
 * propagation delays. Throws AuthError({transient}); transient=true means the
 * key may just not be active yet (the caller should not hard-fail on it).
 */
async function mintAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  // ~0,2,4,6,8,10s ≈ 30s budget — covers most new-key propagation while staying
  // under the callable timeout.
  const delays = [0, 2000, 4000, 6000, 8000, 10000];
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
      lastErr = new Error('Empty token response from Google.');
    } catch (err) {
      lastErr = err;
      if (!isTransientAuthError(err)) {
        // Permanent (e.g. malformed PEM private_key) — stop immediately.
        throw new AuthError(`Could not authenticate with the service account: ${errMsg(err)}`, false);
      }
      console.warn(`saveFirebaseConfig: token mint attempt ${attempt + 1} transient, retrying: ${errMsg(err)}`);
    }
  }
  throw new AuthError(`Could not verify the service-account key yet: ${errMsg(lastErr)}`, true);
}

interface ValidationResult {
  verified: boolean;
  warning?: string;
}

/**
 * Validate a service account by minting a token and listing Hosting sites.
 * NEVER hard-fails on a transient/propagation error — those return
 * {verified:false, warning} so the config still saves (a freshly minted key is
 * often valid but not yet active; the first deploy confirms it). Only clearly
 * permanent problems (malformed key, missing Hosting permission) throw.
 */
async function validateServiceAccount(
  projectId: string,
  clientEmail: string,
  privateKey: string
): Promise<ValidationResult> {
  let token: string;
  try {
    token = await mintAccessToken(clientEmail, privateKey);
  } catch (err) {
    if (err instanceof AuthError && err.transient) {
      return {
        verified: false,
        warning:
          'The key could not be verified yet — a newly created key can take up to a minute to activate. ' +
          'Your config was saved; the first deploy will confirm it. If deploys keep failing, generate a fresh ' +
          'private key in the Firebase console (Project settings → Service accounts) and re-upload.',
      };
    }
    throw err; // permanent — surface to the caller
  }

  // Token minted — check Hosting access.
  const response = await fetch(
    `https://firebasehosting.googleapis.com/v1beta1/projects/${projectId}/sites`,
    { method: 'GET', headers: { 'Authorization': `Bearer ${token}` } }
  );
  if (response.ok) return { verified: true };

  const errorText = await response.text();
  if (response.status === 403) {
    throw new Error('Service account lacks Firebase Hosting permissions. Enable the Firebase Hosting API and grant the "Firebase Hosting Admin" role.');
  }
  // Non-permission Hosting errors shouldn't block the save.
  return { verified: false, warning: `Saved, but a Hosting check returned an error (${response.status}): ${errorText}` };
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

  // Validate — but only PERMANENT problems (malformed key, missing Hosting
  // permission) block the save. A still-propagating key saves with a warning.
  let validation: ValidationResult;
  try {
    validation = await validateServiceAccount(project_id, client_email, private_key);
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
    verified: validation.verified,
    savedAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  });

  return {
    success: true,
    projectId: project_id,
    clientEmail: client_email,
    verified: validation.verified,
    warning: validation.warning,
    message: validation.verified
      ? `Firebase config saved for project "${project_id}".`
      : `Firebase config saved for project "${project_id}". ${validation.warning}`,
  };
};
