import * as crypto from 'crypto';

/**
 * Generate a unique subdomain identifier
 */
export function generateSubdomain(): string {
  const hash = crypto.randomBytes(8).toString('hex');
  return `deploy-${hash}`;
}

/**
 * Get full deployment URL from subdomain
 */
export function getDeploymentUrl(subdomain: string, customDomain?: string): string {
  const domain = customDomain || 'yourdomain.com';
  return `https://${subdomain}.${domain}`;
}

