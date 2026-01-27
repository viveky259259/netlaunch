import * as functions from 'firebase-functions';
import { generateApiKey } from '../services/apiKeyService';

interface GenerateApiKeyRequest {
  metadata?: Record<string, any>;
}

export const generateApiKeyFunction = async (
  data: GenerateApiKeyRequest,
  context: functions.https.CallableContext
): Promise<{ apiKey: string; message: string }> => {
  // Optional: Add authentication check here
  // For now, anyone can generate an API key
  // You might want to restrict this to authenticated users
  
  try {
    const apiKey = await generateApiKey(data.metadata);
    
    return {
      apiKey: apiKey,
      message: 'API key generated successfully. Save this key securely - it will not be shown again.',
    };
  } catch (error) {
    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate API key',
      error instanceof Error ? error.message : 'Unknown error'
    );
  }
};

