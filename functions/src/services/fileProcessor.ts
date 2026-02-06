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
 * Recursively searches subdirectories to handle nested builds (e.g., build/jaspr/, myproject/build/web/)
 */
export function validateExtractedFiles(extractPath: string): { valid: boolean; entryPoint?: string; contentPath?: string } {
  const commonEntryPoints = ['index.html', 'index.htm', 'app.html', 'main.html'];
  
  // Log the contents of the extract path for debugging
  console.log(`Validating extracted files at: ${extractPath}`);
  try {
    const rootContents = fs.readdirSync(extractPath);
    console.log(`Root contents: ${JSON.stringify(rootContents)}`);
  } catch (e) {
    console.error(`Failed to read extract path: ${e}`);
  }
  
  // Recursive function to find entry point
  function findEntryPoint(dirPath: string, depth: number = 0, maxDepth: number = 5): { entryPoint: string; contentPath: string } | null {
    if (depth > maxDepth) return null;
    
    try {
      const files = fs.readdirSync(dirPath);
      
      // First, check for common entry points in this directory
      for (const entryPoint of commonEntryPoints) {
        if (files.includes(entryPoint)) {
          const entryPath = path.join(dirPath, entryPoint);
          if (fs.existsSync(entryPath) && fs.statSync(entryPath).isFile()) {
            console.log(`Found entry point at depth ${depth}: ${dirPath}/${entryPoint}`);
            return { entryPoint, contentPath: dirPath };
          }
        }
      }
      
      // Check for any HTML file in this directory
      const htmlFiles = files.filter(f => {
        const fullPath = path.join(dirPath, f);
        try {
          return fs.statSync(fullPath).isFile() && (f.endsWith('.html') || f.endsWith('.htm'));
        } catch {
          return false;
        }
      });
      
      if (htmlFiles.length > 0) {
        console.log(`Found HTML file at depth ${depth}: ${dirPath}/${htmlFiles[0]}`);
        return { entryPoint: htmlFiles[0], contentPath: dirPath };
      }
      
      // Recursively check subdirectories
      const directories = files.filter(f => {
        const fullPath = path.join(dirPath, f);
        try {
          return fs.statSync(fullPath).isDirectory() && !f.startsWith('.');
        } catch {
          return false;
        }
      });
      
      // Prioritize common build output directories
      const priorityDirs = ['build', 'web', 'dist', 'public', 'out', 'output', 'jaspr'];
      directories.sort((a, b) => {
        const aIndex = priorityDirs.indexOf(a.toLowerCase());
        const bIndex = priorityDirs.indexOf(b.toLowerCase());
        if (aIndex !== -1 && bIndex === -1) return -1;
        if (aIndex === -1 && bIndex !== -1) return 1;
        if (aIndex !== -1 && bIndex !== -1) return aIndex - bIndex;
        return 0;
      });
      
      for (const dir of directories) {
        const subDirPath = path.join(dirPath, dir);
        const result = findEntryPoint(subDirPath, depth + 1, maxDepth);
        if (result) {
          return result;
        }
      }
    } catch (error) {
      console.error(`Error reading directory ${dirPath}:`, error);
    }
    
    return null;
  }
  
  const result = findEntryPoint(extractPath);
  
  if (result) {
    return { valid: true, entryPoint: result.entryPoint, contentPath: result.contentPath };
  }
  
  console.log('No valid entry point found in extracted files');
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

