import { createPublicKey, createVerify, type JsonWebKey } from 'node:crypto';
import { decodeBase64Url } from './jwt';

export class PubSubKeysUnavailable extends Error {}

export type PubSubClaims = Record<string, unknown>;

/** RS256 check. Returns the payload, or null when the signature does not match. */
export function verifyRs256(token: string, pem: string): PubSubClaims | null {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  let header: { alg?: unknown };
  try {
    header = JSON.parse(decodeBase64Url(parts[0]).toString('utf8')) as { alg?: unknown };
  } catch {
    return null;
  }
  if (header.alg !== 'RS256') return null;
  const signed = `${parts[0]}.${parts[1]}`;
  let ok = false;
  try {
    ok = createVerify('RSA-SHA256').update(signed).verify(pem, decodeBase64Url(parts[2]));
  } catch {
    return null;
  }
  if (!ok) return null;
  try {
    const payload = JSON.parse(decodeBase64Url(parts[1]).toString('utf8')) as unknown;
    return payload && typeof payload === 'object' ? (payload as PubSubClaims) : null;
  } catch {
    return null;
  }
}

export function publicKeyFromJwk(jwk: JsonWebKey & { kid?: string }): string {
  const key = createPublicKey({ key: jwk, format: 'jwk' });
  return key.export({ type: 'spki', format: 'pem' }).toString();
}

/**
 * A Play push is accepted only when Google signed it for this endpoint and
 * the email is the configured Pub/Sub service account.
 */
export function pubSubPushAllowed(
  claims: PubSubClaims,
  options: { nowSec: number; audiences: string[]; serviceAccount: string },
): boolean {
  const email = options.serviceAccount.trim();
  if (!email.endsWith('.gserviceaccount.com')) return false;
  if (claims.iss !== 'https://accounts.google.com' && claims.iss !== 'accounts.google.com') return false;
  if (claims.email_verified !== true) return false;
  if (claims.email !== email) return false;
  if (typeof claims.exp !== 'number' || claims.exp <= options.nowSec) return false;
  const aud = claims.aud;
  const audiences = Array.isArray(aud) ? aud : [aud];
  return audiences.some((value) => typeof value === 'string' && options.audiences.includes(value));
}

export function bearerToken(authorization: string | undefined): string | null {
  if (!authorization) return null;
  const match = /^Bearer (.+)$/.exec(authorization.trim());
  return match ? match[1] : null;
}

export async function authorizePubSub(
  authorization: string | undefined,
  options: {
    nowSec: number;
    audiences: string[];
    serviceAccount: string;
    keyForKid: (kid: string) => Promise<string | null>;
  },
): Promise<boolean> {
  const token = bearerToken(authorization);
  if (!token || options.audiences.length === 0) return false;
  const kid = tokenKid(token);
  if (!kid) return false;
  const pem = await options.keyForKid(kid);
  if (!pem) return false;
  const claims = verifyRs256(token, pem);
  if (!claims) return false;
  return pubSubPushAllowed(claims, options);
}

function tokenKid(token: string): string | null {
  const header = token.split('.')[0];
  if (!header) return null;
  try {
    const parsed = JSON.parse(decodeBase64Url(header).toString('utf8')) as { kid?: unknown };
    return typeof parsed.kid === 'string' && parsed.kid.length > 0 ? parsed.kid : null;
  } catch {
    return null;
  }
}

let cachedKeys: { at: number; keys: Map<string, string> } | null = null;

/** Google's OAuth certs. A failed fetch throws so the push can be retried. */
export async function googlePubSubKey(kid: string, fetchImpl: typeof fetch = fetch): Promise<string | null> {
  const now = Date.now();
  if (!cachedKeys || now - cachedKeys.at > 60 * 60 * 1000) {
    let response: Response;
    try {
      response = await fetchImpl('https://www.googleapis.com/oauth2/v3/certs');
    } catch {
      throw new PubSubKeysUnavailable('certs unreachable');
    }
    if (!response.ok) throw new PubSubKeysUnavailable(`certs ${response.status}`);
    const body = (await response.json()) as { keys?: Array<JsonWebKey & { kid?: string }> };
    const keys = new Map<string, string>();
    for (const jwk of body.keys ?? []) {
      if (!jwk.kid || jwk.kty !== 'RSA' || !jwk.n || !jwk.e) continue;
      keys.set(jwk.kid, publicKeyFromJwk(jwk));
    }
    cachedKeys = { at: now, keys };
  }
  return cachedKeys.keys.get(kid) ?? null;
}

export function resetPubSubKeyCache(): void {
  cachedKeys = null;
}
