import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

interface ListUserDeploymentsRequest {
  limit?: number;
}

export const listUserDeployments = async (
  data: ListUserDeploymentsRequest,
  context: functions.https.CallableContext
): Promise<any> => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to view your deployments.'
    );
  }
  
  const userId = context.auth.uid;
  
  // Query deployments directly by userId
  let query = db.collection('deployments')
    .where('userId', '==', userId)
    .orderBy('createdAt', 'desc');
  
  if (data.limit) {
    query = query.limit(data.limit);
  }
  
  const snapshot = await query.get();
  
  const deployments = snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    createdAt: doc.data().createdAt?.toDate?.()?.toISOString(),
    updatedAt: doc.data().updatedAt?.toDate?.()?.toISOString(),
  }));
  
  return {
    deployments: deployments,
    count: deployments.length,
  };
};
