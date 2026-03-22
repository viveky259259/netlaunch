import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { validateApiKey, getUserIdFromApiKey } from '../services/apiKeyService';
import { downloadZipFile, extractZip, validateExtractedFiles, cleanupTempFiles } from '../services/fileProcessor';
import { deployToFirebaseHosting, uploadFilesForHosting, getUserFirebaseConfig } from '../services/firebaseDeployer';

/**
 * Look up the API key and site name from fileUploadRequests collection by file path
 */
async function getUploadRequestByFilePath(filePath: string): Promise<{
  apiKey: string;
  userId: string | null;
  siteName: string;
  requestId: string;
} | null> {
  const db = admin.firestore();
  
  // Query for the upload request with this file path
  const snapshot = await db.collection('fileUploadRequests')
    .where('filePath', '==', filePath)
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get();
  
  if (snapshot.empty) {
    return null;
  }
  
  const doc = snapshot.docs[0];
  const data = doc.data();
  
  // Mark the request as processing
  await doc.ref.update({
    status: 'processing',
    processedAt: admin.firestore.Timestamp.now(),
  });
  
  return {
    apiKey: data.apiKey,
    userId: data.userId || null,
    siteName: data.siteName || '',
    requestId: doc.id,
  };
}

export const onFileUpload = async (object: functions.storage.ObjectMetadata): Promise<void> => {
  const filePath = object.name;
  const bucketName = object.bucket;
  
  if (!filePath) {
    console.error('No file path provided');
    return;
  }
  
  // Only process files in uploads directory
  if (!filePath.startsWith('uploads/')) {
    console.log(`Skipping file ${filePath} - not in uploads directory`);
    return;
  }
  
  const db = admin.firestore();
  
  // Look up the upload request from Firestore
  const uploadRequest = await getUploadRequestByFilePath(filePath);
  if (!uploadRequest) {
    console.error(`No upload request found for file path: ${filePath}`);
    return;
  }
  
  const { apiKey, siteName, requestId } = uploadRequest;
  console.log(`Found upload request ${requestId} for file: ${filePath}, siteName: ${siteName}`);
  
  // Validate site name
  if (!siteName || siteName.length < 3) {
    console.error(`Invalid site name for request ${requestId}: ${siteName}`);
    await db.collection('fileUploadRequests').doc(requestId).update({
      status: 'failed',
      error: 'Invalid site name - must be at least 3 characters',
    });
    return;
  }
  
  // Validate API key
  const isValid = await validateApiKey(apiKey);
  if (!isValid) {
    console.error(`Invalid API key for request ${requestId}`);
    await db.collection('fileUploadRequests').doc(requestId).update({
      status: 'failed',
      error: 'Invalid API key',
    });
    return;
  }
  
  // Get user ID associated with this API key
  const userId = await getUserIdFromApiKey(apiKey);
  
  // Hash the API key for storage
  const apiKeyHash = crypto.createHash('sha256').update(apiKey).digest('hex');
  
  const deploymentId = db.collection('deployments').doc().id;
  // Use user-provided site name for the URL
  const deploymentUrl = `https://${siteName.toLowerCase()}.web.app/`;
  
  let zipPath: string | null = null;
  let extractPath: string | null = null;
  
  try {
    // Create deployment record with pending status
    await db.collection('deployments').doc(deploymentId).set({
      apiKey: apiKey,
      apiKeyHash: apiKeyHash,
      userId: userId,
      siteName: siteName,
      url: deploymentUrl,
      status: 'pending',
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      filePath: filePath,
      metadata: {},
    });
    
    // Update status to deploying
    await db.collection('deployments').doc(deploymentId).update({
      status: 'deploying',
      updatedAt: admin.firestore.Timestamp.now(),
    });
    
    // Download zip file
    zipPath = await downloadZipFile(bucketName, filePath);
    
    // Extract zip file
    extractPath = extractZip(zipPath);
    
    // Validate extracted files
    const validation = validateExtractedFiles(extractPath);
    if (!validation.valid || !validation.contentPath) {
      throw new Error('No valid entry point found in extracted files (e.g., index.html)');
    }
    
    // Use the content path (may be a subdirectory if content is nested, e.g., jaspr/, build/web/)
    const contentPath = validation.contentPath;
    console.log(`Using content path: ${contentPath} (entry point: ${validation.entryPoint})`);
    
    // Upload files for hosting
    await uploadFilesForHosting(contentPath, deploymentId);

    // Check if user has a self-hosted Firebase config
    const userConfig = userId ? await getUserFirebaseConfig(userId) : null;
    if (userConfig) {
      console.log(`Using self-hosted config for project: ${userConfig.projectId}`);
    }

    // Deploy to Firebase Hosting with user's chosen site name
    const finalUrl = await deployToFirebaseHosting(contentPath, siteName, deploymentId, userConfig || undefined);
    
    // Update deployment status to success
    await db.collection('deployments').doc(deploymentId).update({
      status: 'success',
      url: finalUrl,
      updatedAt: admin.firestore.Timestamp.now(),
    });
    
    // Update upload request status to completed
    await db.collection('fileUploadRequests').doc(requestId).update({
      status: 'completed',
      deploymentId: deploymentId,
      completedAt: admin.firestore.Timestamp.now(),
    });
    
    console.log(`Deployment successful: ${deploymentId} -> ${finalUrl}`);
    
  } catch (error) {
    console.error(`Deployment failed for ${deploymentId}:`, error);
    
    // Update deployment status to failed
    await db.collection('deployments').doc(deploymentId).update({
      status: 'failed',
      updatedAt: admin.firestore.Timestamp.now(),
      error: error instanceof Error ? error.message : 'Unknown error',
    });
    
    // Update upload request status to failed
    await db.collection('fileUploadRequests').doc(requestId).update({
      status: 'failed',
      error: error instanceof Error ? error.message : 'Unknown error',
      failedAt: admin.firestore.Timestamp.now(),
    });
  } finally {
    // Clean up temporary files
    if (zipPath) cleanupTempFiles(zipPath);
    if (extractPath) cleanupTempFiles(extractPath);
  }
};

