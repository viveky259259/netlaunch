import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import * as zlib from 'zlib';

const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'deployinstantwebapp';

const BEACON_TEMPLATE = `<script>(function(){var d='__SITE_ID__',u='https://us-central1-deployinstantwebapp.cloudfunctions.net/trackPageView';var p=location.pathname+location.search,r='';try{r=document.referrer?new URL(document.referrer).origin:''}catch(e){}var b='d='+encodeURIComponent(d)+'&p='+encodeURIComponent(p)+'&r='+encodeURIComponent(r)+'&w='+innerWidth+'&t='+Math.floor(Date.now()/1e3);if(navigator.sendBeacon){navigator.sendBeacon(u,b)}else{fetch(u,{method:'POST',body:b,keepalive:true})}})()</script>`;

/**
 * Inject analytics beacon script into HTML content
 */
function injectBeaconScript(content: Buffer, siteId: string): Buffer {
  const html = content.toString('utf-8');
  const script = BEACON_TEMPLATE.replace('__SITE_ID__', siteId);

  // Try to inject before </body>, then </html>, then append
  const bodyIdx = html.toLowerCase().lastIndexOf('</body>');
  if (bodyIdx !== -1) {
    return Buffer.from(html.slice(0, bodyIdx) + script + html.slice(bodyIdx), 'utf-8');
  }

  const htmlIdx = html.toLowerCase().lastIndexOf('</html>');
  if (htmlIdx !== -1) {
    return Buffer.from(html.slice(0, htmlIdx) + script + html.slice(htmlIdx), 'utf-8');
  }

  return Buffer.from(html + script, 'utf-8');
}

/**
 * Get access token for Firebase Hosting API
 */
async function getAccessToken(): Promise<string> {
  const credential = admin.credential.applicationDefault();
  const token = await credential.getAccessToken();
  return token.access_token;
}

/**
 * Calculate SHA256 hash of gzipped content
 * Firebase Hosting requires hash of the gzipped content
 */
function calculateGzipHash(content: Buffer): { hash: string; gzipped: Buffer } {
  const gzipped = zlib.gzipSync(content);
  const hash = crypto.createHash('sha256').update(gzipped).digest('hex');
  return { hash, gzipped };
}

/**
 * Validate and sanitize site name
 * Firebase site IDs must be 3-40 chars, lowercase, start with letter
 */
function validateSiteId(siteName: string): string {
  // Sanitize: lowercase, remove invalid chars
  let siteId = siteName.toLowerCase().replace(/[^a-z0-9-]/g, '');
  
  // Ensure it starts with a letter
  if (!/^[a-z]/.test(siteId)) {
    siteId = 'site-' + siteId;
  }
  
  // Ensure minimum length
  if (siteId.length < 3) {
    siteId = siteId + crypto.randomBytes(4).toString('hex');
  }
  
  // Truncate if too long (max 40 chars)
  if (siteId.length > 40) {
    siteId = siteId.substring(0, 40);
  }
  
  // Remove trailing hyphens
  siteId = siteId.replace(/-+$/, '');
  
  return siteId;
}

/**
 * Check if a Firebase Hosting site exists
 */
async function siteExists(siteId: string, accessToken: string): Promise<boolean> {
  const response = await fetch(
    `https://firebasehosting.googleapis.com/v1beta1/projects/${PROJECT_ID}/sites/${siteId}`,
    {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      },
    }
  );
  
  return response.ok;
}

/**
 * Create a new Firebase Hosting site for this deployment
 * If the site already exists, it will be reused (updated)
 */
async function createHostingSiteIfNeeded(siteId: string, accessToken: string): Promise<boolean> {
  // First check if site already exists
  const exists = await siteExists(siteId, accessToken);
  
  if (exists) {
    console.log(`Site ${siteId} already exists, will update it`);
    return false; // Site existed, didn't create new
  }
  
  console.log(`Creating new Firebase Hosting site: ${siteId}`);
  
  const response = await fetch(
    `https://firebasehosting.googleapis.com/v1beta1/projects/${PROJECT_ID}/sites?siteId=${siteId}`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    }
  );
  
  if (!response.ok) {
    const errorText = await response.text();
    // Check if it's a "site already exists" error (can happen in race conditions)
    if (response.status === 409 || errorText.includes('already exists')) {
      console.log(`Site ${siteId} already exists (race condition), will update it`);
      return false;
    }
    throw new Error(`Failed to create hosting site: ${errorText}`);
  }
  
  console.log(`Created hosting site: ${siteId}`);
  return true; // Created new site
}

/**
 * Deploy files to Firebase Hosting
 * Creates a NEW site for each deployment - scalable solution
 * Each deployment gets its own subdomain: https://{siteName}.web.app/
 * 
 * @param extractPath - Path to extracted files
 * @param siteName - User-provided site name (will be used as subdomain)
 * @param deploymentId - Firestore deployment document ID
 */
export async function deployToFirebaseHosting(
  extractPath: string,
  siteName: string,
  deploymentId: string
): Promise<string> {
  const accessToken = await getAccessToken();
  
  // Validate and use the user-provided site name
  const siteId = validateSiteId(siteName);
  
  console.log(`Deploying to Firebase Hosting site: ${siteId} (requested: ${siteName})`);
  
  // Step 0: Create the hosting site if it doesn't exist, or reuse existing
  const isNewSite = await createHostingSiteIfNeeded(siteId, accessToken);
  console.log(isNewSite ? 'Created new site' : 'Updating existing site');
  
  // Get all files to deploy
  const files = getAllFiles(extractPath);
  const fileMap: Record<string, string> = {};
  const gzippedContents: Record<string, Buffer> = {};
  
  console.log(`Processing ${files.length} files...`);
  
  // Calculate hashes for all files (hash of gzipped content)
  // Files go to root / - no path prefixing needed!
  for (const file of files) {
    const relativePath = path.relative(extractPath, file);
    const hostingPath = `/${relativePath}`;
    const rawContent = fs.readFileSync(file);

    // Inject analytics beacon into HTML files
    const ext = path.extname(file).toLowerCase();
    const content: Buffer = (ext === '.html' || ext === '.htm')
      ? injectBeaconScript(rawContent, siteId)
      : Buffer.from(rawContent);

    const { hash, gzipped } = calculateGzipHash(content);
    fileMap[hostingPath] = hash;
    gzippedContents[hash] = gzipped;
  }
  
  console.log(`Prepared ${Object.keys(fileMap).length} files for upload`);
  
  try {
    // Step 1: Create a new version
    console.log('Creating new hosting version...');
    const createVersionResponse = await fetch(
      `https://firebasehosting.googleapis.com/v1beta1/sites/${siteId}/versions`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          config: {
            // SPA rewrite - serve index.html for all routes
            rewrites: [
              {
                glob: '**',
                path: '/index.html',
              },
            ],
          },
        }),
      }
    );
    
    if (!createVersionResponse.ok) {
      const error = await createVersionResponse.text();
      throw new Error(`Failed to create version: ${error}`);
    }
    
    const versionData = await createVersionResponse.json() as { name: string };
    const versionName = versionData.name;
    console.log(`Created version: ${versionName}`);
    
    // Step 2: Populate files (tell Hosting what files we want to upload)
    console.log('Populating files...');
    const populateResponse = await fetch(
      `https://firebasehosting.googleapis.com/v1beta1/${versionName}:populateFiles`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ files: fileMap }),
      }
    );
    
    if (!populateResponse.ok) {
      const error = await populateResponse.text();
      throw new Error(`Failed to populate files: ${error}`);
    }
    
    const populateData = await populateResponse.json() as { 
      uploadRequiredHashes?: string[]; 
      uploadUrl?: string;
    };
    const uploadRequiredHashes = populateData.uploadRequiredHashes || [];
    const uploadUrl = populateData.uploadUrl;
    
    console.log(`Need to upload ${uploadRequiredHashes.length} files`);
    
    // Step 3: Upload files that need to be uploaded
    if (uploadUrl && uploadRequiredHashes.length > 0) {
      const failedUploads: string[] = [];
      
      for (const hash of uploadRequiredHashes) {
        const gzippedContent = gzippedContents[hash];
        if (!gzippedContent) {
          console.error(`Gzipped content not found for hash: ${hash}`);
          failedUploads.push(hash);
          continue;
        }
        
        try {
          const bodyData = new Uint8Array(gzippedContent);
          
          const uploadResponse = await fetch(`${uploadUrl}/${hash}`, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/octet-stream',
            },
            body: bodyData,
          });
          
          if (!uploadResponse.ok) {
            const error = await uploadResponse.text();
            console.error(`Failed to upload file ${hash}: ${error}`);
            failedUploads.push(hash);
          } else {
            console.log(`Uploaded file: ${hash.substring(0, 16)}...`);
          }
        } catch (uploadError) {
          console.error(`Exception uploading file ${hash}:`, uploadError);
          failedUploads.push(hash);
        }
      }
      
      if (failedUploads.length > 0) {
        throw new Error(`Failed to upload ${failedUploads.length} files`);
      }
      
      console.log('All files uploaded successfully');
    }
    
    // Step 4: Finalize the version
    console.log('Finalizing version...');
    const finalizeResponse = await fetch(
      `https://firebasehosting.googleapis.com/v1beta1/${versionName}?update_mask=status`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status: 'FINALIZED' }),
      }
    );
    
    if (!finalizeResponse.ok) {
      const error = await finalizeResponse.text();
      throw new Error(`Failed to finalize version: ${error}`);
    }
    
    // Step 5: Release the version
    console.log('Releasing version...');
    const releaseResponse = await fetch(
      `https://firebasehosting.googleapis.com/v1beta1/sites/${siteId}/releases?versionName=${versionName}`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
      }
    );
    
    if (!releaseResponse.ok) {
      const error = await releaseResponse.text();
      throw new Error(`Failed to release version: ${error}`);
    }
    
    console.log('Deployment released successfully!');
    
  } catch (error) {
    console.error('Firebase Hosting deployment error:', error);
    throw error;
  }
  
  // Return the deployment URL - each site has its own subdomain!
  const deploymentUrl = `https://${siteId}.web.app/`;
  
  // Update deployment record with final URL and site ID
  const db = admin.firestore();
  await db.collection('deployments').doc(deploymentId).update({
    url: deploymentUrl,
    siteId: siteId,
    status: 'deploying',
    updatedAt: admin.firestore.Timestamp.now(),
  });
  
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

