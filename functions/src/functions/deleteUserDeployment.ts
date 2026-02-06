import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

interface DeleteUserDeploymentRequest {
  deploymentId: string;
}

export const deleteUserDeployment = async (
  data: DeleteUserDeploymentRequest,
  context: functions.https.CallableContext
): Promise<{ success: boolean; message: string }> => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to delete a deployment.'
    );
  }
  
  if (!data.deploymentId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Deployment ID is required'
    );
  }
  
  const userId = context.auth.uid;
  
  // Get the deployment
  const deploymentRef = db.collection('deployments').doc(data.deploymentId);
  const deployment = await deploymentRef.get();
  
  if (!deployment.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'Deployment not found'
    );
  }
  
  const deploymentData = deployment.data();
  
  // Verify the deployment belongs to this user
  if (deploymentData?.userId !== userId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You do not have permission to delete this deployment'
    );
  }
  
  // Delete the deployment
  await deploymentRef.delete();
  
  // TODO: Also delete the hosted files from Firebase Hosting
  
  return {
    success: true,
    message: 'Deployment deleted successfully',
  };
};
