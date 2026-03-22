import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Get the user's saved Firebase project configuration.
 * Returns project ID and client email (never the private key).
 */
export const getFirebaseConfig = async (
  _data: any,
  context: functions.https.CallableContext
): Promise<any> => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }

  const db = admin.firestore();
  const doc = await db.collection('firebaseConfigs').doc(context.auth.uid).get();

  if (!doc.exists) {
    return { hasConfig: false };
  }

  const data = doc.data()!;
  return {
    hasConfig: true,
    projectId: data.projectId,
    clientEmail: data.clientEmail,
    savedAt: data.savedAt?.toDate?.()?.toISOString(),
    updatedAt: data.updatedAt?.toDate?.()?.toISOString(),
  };
};
