import * as crypto from 'crypto';

/**
 * Envelope encryption for secrets stored at rest in Firestore (e.g. user
 * service-account private keys).
 *
 * The encryption key is provided via the FIREBASE_CONFIG_ENC_KEY environment
 * variable / functions secret. It may be either:
 *   - 64 hex characters (32 bytes), used directly as the AES-256 key, or
 *   - any passphrase, from which a 32-byte key is derived via scrypt.
 *
 * Ciphertext format: "v1:" + base64(iv) + ":" + base64(authTag) + ":" + base64(ciphertext)
 */

const PREFIX = 'v1';
const ALGO = 'aes-256-gcm';
const IV_LEN = 12;
// Fixed salt — the env key is the secret; the salt only needs to be stable.
const SCRYPT_SALT = Buffer.from('netlaunch-config-enc-v1');

function getKey(): Buffer {
  const raw = process.env.FIREBASE_CONFIG_ENC_KEY;
  if (!raw) {
    throw new Error(
      'FIREBASE_CONFIG_ENC_KEY is not set. Configure it before saving Firebase configs (firebase functions:secrets:set FIREBASE_CONFIG_ENC_KEY).'
    );
  }
  if (/^[0-9a-fA-F]{64}$/.test(raw)) {
    return Buffer.from(raw, 'hex');
  }
  return crypto.scryptSync(raw, SCRYPT_SALT, 32);
}

/**
 * Encrypt a plaintext string for storage at rest.
 */
export function encryptSecret(plaintext: string): string {
  const key = getKey();
  const iv = crypto.randomBytes(IV_LEN);
  const cipher = crypto.createCipheriv(ALGO, key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return [
    PREFIX,
    iv.toString('base64'),
    authTag.toString('base64'),
    ciphertext.toString('base64'),
  ].join(':');
}

/**
 * Returns true if the given value looks like an encryptSecret() output.
 */
export function isEncrypted(value: string | undefined | null): boolean {
  return typeof value === 'string' && value.startsWith(PREFIX + ':');
}

/**
 * Decrypt a value produced by encryptSecret().
 */
export function decryptSecret(payload: string): string {
  const parts = payload.split(':');
  if (parts.length !== 4 || parts[0] !== PREFIX) {
    throw new Error('Malformed encrypted payload.');
  }
  const key = getKey();
  const iv = Buffer.from(parts[1], 'base64');
  const authTag = Buffer.from(parts[2], 'base64');
  const ciphertext = Buffer.from(parts[3], 'base64');
  const decipher = crypto.createDecipheriv(ALGO, key, iv);
  decipher.setAuthTag(authTag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8');
}
