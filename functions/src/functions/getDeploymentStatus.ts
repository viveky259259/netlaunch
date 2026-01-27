import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
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
  
  // Verify deployment belongs to this API key
  if (deploymentData?.apiKey !== data.apiKey) {
    throw new functions.https.HttpsError('permission-denied', 'Deployment does not belong to this API key');
  }
  
  return {
    id: deploymentDoc.id,
    ...deploymentData,
    createdAt: deploymentData?.createdAt?.toDate?.()?.toISOString(),
    updatedAt: deploymentData?.updatedAt?.toDate?.()?.toISOString(),
  };
};

