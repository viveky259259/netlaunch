import * as functions from 'firebase-functions';
import { generateApiKey } from '../services/apiKeyService';

interface GenerateApiKeyRequest {
  metadata?: Record<string, any>;
}

export const generateApiKeyFunction = async (
  data: GenerateApiKeyRequest,
  context: functions.https.CallableContext
): Promise<{ apiKey: string; message: string }> => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to generate an API key.'
    );
  }
  
  const userId = context.auth.uid;
  const userEmail = context.auth.token.email || null;
  
  try {
    const apiKey = await generateApiKey(userId, userEmail, data.metadata);
    
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

