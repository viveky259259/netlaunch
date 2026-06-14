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
  // Prefer structured GaxiosError fields when present.
  const e = err as { status?: unknown; code?: unknown; response?: { status?: unknown; data?: { error?: unknown } } };
  const status =
    typeof e?.status === 'number' ? e.status :
    typeof e?.response?.status === 'number' ? e.response.status : undefined;
  // Token-endpoint server errors / rate limits are transient.
  if (status !== undefined && (status >= 500 || status === 429)) return true;

  const code = typeof e?.code === 'string' ? e.code.toUpperCase() : '';
  if (['ETIMEDOUT', 'ECONNRESET', 'ENOTFOUND', 'EAI_AGAIN', 'ECONNREFUSED'].includes(code)) return true;

  // A freshly minted key still propagating returns OAuth `invalid_grant`
  // ("Invalid JWT Signature"). A revoked/malformed key returns the SAME thing,
  // so this case is genuinely ambiguous — we retry, then (caller) save with a
  // warning rather than hard-fail. Malformed-PEM errors don't match here and
  // are treated as permanent (no retry).
  const oauthErr = String(e?.response?.data?.error ?? '').toLowerCase();
  const msg = (err instanceof Error ? err.message : String(err)).toLowerCase();
  return (
    oauthErr === 'invalid_grant' ||
    msg.includes('invalid_grant') ||
    msg.includes('invalid jwt signature') ||
    msg.includes('invalid jwt')
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
  let response: Response;
  try {
    response = await fetch(
      `https://firebasehosting.googleapis.com/v1beta1/projects/${projectId}/sites`,
      { method: 'GET', headers: { 'Authorization': `Bearer ${token}` } }
    );
  } catch (err) {
    // Transport failure (network) — transient, keep the save best-effort.
    return {
      verified: false,
      warning: `Saved, but the Hosting check could not complete (network error: ${errMsg(err)}). Your first deploy will confirm the key.`,
    };
  }

  if (response.ok) return { verified: true };

  const errorText = await response.text();
  if (response.status === 403) {
    throw new Error('Service account lacks Firebase Hosting permissions. Enable the Firebase Hosting API and grant the "Firebase Hosting Admin" role.');
  }
  // Other 4xx (400/401/404 …) mean permanent misconfiguration — a wrong
  // projectId or a project/service-account mismatch — so reject rather than
  // persist a broken config. Only 429 / 5xx are treated as transient.
  if (response.status >= 400 && response.status < 500 && response.status !== 429) {
    throw new Error(`Service account could not access Firebase Hosting for project "${projectId}" (HTTP ${response.status}): ${errorText}`);
  }
  return {
    verified: false,
    warning: `Saved, but a transient Hosting check error occurred (HTTP ${response.status}). Your first deploy will confirm the key.`,
  };
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
