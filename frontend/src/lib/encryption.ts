// Web Crypto API based E2E encryption
// Key exchange: ECDH P-256
// Encryption: AES-GCM 256

const DB_NAME = 'aurbit-keys';
const STORE_NAME = 'private-keys';

async function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      req.result.createObjectStore(STORE_NAME);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function generateKeyPair(): Promise<{ publicKeyBase64: string }> {
  const keyPair = await crypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    ['deriveKey']
  );

  const publicKeyBuffer = await crypto.subtle.exportKey('spki', keyPair.publicKey);
  const privateKeyBuffer = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);

  // Store private key in IndexedDB
  const db = await openDB();
  const tx = db.transaction(STORE_NAME, 'readwrite');
  tx.objectStore(STORE_NAME).put(
    btoa(String.fromCharCode(...Array.from(new Uint8Array(privateKeyBuffer)))),
    'private-key'
  );

  const publicKeyBase64 = btoa(String.fromCharCode(...Array.from(new Uint8Array(publicKeyBuffer))));
  return { publicKeyBase64 };
}

export async function getPrivateKey(): Promise<CryptoKey | null> {
  try {
    const db = await openDB();
    const tx = db.transaction(STORE_NAME, 'readonly');
    const stored: string = await new Promise((resolve, reject) => {
      const req = tx.objectStore(STORE_NAME).get('private-key');
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
    if (!stored) return null;
    const buffer = Uint8Array.from(atob(stored), c => c.charCodeAt(0));
    return crypto.subtle.importKey('pkcs8', buffer, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveKey']);
  } catch {
    return null;
  }
}

async function deriveSharedKey(privateKey: CryptoKey, theirPublicKeyBase64: string): Promise<CryptoKey> {
  const publicKeyBuffer = Uint8Array.from(atob(theirPublicKeyBase64), c => c.charCodeAt(0));
  const theirPublicKey = await crypto.subtle.importKey(
    'spki',
    publicKeyBuffer,
    { name: 'ECDH', namedCurve: 'P-256' },
    false,
    []
  );
  return crypto.subtle.deriveKey(
    { name: 'ECDH', public: theirPublicKey },
    privateKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

export async function encryptMessage(
  plaintext: string,
  theirPublicKeyBase64: string
): Promise<{ encryptedContent: string; nonce: string } | null> {
  try {
    const privateKey = await getPrivateKey();
    if (!privateKey) return null;
    const sharedKey = await deriveSharedKey(privateKey, theirPublicKeyBase64);
    const nonce = crypto.getRandomValues(new Uint8Array(12));
    const encoded = new TextEncoder().encode(plaintext);
    const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, sharedKey, encoded);
    return {
      encryptedContent: btoa(String.fromCharCode(...Array.from(new Uint8Array(encrypted)))),
      nonce: btoa(String.fromCharCode(...Array.from(nonce))),
    };
  } catch {
    return null;
  }
}

export async function decryptMessage(
  encryptedContent: string,
  nonce: string,
  theirPublicKeyBase64: string
): Promise<string | null> {
  try {
    const privateKey = await getPrivateKey();
    if (!privateKey) return null;
    const sharedKey = await deriveSharedKey(privateKey, theirPublicKeyBase64);
    const nonceBuffer = Uint8Array.from(atob(nonce), c => c.charCodeAt(0));
    const encryptedBuffer = Uint8Array.from(atob(encryptedContent), c => c.charCodeAt(0));
    const decrypted = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: nonceBuffer }, sharedKey, encryptedBuffer);
    return new TextDecoder().decode(decrypted);
  } catch {
    return null;
  }
}
