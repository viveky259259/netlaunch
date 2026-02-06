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
export const listUserDeploymentsFunction = functions.https.onCall(listUserDeployments);
export const deleteDeploymentFunction = functions.https.onCall(deleteDeployment);
export const deleteUserDeploymentFunction = functions.https.onCall(deleteUserDeployment);
export const getDeploymentStatusFunction = functions.https.onCall(getDeploymentStatus);

