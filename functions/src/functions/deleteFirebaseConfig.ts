import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Delete the user's saved Firebase project configuration.
 * Future deploys will use the default NetLaunch project.
 */
export const deleteFirebaseConfig = async (
  _data: any,
  context: functions.https.CallableContext
): Promise<any> => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }

  const db = admin.firestore();
  const docRef = db.collection('firebaseConfigs').doc(context.auth.uid);
  const doc = await docRef.get();

  if (!doc.exists) {
    return { success: true, message: 'No config to delete.' };
  }

  await docRef.delete();
  return { success: true, message: 'Firebase config removed. Deploys will use NetLaunch hosting.' };
};
