import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

import { onFileUpload } from './functions/onFileUpload';
import { listDeployments } from './functions/listDeployments';
import { listUserDeployments } from './functions/listUserDeployments';
import { deleteDeployment } from './functions/deleteDeployment';
import { deleteUserDeployment } from './functions/deleteUserDeployment';
import { getDeploymentStatus } from './functions/getDeploymentStatus';
import { generateApiKeyFunction } from './functions/generateApiKey';
import { trackPageViewHandler } from './functions/trackPageView';
import { getDeploymentAnalytics } from './functions/getDeploymentAnalytics';
import { cliDeployHandler } from './functions/cliDeploy';
import { saveFirebaseConfig } from './functions/saveFirebaseConfig';
import { getFirebaseConfig } from './functions/getFirebaseConfig';
import { deleteFirebaseConfig } from './functions/deleteFirebaseConfig';

// Storage trigger for file uploads
// Uses the default Firebase Storage bucket for the project
export const onFileUploadTrigger = functions
  .runWith({ memory: '512MB', timeoutSeconds: 540 })
  .region('us-central1')
  .storage
  .object()
  .onFinalize(onFileUpload);

// HTTP callable functions
export const generateApiKeyFunctionCallable = functions.https.onCall(generateApiKeyFunction);
export const listDeploymentsFunction = functions.https.onCall(listDeployments);
export const listUserDeploymentsFunction = functions.https.onCall(listUserDeployments);
export const deleteDeploymentFunction = functions.https.onCall(deleteDeployment);
export const deleteUserDeploymentFunction = functions.https.onCall(deleteUserDeployment);
export const getDeploymentStatusFunction = functions.https.onCall(getDeploymentStatus);

// Analytics
export const trackPageView = functions.region('us-central1').https.onRequest(trackPageViewHandler);
export const getDeploymentAnalyticsFunction = functions.https.onCall(getDeploymentAnalytics);

// Firebase config management (self-hosted deployments)
export const saveFirebaseConfigFunction = functions.https.onCall(saveFirebaseConfig);
export const getFirebaseConfigFunction = functions.https.onCall(getFirebaseConfig);
export const deleteFirebaseConfigFunction = functions.https.onCall(deleteFirebaseConfig);

// CLI deploy endpoint
export const cliDeploy = functions
  .runWith({ memory: '512MB', timeoutSeconds: 540 })
  .region('us-central1')
  .https.onRequest(cliDeployHandler);

