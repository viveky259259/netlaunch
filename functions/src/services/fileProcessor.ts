import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import AdmZip from 'adm-zip';
import { Storage } from '@google-cloud/storage';

const storage = new Storage();

/**
 * Download zip file from Firebase Storage
 */
export async function downloadZipFile(bucketName: string, filePath: string): Promise<string> {
  const bucket = storage.bucket(bucketName);
  const file = bucket.file(filePath);
  const tempFilePath = path.join(os.tmpdir(), `deploy-${Date.now()}.zip`);
  
  await file.download({ destination: tempFilePath });
  return tempFilePath;
}

/**
 * Extract zip file to temporary directory
 */
export function extractZip(zipPath: string): string {
  const extractPath = path.join(os.tmpdir(), `extract-${Date.now()}`);
  fs.mkdirSync(extractPath, { recursive: true });
  
  const zip = new AdmZip(zipPath);
  zip.extractAllTo(extractPath, true);
  
  return extractPath;
}

/**
 * Validate extracted files structure
 * Checks for index.html or other common entry points
 */
export function validateExtractedFiles(extractPath: string): { valid: boolean; entryPoint?: string } {
  const commonEntryPoints = ['index.html', 'index.htm', 'app.html', 'main.html'];
  
  for (const entryPoint of commonEntryPoints) {
    const entryPath = path.join(extractPath, entryPoint);
    if (fs.existsSync(entryPath)) {
      return { valid: true, entryPoint };
    }
  }
  
  // Check if there's any HTML file in the root
  const files = fs.readdirSync(extractPath);
  const htmlFiles = files.filter(f => f.endsWith('.html') || f.endsWith('.htm'));
  
  if (htmlFiles.length > 0) {
    return { valid: true, entryPoint: htmlFiles[0] };
  }
  
  return { valid: false };
}

/**
 * Clean up temporary files
 */
export function cleanupTempFiles(...paths: string[]): void {
  for (const filePath of paths) {
    try {
      if (fs.existsSync(filePath)) {
        if (fs.statSync(filePath).isDirectory()) {
          fs.rmSync(filePath, { recursive: true, force: true });
        } else {
          fs.unlinkSync(filePath);
        }
      }
    } catch (error) {
      console.error(`Error cleaning up ${filePath}:`, error);
    }
  }
}

