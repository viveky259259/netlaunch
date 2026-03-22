import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import * as zlib from 'zlib';
import { JWT } from 'google-auth-library';

const DEFAULT_PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'deployinstantwebapp';

const BEACON_TEMPLATE = `<script>(function(){var d='__SITE_ID__',u='https://us-central1-deployinstantwebapp.cloudfunctions.net/trackPageView';var p=location.pathname+location.search,r='';try{r=document.referrer?new URL(document.referrer).origin:''}catch(e){}var b='d='+encodeURIComponent(d)+'&p='+encodeURIComponent(p)+'&r='+encodeURIComponent(r)+'&w='+innerWidth+'&t='+Math.floor(Date.now()/1e3);if(navigator.sendBeacon){navigator.sendBeacon(u,b)}else{fetch(u,{method:'POST',body:b,keepalive:true})}})()</script>`;

/**
 * User-provided Firebase project configuration (service account key).
 * When provided, deployments target the user's project instead of ours.
 */
export interface FirebaseProjectConfig {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

/**
 * Resolved credentials for a deployment — either default or user-provided.
 */
interface DeployCredentials {
  projectId: string;
  accessToken: string;
  isSelfHosted: boolean;
}

/**
 * Inject analytics beacon script into HTML content.
 * Skipped for self-hosted deployments.
 */
function injectBeaconScript(content: Buffer, siteId: string): Buffer {
  const html = content.toString('utf-8');
  const script = BEACON_TEMPLATE.replace('__SITE_ID__', siteId);

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
 * Resolve deployment credentials.
 * If a user config is provided, mint a token from their service account.
 * Otherwise, use the default application credentials.
 */
async function resolveCredentials(userConfig?: FirebaseProjectConfig): Promise<DeployCredentials> {
  if (userConfig) {
    const client = new JWT({
      email: userConfig.clientEmail,
      key: userConfig.privateKey,
      scopes: ['https://www.googleapis.com/auth/firebase.hosting'],
    });
    const tokenResponse = await client.getAccessToken();
    if (!tokenResponse.token) {
      throw new Error('Failed to get access token from user service account. Check your Firebase configuration.');
    }
    return {
      projectId: userConfig.projectId,
      accessToken: tokenResponse.token,
      isSelfHosted: true,
    };
  }

  // Default: use our project credentials
  const credential = admin.credential.applicationDefault();
  const token = await credential.getAccessToken();
  return {
    projectId: DEFAULT_PROJECT_ID,
    accessToken: token.access_token,
    isSelfHosted: false,
  };
}

/**
 * Fetch the user's saved Firebase config from Firestore (if any).
 */
export async function getUserFirebaseConfig(userId: string): Promise<FirebaseProjectConfig | null> {
  const db = admin.firestore();
  const doc = await db.collection('firebaseConfigs').doc(userId).get();
  if (!doc.exists) return null;

  const data = doc.data()!;
  return {
    projectId: data.projectId,
    clientEmail: data.clientEmail,
    privateKey: data.privateKey,
  };
}

/**
 * Calculate SHA256 hash of gzipped content
 */
function calculateGzipHash(content: Buffer): { hash: string; gzipped: Buffer } {
  const gzipped = zlib.gzipSync(content);
  const hash = crypto.createHash('sha256').update(gzipped).digest('hex');
  return { hash, gzipped };
}

/**
 * Validate and sanitize site name
 */
function validateSiteId(siteName: string): string {
  let siteId = siteName.toLowerCase().replace(/[^a-z0-9-]/g, '');
  if (!/^[a-z]/.test(siteId)) siteId = 'site-' + siteId;
  if (siteId.length < 3) siteId = siteId + crypto.randomBytes(4).toString('hex');
  if (siteId.length > 40) siteId = siteId.substring(0, 40);
  siteId = siteId.replace(/-+$/, '');
  return siteId;
}

/**
 * Check if a Firebase Hosting site exists
 */
async function siteExists(siteId: string, creds: DeployCredentials): Promise<boolean> {
  const response = await fetch(
    `https://firebasehosting.googleapis.com/v1beta1/projects/${creds.projectId}/sites/${siteId}`,
    {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${creds.accessToken}` },
    }
  );
  return response.ok;
}

/**
 * Create a new Firebase Hosting site if needed
 */
async function createHostingSiteIfNeeded(siteId: string, creds: DeployCredentials): Promise<boolean> {
  const exists = await siteExists(siteId, creds);
  if (exists) {
    console.log(`Site ${siteId} already exists, will update it`);
    return false;
  }

  console.log(`Creating new Firebase Hosting site: ${siteId}`);
  const response = await fetch(
    `https://firebasehosting.googleapis.com/v1beta1/projects/${creds.projectId}/sites?siteId=${siteId}`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${creds.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    if (response.status === 409 || errorText.includes('already exists')) {
      console.log(`Site ${siteId} already exists (race condition), will update it`);
      return false;
    }
    throw new Error(`Failed to create hosting site: ${errorText}`);
  }

  console.log(`Created hosting site: ${siteId}`);
  return true;
}

/**
 * Deploy files to Firebase Hosting.
 *
 * If userConfig is provided, deploys to the user's Firebase project.
 * Otherwise deploys to the default NetLaunch project.
 */
export async function deployToFirebaseHosting(
  extractPath: string,
  siteName: string,
  deploymentId: string,
  userConfig?: FirebaseProjectConfig,
): Promise<string> {
  const creds = await resolveCredentials(userConfig);
  const siteId = validateSiteId(siteName);

  console.log(`Deploying to Firebase Hosting site: ${siteId} (project: ${creds.projectId}, self-hosted: ${creds.isSelfHosted})`);

  // Step 0: Create the hosting site if it doesn't exist
  const isNewSite = await createHostingSiteIfNeeded(siteId, creds);
  console.log(isNewSite ? 'Created new site' : 'Updating existing site');

  // Process files
  const files = getAllFiles(extractPath);
  const fileMap: Record<string, string> = {};
  const gzippedContents: Record<string, Buffer> = {};

  console.log(`Processing ${files.length} files...`);

  for (const file of files) {
    const relativePath = path.relative(extractPath, file);
    const hostingPath = `/${relativePath}`;
    const rawContent = fs.readFileSync(file);

    // Only inject analytics beacon for NetLaunch-hosted deployments
    const ext = path.extname(file).toLowerCase();
    const content: Buffer = (!creds.isSelfHosted && (ext === '.html' || ext === '.htm'))
      ? injectBeaconScript(rawContent, siteId)
      : Buffer.from(rawContent);

    const { hash, gzipped } = calculateGzipHash(content);
    fileMap[hostingPath] = hash;
    gzippedContents[hash] = gzipped;
  }

  console.log(`Prepared ${Object.keys(fileMap).length} files for upload`);

  const authHeader = { 'Authorization': `Bearer ${creds.accessToken}` };

  try {
    // Step 1: Create a new version
    console.log('Creating new hosting version...');
    const createVersionResponse = await fetch(
      `https://firebasehosting.googleapis.com/v1beta1/sites/${siteId}/versions`,
      {
        method: 'POST',
        headers: { ...authHeader, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          config: {
            rewrites: [{ glob: '**', path: '/index.html' }],
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

    // Step 2: Populate files
    console.log('Populating files...');
    const populateResponse = await fetch(
      `https://firebasehosting.googleapis.com/v1beta1/${versionName}:populateFiles`,
      {
        method: 'POST',
        headers: { ...authHeader, 'Content-Type': 'application/json' },
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

    // Step 3: Upload files
    if (uploadUrl && uploadRequiredHashes.length > 0) {
      const failedUploads: string[] = [];

      for (const hash of uploadRequiredHashes) {
        const gzippedContent = gzippedContents[hash];
        if (!gzippedContent) {
          failedUploads.push(hash);
          continue;
        }

        try {
          const uploadResponse = await fetch(`${uploadUrl}/${hash}`, {
            method: 'POST',
            headers: { ...authHeader, 'Content-Type': 'application/octet-stream' },
            body: new Uint8Array(gzippedContent),
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
        headers: { ...authHeader, 'Content-Type': 'application/json' },
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
        headers: { ...authHeader, 'Content-Type': 'application/json' },
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

  const deploymentUrl = `https://${siteId}.web.app/`;

  // Update deployment record
  const db = admin.firestore();
  await db.collection('deployments').doc(deploymentId).update({
    url: deploymentUrl,
    siteId: siteId,
    selfHosted: creds.isSelfHosted,
    targetProjectId: creds.projectId,
    status: 'deploying',
    updatedAt: admin.firestore.Timestamp.now(),
  });

  return deploymentUrl;
}

/**
 * Upload files to a storage location for hosting
 */
export async function uploadFilesForHosting(
  extractPath: string,
  deploymentId: string
): Promise<string> {
  const bucket = admin.storage().bucket();
  const deploymentPath = `deployments/${deploymentId}`;

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
