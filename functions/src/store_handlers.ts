import {
  appleRenewalInfo,
  appleTransaction,
  applyAppleRenewal,
  appStoreBundleId,
  verifyAppleSignedPayload,
  type AppleRenewalInfo,
  type AppleTransaction,
} from './apple_jws';
import {
  entitlementRows,
  notificationUid,
  planGrant,
  productsFromWrites,
  proofKey,
  proofRecordOf,
  type ProofRecord,
  type VerifiedPurchase,
} from './entitlements';
import { playPackageName } from './play_purchase';
import { nextRefreshReservation } from './refresh_limit';
import { storeAccountToken } from './store_account';

/// One account's proofs, or the subscriptions the nightly pass still polls.
export type ProofQuery = { kind: 'account'; uid: string } | { kind: 'active-subscription' };

export type StoredProof = { key: string; proof: ProofRecord };

/// Indexed reads return this many documents per page.
export const proofPageSize = 100;

export type EntitlementDb = {
  get(path: string): Promise<unknown>;
  set(path: string, value: unknown): Promise<void>;
  remove(path: string): Promise<void>;
  /// Return undefined from update to leave the row unchanged.
  transaction(path: string, update: (current: unknown) => unknown): Promise<boolean>;
  authExists(uid: string): Promise<boolean>;
  forEachProof(query: ProofQuery, visit: (row: StoredProof) => Promise<void>): Promise<void>;
};

export function matchingProofs(all: unknown, query: ProofQuery): StoredProof[] {
  if (!all || typeof all !== 'object') return [];
  const rows: StoredProof[] = [];
  for (const [key, value] of Object.entries(all as Record<string, unknown>)) {
    const proof = proofRecordOf(value);
    if (!proof || !proofMatches(proof, query)) continue;
    rows.push({ key, proof });
  }
  rows.sort((left, right) => (left.key < right.key ? -1 : left.key > right.key ? 1 : 0));
  return rows;
}

function proofMatches(proof: ProofRecord, query: ProofQuery): boolean {
  if (query.kind === 'account') return proof.uid === query.uid;
  return proof.subscription && proof.active;
}

/// Loads every page. A cursor that comes back again stops the walk.
export async function walkProofPages<Cursor>(
  load: (cursor: Cursor | null) => Promise<{ rows: StoredProof[]; next: Cursor | null }>,
  visit: (row: StoredProof) => Promise<void>,
): Promise<void> {
  const requested = new Set<Cursor | null>();
  let cursor: Cursor | null = null;
  for (;;) {
    if (requested.has(cursor)) return;
    requested.add(cursor);
    const page = await load(cursor);
    for (const row of page.rows) await visit(row);
    if (page.next == null || requested.has(page.next)) return;
    cursor = page.next;
  }
}

async function applyWrites(
  db: EntitlementDb,
  writes: { path: string; value: unknown | null }[],
): Promise<void> {
  for (const write of writes) {
    if (write.value == null) await db.remove(write.path);
    else await db.set(write.path, write.value);
  }
}

function sameStoredProof(current: unknown, expected: ProofRecord | null): boolean {
  if (expected == null) return current == null;
  const proof = proofRecordOf(current);
  return proof != null && JSON.stringify(proof) === JSON.stringify(expected);
}

/// Claims the receipt inside a transaction, then writes the account rows.
/// A receipt with no account token can still be taken by the first live account.
export async function grantPurchase(
  db: EntitlementDb,
  uid: string,
  purchase: VerifiedPurchase,
  now: number,
): Promise<{ error: 'invalid' | 'other-account' } | { products: Record<string, boolean> }> {
  const key = proofKey(purchase.store, purchase.token);
  if (!key) return { error: 'invalid' };
  const proofPath = `purchase_proofs/${key}`;
  for (let attempt = 0; attempt < 4; attempt++) {
    const existing = proofRecordOf(await db.get(proofPath));
    const previousOwnerExists =
      existing != null && existing.uid !== uid ? await db.authExists(existing.uid) : false;
    const products = entitlementRows(await db.get(`users/${uid}/entitlements`));
    const plan = planGrant({ uid, now, purchase, existing, previousOwnerExists, products });
    if ('error' in plan) return plan;
    const proofWrite = plan.writes.find((write) => write.path === proofPath);
    if (!proofWrite || proofWrite.value == null) return { error: 'invalid' };
    const proofValue = proofWrite.value;
    const committed = await db.transaction(proofPath, (current) => {
      if (sameStoredProof(current, existing)) return proofValue;
      return undefined;
    });
    if (!committed) continue;
    await applyWrites(
      db,
      plan.writes.filter((write) => write.path !== proofPath),
    );
    return { products: productsFromWrites(plan.writes) };
  }
  return { error: 'other-account' };
}

export async function applyVerifiedNotification(
  db: EntitlementDb,
  purchase: VerifiedPurchase,
  now: number,
): Promise<boolean> {
  const key = proofKey(purchase.store, purchase.token);
  if (!key) return false;
  const proof = proofRecordOf(await db.get(`purchase_proofs/${key}`));
  let accountUid: string | null = null;
  if (purchase.accountToken && /^[0-9a-f-]{36}$/i.test(purchase.accountToken)) {
    const mapped = await db.get(`store_accounts/${purchase.accountToken}`);
    if (typeof mapped === 'string') accountUid = mapped;
  }
  const uid = notificationUid({
    proof,
    accountUid,
    proofOwnerExists: proof ? await db.authExists(proof.uid) : false,
    accountOwnerExists: accountUid ? await db.authExists(accountUid) : false,
  });
  if (!uid) return false;
  const result = await grantPurchase(db, uid, purchase, now);
  return !('error' in result);
}

export async function registerStoreAccount(db: EntitlementDb, uid: string): Promise<void> {
  const token = storeAccountToken(uid);
  const current = await db.get(`store_accounts/${token}`);
  if (current == null) await db.set(`store_accounts/${token}`, uid);
}

export async function releaseStorePurchases(db: EntitlementDb, uid: string): Promise<void> {
  const owned: StoredProof[] = [];
  await db.forEachProof({ kind: 'account', uid }, async (row) => {
    owned.push(row);
  });
  for (const { key } of owned) {
    if (!/^[A-Za-z0-9_-]{1,128}$/.test(key)) continue;
    await db.remove(`purchase_proofs/${key}`);
  }
  await db.remove(`users/${uid}/entitlements`);
  await db.remove(`store_accounts/${storeAccountToken(uid)}`);
}

/// Subscriptions that are still active. An ended or revoked proof stays
/// stored and is left for an account refresh, which can see a later renewal.
export async function subscriptionProofs(db: EntitlementDb): Promise<ProofRecord[]> {
  const proofs: ProofRecord[] = [];
  await db.forEachProof({ kind: 'active-subscription' }, async (row) => {
    proofs.push(row.proof);
  });
  return proofs;
}

export type ProofLookup =
  | { status: 'verified'; purchase: VerifiedPurchase }
  | { status: 'unknown' }
  | { status: 'unavailable' }
  | { status: 'throttled' };

export type RefreshRun = {
  products: Record<string, boolean>;
  retry: boolean;
  throttled: boolean;
};

/// Re-reads this account's stored subscription tokens, including one that
/// has already ended, so a later renewal of the same token is still seen.
/// A verified result is written. An unknown or unavailable lookup is left
/// unchanged and reported as retry, so a failed Play read is not stored as
/// a cancellation. Throttled stops the pass and is not a retry.
export async function refreshAccountProofs(
  db: EntitlementDb,
  uid: string,
  now: number,
  lookup: (proof: ProofRecord) => Promise<ProofLookup>,
): Promise<RefreshRun> {
  const products: Record<string, boolean> = {};
  let retry = false;
  const owned: ProofRecord[] = [];
  await db.forEachProof({ kind: 'account', uid }, async (row) => {
    if (row.proof.subscription) owned.push(row.proof);
  });
  for (const proof of owned) {
    try {
      const fetched = await lookup(proof);
      if (fetched.status === 'throttled') {
        return { products, retry: false, throttled: true };
      }
      if (fetched.status !== 'verified') {
        retry = true;
        continue;
      }
      const result = await grantPurchase(db, uid, fetched.purchase, now);
      if ('error' in result) {
        retry = true;
        continue;
      }
      Object.assign(products, result.products);
    } catch {
      retry = true;
    }
  }
  return { products, retry, throttled: false };
}

/**
 * One account refresh.
 *
 * A closed window returns throttled and does not mint. The slot is reserved
 * before a Play token is minted and before proofs are scanned. If the reserve
 * loses, nothing is minted. A call that cannot reach Play or the App Store
 * returns retry and does not reserve.
 */
export async function runEntitlementRefresh(input: {
  db: EntitlementDb;
  uid: string;
  now: number;
  node: unknown;
  canFetch: (proof: ProofRecord) => boolean;
  reserve: (now: number) => Promise<boolean>;
  lookup: (proof: ProofRecord) => Promise<Exclude<ProofLookup, { status: 'throttled' }>>;
  /** False when Play credentials and the App Store key are both missing. */
  canReachStore?: boolean;
  /** Mints the Play bearer after the slot is held. */
  mint?: () => Promise<void>;
}): Promise<RefreshRun> {
  if (!nextRefreshReservation(input.node, input.now).allowed) {
    return { products: {}, retry: false, throttled: true };
  }
  if (input.canReachStore === false) {
    return { products: {}, retry: true, throttled: false };
  }
  const reserved = await input.reserve(input.now);
  if (!reserved) {
    return { products: {}, retry: false, throttled: true };
  }
  if (input.mint) await input.mint();
  return refreshAccountProofs(input.db, input.uid, input.now, async (proof) => {
    if (!input.canFetch(proof)) return { status: 'unavailable' };
    return input.lookup(proof);
  });
}

export type AppleNotice = { kind: 'transaction'; purchase: VerifiedPurchase } | { kind: 'ignore' } | { kind: 'bad' };

export function appleNotice(
  body: unknown,
  now: number,
  toPurchase: (transaction: AppleTransaction) => VerifiedPurchase,
  rootPem?: string,
): AppleNotice {
  if (!body || typeof body !== 'object') return { kind: 'bad' };
  const signed = (body as { signedPayload?: unknown }).signedPayload;
  if (typeof signed !== 'string') return { kind: 'bad' };
  const payload = verifyAppleSignedPayload(signed, now, rootPem);
  if (!payload) return { kind: 'bad' };
  if (payload.notificationType === 'TEST') return { kind: 'ignore' };
  const data = payload.data;
  if (!data || typeof data !== 'object') return { kind: 'ignore' };
  if ((data as { bundleId?: unknown }).bundleId !== appStoreBundleId) return { kind: 'ignore' };
  const signedTransaction = (data as { signedTransactionInfo?: unknown }).signedTransactionInfo;
  if (typeof signedTransaction !== 'string') return { kind: 'ignore' };
  const transactionPayload = verifyAppleSignedPayload(signedTransaction, now, rootPem);
  if (!transactionPayload) return { kind: 'bad' };
  const signedRenewal = (data as { signedRenewalInfo?: unknown }).signedRenewalInfo;
  let renewal: AppleRenewalInfo | null = null;
  if (typeof signedRenewal === 'string' && signedRenewal.length > 0) {
    const renewalPayload = verifyAppleSignedPayload(signedRenewal, now, rootPem);
    if (!renewalPayload) return { kind: 'bad' };
    renewal = appleRenewalInfo(renewalPayload);
  }
  const transaction = appleTransaction(transactionPayload);
  const purchase = transaction ? toPurchase(transaction) : null;
  if (!transaction || !purchase) return { kind: 'ignore' };
  const applied = applyAppleRenewal({
    expiresAt: transaction.expiresAt,
    revoked: transaction.revoked,
    status: null,
    renewal,
    now,
  });
  purchase.expiresAt = applied.expiresAt;
  purchase.revoked = applied.revoked;
  purchase.willNotRenew = applied.willNotRenew;
  return { kind: 'transaction', purchase };
}

export type PlayNotice =
  | { kind: 'subscription'; token: string; productId: string }
  | { kind: 'product'; token: string; productId: string }
  | { kind: 'voided'; token: string };

export function playNotice(body: unknown): PlayNotice | null {
  if (!body || typeof body !== 'object') return null;
  const data = (body as { message?: { data?: unknown } }).message?.data;
  if (typeof data !== 'string' || data.length === 0) return null;
  let decoded: unknown;
  try {
    decoded = JSON.parse(Buffer.from(data, 'base64').toString('utf8'));
  } catch {
    return null;
  }
  if (!decoded || typeof decoded !== 'object') return null;
  const record = decoded as Record<string, unknown>;
  if (record.packageName !== playPackageName) return null;
  const subscription = record.subscriptionNotification;
  if (subscription && typeof subscription === 'object') {
    const token = (subscription as { purchaseToken?: unknown }).purchaseToken;
    const productId = (subscription as { subscriptionId?: unknown }).subscriptionId;
    // Current Play notices carry the token only. subscriptionsv2 names the product.
    if (typeof token === 'string' && token.length > 0) {
      return {
        kind: 'subscription',
        token,
        productId: typeof productId === 'string' ? productId : '',
      };
    }
  }
  const product = record.oneTimeProductNotification;
  if (product && typeof product === 'object') {
    const token = (product as { purchaseToken?: unknown }).purchaseToken;
    const productId = (product as { sku?: unknown }).sku;
    if (typeof token === 'string' && typeof productId === 'string') {
      return { kind: 'product', token, productId };
    }
  }
  const voided = record.voidedPurchaseNotification;
  if (voided && typeof voided === 'object') {
    const token = (voided as { purchaseToken?: unknown }).purchaseToken;
    if (typeof token === 'string') return { kind: 'voided', token };
  }
  return null;
}
