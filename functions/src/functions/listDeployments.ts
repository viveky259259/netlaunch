import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { validateApiKey } from '../services/apiKeyService';

const db = admin.firestore();

interface ListDeploymentsRequest {
  apiKey: string;
  limit?: number;
}

export const listDeployments = async (
  data: ListDeploymentsRequest,
  context: functions.https.CallableContext
): Promise<any> => {
  // Validate API key
  if (!data.apiKey) {
    throw new functions.https.HttpsError('invalid-argument', 'API key is required');
  }
  
  const isValid = await validateApiKey(data.apiKey);
  if (!isValid) {
    throw new functions.https.HttpsError('unauthenticated', 'Invalid API key');
  }
  
  // Query deployments for this API key
  let query = db.collection('deployments')
    .where('apiKey', '==', data.apiKey)
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
    deployments,
    count: deployments.length,
  };
};

