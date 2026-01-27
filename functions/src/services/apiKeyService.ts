import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

const db = admin.firestore();

export interface ApiKeyData {
  apiKey: string;
  createdAt: admin.firestore.Timestamp;
  usageCount: number;
  lastUsed: admin.firestore.Timestamp | null;
  metadata?: Record<string, any>;
}

/**
 * Generate a new API key
 */
export async function generateApiKey(metadata?: Record<string, any>): Promise<string> {
  const apiKey = `fk_${crypto.randomBytes(32).toString('hex')}`;
  const hashedKey = crypto.createHash('sha256').update(apiKey).digest('hex');
  
  const apiKeyData: ApiKeyData = {
    apiKey: hashedKey,
    createdAt: admin.firestore.Timestamp.now(),
    usageCount: 0,
    lastUsed: null,
    metadata: metadata || {},
  };
  
  await db.collection('apiKeys').doc(hashedKey).set(apiKeyData);
  
  return apiKey;
}

/**
 * Validate an API key
 */
export async function validateApiKey(apiKey: string): Promise<boolean> {
  if (!apiKey || !apiKey.startsWith('fk_')) {
    return false;
  }
  
  const hashedKey = crypto.createHash('sha256').update(apiKey).digest('hex');
  const doc = await db.collection('apiKeys').doc(hashedKey).get();
  
  if (!doc.exists) {
    return false;
  }
  
  // Update usage count and last used
  await db.collection('apiKeys').doc(hashedKey).update({
    usageCount: admin.firestore.FieldValue.increment(1),
    lastUsed: admin.firestore.Timestamp.now(),
  });
  
  return true;
}

/**
 * Extract API key from file path
 * Expected format: uploads/{apiKey}/{filename}
 */
export function extractApiKeyFromPath(filePath: string): string | null {
  const parts = filePath.split('/');
  if (parts.length >= 2 && parts[0] === 'uploads') {
    return parts[1];
  }
  return null;
}

