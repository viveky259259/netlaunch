import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { JWT } from 'google-auth-library';

interface SaveFirebaseConfigRequest {
  serviceAccountJson: string;
}

/**
 * Validate a service account JSON by attempting to mint a token
 * and listing Firebase Hosting sites.
 */
async function validateServiceAccount(
  projectId: string,
  clientEmail: string,
  privateKey: string
): Promise<void> {
  const client = new JWT({
    email: clientEmail,
    key: privateKey,
    scopes: ['https://www.googleapis.com/auth/firebase.hosting'],
  });

  const tokenResponse = await client.getAccessToken();
  if (!tokenResponse.token) {
    throw new Error('Could not authenticate with the provided service account.');
  }

  // Test: list hosting sites on the project
  const response = await fetch(
    `https://firebasehosting.googleapis.com/v1beta1/projects/${projectId}/sites`,
    {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${tokenResponse.token}` },
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
