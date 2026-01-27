#!/usr/bin/env node

/**
 * Script to generate API keys for Firebase Hosting Service
 * 
 * Usage:
 *   node generate-key.js
 * 
 * Make sure Firebase Admin is initialized and you have access to Firestore
 */

const admin = require('firebase-admin');
const crypto = require('crypto');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  try {
    admin.initializeApp();
  } catch (error) {
    console.error('Error initializing Firebase Admin:', error);
    console.log('\nMake sure you have:');
    console.log('1. Set GOOGLE_APPLICATION_CREDENTIALS environment variable, or');
    console.log('2. Run this from a Firebase Functions environment, or');
    console.log('3. Use firebase-tools: firebase functions:shell');
    process.exit(1);
  }
}

const db = admin.firestore();

async function generateApiKey(metadata = {}) {
  // Generate API key
  const apiKey = `fk_${crypto.randomBytes(32).toString('hex')}`;
  const hashedKey = crypto.createHash('sha256').update(apiKey).digest('hex');
  
  // Create API key document
  const apiKeyData = {
    apiKey: hashedKey,
    createdAt: admin.firestore.Timestamp.now(),
    usageCount: 0,
    lastUsed: null,
    metadata: metadata,
  };
  
  // Save to Firestore
  await db.collection('apiKeys').doc(hashedKey).set(apiKeyData);
  
  return apiKey;
}

// Main execution
(async () => {
  try {
    console.log('🔑 Generating API key...\n');
    
    const apiKey = await generateApiKey();
    
    console.log('✅ API Key generated successfully!\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('API Key:', apiKey);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('⚠️  IMPORTANT: Save this key securely!');
    console.log('   This key will not be shown again.\n');
    console.log('📝 You can now use this key in the Flutter app to upload and deploy files.\n');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error generating API key:', error);
    process.exit(1);
  }
})();

