import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { validateApiKey } from '../services/apiKeyService';

const db = admin.firestore();

interface GetDeploymentStatusRequest {
  apiKey: string;
  deploymentId: string;
}

export const getDeploymentStatus = async (
  data: GetDeploymentStatusRequest,
  context: functions.https.CallableContext
): Promise<any> => {
  // Validate API key
  if (!data.apiKey) {
    throw new functions.https.HttpsError('invalid-argument', 'API key is required');
  }
  
  if (!data.deploymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'Deployment ID is required');
  }
  
  const isValid = await validateApiKey(data.apiKey);
  if (!isValid) {
    throw new functions.https.HttpsError('unauthenticated', 'Invalid API key');
  }
  
  // Get deployment
  const deploymentDoc = await db.collection('deployments').doc(data.deploymentId).get();
  
  if (!deploymentDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Deployment not found');
  }
  
  const deploymentData = deploymentDoc.data();

  // Verify deployment belongs to this API key (compare hashes — the raw key is
  // never stored).
  const apiKeyHash = crypto.createHash('sha256').update(data.apiKey).digest('hex');
  if (deploymentData?.apiKeyHash !== apiKeyHash) {
    throw new functions.https.HttpsError('permission-denied', 'Deployment does not belong to this API key');
  }

  // Never return secret fields to the client.
  const { apiKey: _apiKey, apiKeyHash: _apiKeyHash, ...safeData } = deploymentData ?? {};

  return {
    id: deploymentDoc.id,
    ...safeData,
    createdAt: deploymentData?.createdAt?.toDate?.()?.toISOString(),
    updatedAt: deploymentData?.updatedAt?.toDate?.()?.toISOString(),
  };
};

