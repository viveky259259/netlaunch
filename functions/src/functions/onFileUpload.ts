import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { validateApiKey, extractApiKeyFromPath } from '../services/apiKeyService';
import { downloadZipFile, extractZip, validateExtractedFiles, cleanupTempFiles } from '../services/fileProcessor';
import { generateSubdomain, getDeploymentUrl } from '../services/subdomainManager';
import { deployToFirebaseHosting, uploadFilesForHosting } from '../services/firebaseDeployer';

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
  
  // Extract API key from path
  const apiKey = extractApiKeyFromPath(filePath);
  if (!apiKey) {
    console.error(`Could not extract API key from path: ${filePath}`);
    return;
  }
  
  // Validate API key
  const isValid = await validateApiKey(apiKey);
  if (!isValid) {
    console.error(`Invalid API key: ${apiKey}`);
    // Optionally delete the file
    return;
  }
  
  const db = admin.firestore();
  const deploymentId = db.collection('deployments').doc().id;
  const subdomain = generateSubdomain();
  // Get custom domain from environment or config
  const customDomain = process.env.CUSTOM_DOMAIN || 
                       functions.config().custom_domain?.domain || 
                       'yourdomain.com';
  const deploymentUrl = getDeploymentUrl(subdomain, customDomain);
  
  let zipPath: string | null = null;
  let extractPath: string | null = null;
  
  try {
    // Create deployment record with pending status
    await db.collection('deployments').doc(deploymentId).set({
      apiKey: apiKey,
      subdomain: subdomain,
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
    if (!validation.valid) {
      throw new Error('No valid entry point found in extracted files (e.g., index.html)');
    }
    
    // Upload files for hosting
    await uploadFilesForHosting(extractPath, deploymentId);
    
    // Deploy to Firebase Hosting
    const finalUrl = await deployToFirebaseHosting(extractPath, subdomain, deploymentId);
    
    // Update deployment status to success
    await db.collection('deployments').doc(deploymentId).update({
      status: 'success',
      url: finalUrl,
      updatedAt: admin.firestore.Timestamp.now(),
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
  } finally {
    // Clean up temporary files
    if (zipPath) cleanupTempFiles(zipPath);
    if (extractPath) cleanupTempFiles(extractPath);
  }
};

