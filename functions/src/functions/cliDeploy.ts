import * as admin from 'firebase-admin';
import * as os from 'os';
import * as path from 'path';
import * as fs from 'fs';
import * as crypto from 'crypto';
import Busboy from 'busboy';
import { validateApiKey, getUserIdFromApiKey } from '../services/apiKeyService';
import { extractZip, validateExtractedFiles, cleanupTempFiles } from '../services/fileProcessor';
import { deployToFirebaseHosting, getUserFirebaseConfig } from '../services/firebaseDeployer';

/**
 * HTTP handler for CLI deployments.
 * Accepts multipart/form-data with:
 *   - file: ZIP archive
 *   - apiKey: deployment key
 *   - siteName: target subdomain
 */
export const cliDeployHandler = (
  req: import('firebase-functions').https.Request,
  res: import('firebase-functions').Response
): void => {
  // CORS
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const busboy = Busboy({ headers: req.headers });
  const tmpDir = os.tmpdir();
  let zipPath: string | null = null;
  let apiKey = '';
  let siteName = '';

  // Collect form fields
  busboy.on('field', (fieldname: string, val: string) => {
    if (fieldname === 'apiKey') apiKey = val;
    if (fieldname === 'siteName') siteName = val.toLowerCase().trim();
  });

  // Collect the ZIP file
  const filePromise = new Promise<string | null>((resolve, reject) => {
    let fileReceived = false;
    busboy.on('file', (_fieldname: string, file: NodeJS.ReadableStream, _info: { filename: string }) => {
      fileReceived = true;
      const filepath = path.join(tmpDir, `cli-deploy-${Date.now()}.zip`);
      const writeStream = fs.createWriteStream(filepath);
      file.pipe(writeStream);
      writeStream.on('finish', () => resolve(filepath));
      writeStream.on('error', reject);
    });
    busboy.on('finish', () => {
      if (!fileReceived) resolve(null);
    });
    busboy.on('error', reject);
  });

  busboy.end(req.rawBody);

  filePromise
    .then(async (filePath) => {
      zipPath = filePath;

      if (!apiKey) {
        res.status(400).json({ error: 'Missing apiKey field' });
        return;
      }
      if (!siteName || siteName.length < 3) {
        res.status(400).json({ error: 'siteName must be at least 3 characters' });
        return;
      }
      if (!zipPath) {
        res.status(400).json({ error: 'Missing ZIP file' });
        return;
      }

      // Validate API key
      const isValid = await validateApiKey(apiKey);
      if (!isValid) {
        res.status(401).json({ error: 'Invalid API key' });
        return;
      }

      const userId = await getUserIdFromApiKey(apiKey);
      const apiKeyHash = crypto.createHash('sha256').update(apiKey).digest('hex');
      const db = admin.firestore();
      const deploymentId = db.collection('deployments').doc().id;

      let extractPath: string | null = null;

      try {
        // Create deployment record
        await db.collection('deployments').doc(deploymentId).set({
          apiKey,
          apiKeyHash,
          userId,
          siteName,
          url: `https://${siteName}.web.app/`,
          status: 'deploying',
          createdAt: admin.firestore.Timestamp.now(),
          updatedAt: admin.firestore.Timestamp.now(),
          source: 'cli',
          metadata: {},
        });

        // Extract ZIP
        extractPath = extractZip(zipPath);
        const validation = validateExtractedFiles(extractPath);
        if (!validation.valid || !validation.contentPath) {
          await db.collection('deployments').doc(deploymentId).update({
            status: 'failed',
            error: 'No valid entry point found (e.g., index.html)',
            updatedAt: admin.firestore.Timestamp.now(),
          });
          res.status(400).json({ error: 'No valid entry point found (e.g., index.html)' });
          return;
        }

        // Check if user has a self-hosted Firebase config
        const userConfig = userId ? await getUserFirebaseConfig(userId) : null;
        if (userConfig) {
          console.log(`CLI deploy: using self-hosted config for project ${userConfig.projectId}`);
        }

        // Deploy to Firebase Hosting
        const finalUrl = await deployToFirebaseHosting(
          validation.contentPath,
          siteName,
          deploymentId,
          userConfig || undefined,
        );

        // Update status to success
        await db.collection('deployments').doc(deploymentId).update({
          status: 'success',
          url: finalUrl,
          updatedAt: admin.firestore.Timestamp.now(),
        });

        res.status(200).json({
          success: true,
          deploymentId,
          url: finalUrl,
          siteName,
        });
      } catch (error) {
        console.error('CLI deploy error:', error);
        try {
          await db.collection('deployments').doc(deploymentId).update({
            status: 'failed',
            error: error instanceof Error ? error.message : 'Unknown error',
            updatedAt: admin.firestore.Timestamp.now(),
          });
        } catch (_) { /* ignore update error */ }
        res.status(500).json({
          error: error instanceof Error ? error.message : 'Deployment failed',
        });
      } finally {
        if (zipPath) cleanupTempFiles(zipPath);
        if (extractPath) cleanupTempFiles(extractPath);
      }
    })
    .catch((error) => {
      console.error('File parse error:', error);
      res.status(500).json({ error: 'Failed to parse upload' });
    });
};
