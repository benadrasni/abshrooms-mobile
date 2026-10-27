import { verify } from 'node:crypto';
import { adGrantsPerMonth, rollOver, type QuotaState } from './quota';

const keysUrl = 'https://www.gstatic.com/admob/reward/verifier-keys.json';
const keysTtlMs = 24 * 60 * 60 * 1000;
const firebaseId = /^[^.#$[\]/]{1,128}$/;

let cachedKeys: Map<string, string> | undefined;
let cachedAt = 0;

/** Verifier keys could not be fetched. The callback should be retried. */
export class AdmobKeysUnavailable extends Error {}

export function resetAdmobVerifierKeys(): void {
  cachedKeys = undefined;
  cachedAt = 0;
}

async function verifierKeys(refresh: boolean): Promise<Map<string, string>> {
  if (!refresh && cachedKeys && Date.now() - cachedAt < keysTtlMs) return cachedKeys;
  let response: Response;
  try {
    response = await fetch(keysUrl, { signal: AbortSignal.timeout(10_000) });
  } catch (error) {
    throw new AdmobKeysUnavailable(error instanceof Error ? error.message : 'keys');
  }
  if (!response.ok) throw new AdmobKeysUnavailable(`AdMob verifier keys ${response.status}`);
  let body: { keys?: { keyId: number; pem: string }[] };
  try {
    body = (await response.json()) as { keys?: { keyId: number; pem: string }[] };
  } catch (error) {
    throw new AdmobKeysUnavailable(error instanceof Error ? error.message : 'keys');
  }
  cachedKeys = new Map((body.keys ?? []).map((key) => [String(key.keyId), key.pem]));
  cachedAt = Date.now();
  return cachedKeys;
}

/**
 * Checks an AdMob rewarded-ad server-side verification callback. The signed
 * message is the raw query string up to `&signature=`, in the order AdMob sent
 * it, so it must not be rebuilt from parsed parameters.
 * A key-fetch failure throws [AdmobKeysUnavailable]. A bad signature returns null.
 */
export async function verifyAdmobCallback(rawQuery: string): Promise<URLSearchParams | null> {
  const cut = rawQuery.indexOf('&signature=');
  if (cut < 0) return null;
  const params = new URLSearchParams(rawQuery);
  const signature = params.get('signature');
  const keyId = params.get('key_id');
  if (!signature || !keyId) return null;
  const message = Buffer.from(rawQuery.slice(0, cut), 'utf8');
  const signatureBytes = Buffer.from(signature, 'base64url');
  let keys: Map<string, string>;
  try {
    keys = await verifierKeys(false);
    if (!keys.has(keyId)) keys = await verifierKeys(true);
  } catch (error) {
    if (error instanceof AdmobKeysUnavailable) throw error;
    throw new AdmobKeysUnavailable(error instanceof Error ? error.message : 'keys');
  }
  const pem = keys.get(keyId);
  if (!pem) return null;
  try {
    const ok = verify('sha256', message, { key: pem, dsaEncoding: 'der' }, signatureBytes);
    return ok ? params : null;
  } catch {
    return null;
  }
}

/** Query string of an HTTPS callback, preferring the URL that carries the signature. */
export function admobCallbackQuery(url: string | undefined, fallback?: string): string {
  const primary = queryOf(url);
  if (primary.includes('signature=')) return primary;
  const second = queryOf(fallback);
  if (second.includes('signature=')) return second;
  return primary || second;
}

function queryOf(url: string | undefined): string {
  if (!url) return '';
  const mark = url.indexOf('?');
  return mark < 0 ? '' : url.slice(mark + 1);
}

/** `user_id` and `transaction_id` that can be stored as Firestore ids. */
export function admobRewardIdentity(
  params: URLSearchParams,
): { uid: string; transactionId: string } | null {
  const uid = params.get('user_id');
  const transactionId = params.get('transaction_id');
  if (!uid || !firebaseId.test(uid)) return null;
  if (!transactionId || !firebaseId.test(transactionId)) return null;
  return { uid, transactionId };
}

/**
 * The callback's `user_id` is this Firebase account. An anonymous guest has
 * no provider and cannot take an ad name.
 */
export function adGrantAccount(
  user: { uid: string; providers: readonly string[] } | null,
  claimedUid: string,
): boolean {
  if (!user || user.uid !== claimedUid || user.uid.length === 0) return false;
  return user.providers.some((provider) => provider.length > 0);
}

export type VerifiedAdGrant =
  | { result: 'replay' }
  | { result: 'granted' | 'capped'; quota: QuotaState };

/**
 * Grants one name for a verified callback. There is no time gap: a second
 * signed transaction in the same minute is a second view. A stored
 * transaction id is a replay and does not change the meter. The receipt is
 * written only when the grant is counted, or when this month is already full.
 */
export function applyVerifiedAdGrant(
  prior: { transactionUid?: string; quota: QuotaState | null },
  now: number,
): VerifiedAdGrant {
  if (prior.transactionUid !== undefined) return { result: 'replay' };
  const next = rollOver(prior.quota, now);
  const used = next.adGrants ?? 0;
  if (used >= adGrantsPerMonth) return { result: 'capped', quota: next };
  next.adGrants = used + 1;
  next.lastAdGrantAt = now;
  return { result: 'granted', quota: next };
}

export type AdmobClaim = 'granted' | 'replay' | 'capped' | 'unbound' | 'unavailable';

/**
 * Decides the HTTP result for one callback. [claim] runs only after the
 * signature, user id, and transaction id check out. A key-fetch failure is
 * 503, not a throw.
 */
export async function settleAdmobReward(
  method: string,
  rawQuery: string,
  claim: (identity: { uid: string; transactionId: string }) => Promise<AdmobClaim>,
): Promise<{ status: number; body: string }> {
  if (method !== 'GET') return { status: 405, body: 'method' };
  let params: URLSearchParams | null;
  try {
    params = await verifyAdmobCallback(rawQuery);
  } catch (error) {
    if (error instanceof AdmobKeysUnavailable) return { status: 503, body: 'keys' };
    throw error;
  }
  if (!params) return { status: 403, body: 'signature' };
  const identity = admobRewardIdentity(params);
  if (!identity) return { status: 400, body: 'user' };
  const result = await claim(identity);
  if (result === 'unbound') return { status: 403, body: 'user' };
  if (result === 'unavailable') return { status: 503, body: 'retry' };
  if (result === 'replay') return { status: 200, body: 'replay' };
  if (result === 'capped') return { status: 200, body: 'capped' };
  return { status: 200, body: 'ok' };
}
