import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

import { onFileUpload } from './functions/onFileUpload';
import { listDeployments } from './functions/listDeployments';
import { deleteDeployment } from './functions/deleteDeployment';
import { getDeploymentStatus } from './functions/getDeploymentStatus';
import { generateApiKeyFunction } from './functions/generateApiKey';

// Storage trigger for file uploads
// Uses the default Firebase Storage bucket for the project
export const onFileUploadTrigger = functions
  .region('us-central1')
  .storage
  .object()
  .onFinalize(onFileUpload);

// HTTP callable functions
export const generateApiKeyFunctionCallable = functions.https.onCall(generateApiKeyFunction);
export const listDeploymentsFunction = functions.https.onCall(listDeployments);
export const deleteDeploymentFunction = functions.https.onCall(deleteDeployment);
export const getDeploymentStatusFunction = functions.https.onCall(getDeploymentStatus);

