import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { validateApiKey } from '../services/apiKeyService';

const db = admin.firestore();

interface DeleteDeploymentRequest {
  apiKey: string;
  deploymentId: string;
}

export const deleteDeployment = async (
  data: DeleteDeploymentRequest,
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
  
  // Verify deployment belongs to this API key
  const deploymentDoc = await db.collection('deployments').doc(data.deploymentId).get();
  
  if (!deploymentDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Deployment not found');
  }
  
  const deploymentData = deploymentDoc.data();
  if (deploymentData?.apiKey !== data.apiKey) {
    throw new functions.https.HttpsError('permission-denied', 'Deployment does not belong to this API key');
  }
  
  // Delete deployment files from Storage
  const bucket = admin.storage().bucket();
  const deploymentPath = `deployments/${data.deploymentId}`;
  
  try {
    const [files] = await bucket.getFiles({ prefix: deploymentPath });
    await Promise.all(files.map(file => file.delete()));
  } catch (error) {
    console.error(`Error deleting deployment files: ${error}`);
  }
  
  // Delete deployment document
  await db.collection('deployments').doc(data.deploymentId).delete();
  
  return {
    success: true,
    message: 'Deployment deleted successfully',
  };
};

