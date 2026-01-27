import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import { getDeploymentUrl } from './subdomainManager';

/**
 * Deploy files to Firebase Hosting
 * Note: This is a simplified version. In production, you may need to use
 * Firebase Hosting API or Firebase CLI programmatically
 */
export async function deployToFirebaseHosting(
  extractPath: string,
  subdomain: string,
  deploymentId: string
): Promise<string> {
  const customDomain = process.env.CUSTOM_DOMAIN || 
                       (require('firebase-functions').config().custom_domain?.domain) || 
                       'yourdomain.com';
  const deploymentUrl = getDeploymentUrl(subdomain, customDomain);
  
  // In a real implementation, you would:
  // 1. Create a Firebase Hosting site for this subdomain
  // 2. Upload files to the hosting site
  // 3. Deploy the site
  // 
  // For now, we'll store the files in Storage and reference them
  // The actual hosting deployment would require Firebase Hosting API access
  
  // Store deployment metadata
  const db = admin.firestore();
  await db.collection('deployments').doc(deploymentId).update({
    url: deploymentUrl,
    status: 'deploying',
    updatedAt: admin.firestore.Timestamp.now(),
  });
  
  // TODO: Implement actual Firebase Hosting deployment
  // This would typically involve:
  // - Using Firebase Hosting API to create/update a site
  // - Uploading files to the hosting site
  // - Triggering a deployment
  
  // For now, we'll simulate a successful deployment
  // In production, replace this with actual Firebase Hosting API calls
  
  return deploymentUrl;
}

/**
 * Upload files to a storage location for hosting
 * This is a workaround until Firebase Hosting API is fully integrated
 */
export async function uploadFilesForHosting(
  extractPath: string,
  deploymentId: string
): Promise<string> {
  const bucket = admin.storage().bucket();
  const deploymentPath = `deployments/${deploymentId}`;
  
  // Upload all files from extractPath to Storage
  const files = getAllFiles(extractPath);
  
  for (const file of files) {
    const relativePath = path.relative(extractPath, file);
    const destination = `${deploymentPath}/${relativePath}`;
    await bucket.upload(file, { destination });
  }
  
  return deploymentPath;
}

/**
 * Get all files in a directory recursively
 */
function getAllFiles(dirPath: string, arrayOfFiles: string[] = []): string[] {
  const files = fs.readdirSync(dirPath);
  
  files.forEach((file) => {
    const filePath = path.join(dirPath, file);
    if (fs.statSync(filePath).isDirectory()) {
      arrayOfFiles = getAllFiles(filePath, arrayOfFiles);
    } else {
      arrayOfFiles.push(filePath);
    }
  });
  
  return arrayOfFiles;
}

