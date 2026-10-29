import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  activeEntitlementIds,
  hasUnlimitedNames,
  planGrant,
  productsFromWrites,
  purchaseActive,
  type EntitlementRow,
  type VerifiedPurchase,
} from './entitlements';
import { grantPurchase, refreshAccountProofs, releaseStorePurchases, type EntitlementDb } from './store_handlers';
import { storeAccountToken } from './store_account';

const now = Date.parse('2026-10-06T12:00:00Z');
const uid = 'user-1';
const token = storeAccountToken(uid);

function yearly(overrides: Partial<VerifiedPurchase> = {}): VerifiedPurchase {
  return {
    store: 'app_store',
    productId: 'field_guide_yearly',
    token: '1000',
    expiresAt: now + 86_400_000,
    revoked: false,
    accountToken: token,
    environment: 'Production',
    subscription: true,
    ...overrides,
  };
}

test('a future expiry is active and a revocation is not', () => {
  assert.equal(purchaseActive({ revoked: false, expiresAt: now + 1 }, now), true);
  assert.equal(purchaseActive({ revoked: false, expiresAt: now }, now), false);
  assert.equal(purchaseActive({ revoked: true, expiresAt: now + 1 }, now), false);
  assert.equal(purchaseActive({ revoked: false, expiresAt: null }, now), true);
});

test('a checked subscription is written on the account and the other plan is cleared', () => {
  const monthly: EntitlementRow = {
    active: true,
    store: 'app_store',
    originalId: 'app_store_1000',
    updatedAt: now - 1,
  };
  const plan = planGrant({
    uid,
    now,
    purchase: yearly(),
    existing: null,
    previousOwnerExists: false,
    products: { field_guide_monthly: monthly },
  });
  assert.equal('error' in plan, false);
  if ('error' in plan) return;
  const products = productsFromWrites(plan.writes);
  assert.equal(products.field_guide_yearly, true);
  assert.equal(products.field_guide_monthly, false);
  assert.equal(plan.writes.some((write) => write.path === `store_accounts/${token}`), true);
});

test('a receipt named for another account is refused until that account is gone', () => {
  const foreign = storeAccountToken('user-2');
  const refused = planGrant({
    uid,
    now,
    purchase: yearly({ accountToken: foreign }),
    existing: null,
    previousOwnerExists: false,
    products: {},
  });
  assert.deepEqual(refused, { error: 'other-account' });

  const expired = planGrant({
    uid,
    now,
    purchase: yearly({ accountToken: foreign, expiresAt: now - 1 }),
    existing: {
      uid,
      store: 'app_store',
      productId: 'field_guide_yearly',
      token: '1000',
      accountToken: token,
      expiresAt: now + 1,
      environment: 'Production',
      subscription: true,
      active: true,
      updatedAt: now,
    },
    previousOwnerExists: false,
    products: {
      field_guide_yearly: {
        active: true,
        store: 'app_store',
        originalId: 'app_store_1000',
        updatedAt: now,
      },
    },
  });
  assert.equal('error' in expired, false);
  if ('error' in expired) return;
  assert.equal(productsFromWrites(expired.writes).field_guide_yearly, false);
  assert.equal(expired.writes.some((write) => write.path.startsWith('store_accounts/')), false);

  const rebound = planGrant({
    uid: 'user-2',
    now,
    purchase: yearly({ accountToken: token }),
    existing: {
      uid,
      store: 'app_store',
      productId: 'field_guide_yearly',
      token: '1000',
      accountToken: token,
      expiresAt: now + 1,
      environment: 'Production',
      subscription: true,
      active: true,
      updatedAt: now,
    },
    previousOwnerExists: false,
    products: {},
  });
  assert.equal('error' in rebound, false);
  if ('error' in rebound) return;
  assert.equal(productsFromWrites(rebound.writes).field_guide_yearly, true);
  assert.equal(
    rebound.writes.some((write) => write.path === `users/${uid}/entitlements/products/field_guide_yearly` && write.value == null),
    true,
  );
});

test('a receipt owned by a live account is refused', () => {
  const plan = planGrant({
    uid: 'user-2',
    now,
    purchase: yearly({ accountToken: storeAccountToken('user-2') }),
    existing: {
      uid,
      store: 'app_store',
      productId: 'field_guide_yearly',
      token: '1000',
      accountToken: token,
      expiresAt: now + 1,
      environment: 'Production',
      subscription: true,
      active: true,
      updatedAt: now,
    },
    previousOwnerExists: true,
    products: {},
  });
  assert.deepEqual(plan, { error: 'other-account' });
});

test('an expired receipt does not clear a different purchase of the same product', () => {
  const plan = planGrant({
    uid,
    now,
    purchase: yearly({ token: '2000', expiresAt: now - 1, accountToken: token }),
    existing: null,
    previousOwnerExists: false,
    products: {
      field_guide_yearly: {
        active: true,
        store: 'play',
        originalId: 'play_other',
        updatedAt: now,
      },
    },
  });
  assert.equal('error' in plan, false);
  if ('error' in plan) return;
  assert.equal(productsFromWrites(plan.writes).field_guide_yearly, undefined);
});

function putPath(root: Record<string, unknown>, path: string, value: unknown): void {
  const parts = path.split('/');
  let cursor = root;
  for (const part of parts.slice(0, -1)) {
    const next = cursor[part];
    if (!next || typeof next !== 'object') cursor[part] = {};
    cursor = cursor[part] as Record<string, unknown>;
  }
  cursor[parts[parts.length - 1]] = value;
}

test('a plan ends at expiresAt unless a later verified expiry is stored', () => {
  const row = (expiresAt?: number, active = true, willNotRenew = false): EntitlementRow => ({
    active,
    ...(expiresAt == null ? {} : { expiresAt }),
    ...(willNotRenew ? { willNotRenew: true } : {}),
    store: 'app_store',
    originalId: 'app_store_1000',
    updatedAt: now,
  });
  const user = (id: string, value: EntitlementRow) => ({
    entitlements: { products: { [id]: value } },
  });
  assert.deepEqual(activeEntitlementIds(user('field_guide_yearly', row(now + 1)), now), ['field_guide_yearly']);
  assert.deepEqual(activeEntitlementIds(user('field_guide_yearly', row(now)), now), []);
  assert.deepEqual(activeEntitlementIds(user('field_guide_yearly', row(now - 3_600_000)), now), []);
  assert.deepEqual(activeEntitlementIds(user('field_guide_yearly', row(now + 1, true, true)), now), ['field_guide_yearly']);
  assert.deepEqual(activeEntitlementIds(user('field_guide_yearly', row(now, true, true)), now), []);
  assert.deepEqual(activeEntitlementIds(user('field_guide_yearly', row(now - 1, true, true)), now), []);
  assert.deepEqual(activeEntitlementIds(user('field_guide_yearly', row()), now), ['field_guide_yearly']);
  assert.deepEqual(activeEntitlementIds(user('field_guide_yearly', row(now + 1, false)), now), []);
  assert.equal(hasUnlimitedNames(user('field_guide_yearly', row(now - 1)), now), false);
  assert.equal(hasUnlimitedNames(user('field_guide_yearly', row(now - 1, true, true)), now), false);
  assert.equal(hasUnlimitedNames(user('field_guide_yearly', row(now + 1, true, true)), now), true);
  assert.equal(hasUnlimitedNames(user('field_guide_yearly', row(now + 1)), now), true);
  assert.equal(hasUnlimitedNames(user('shrooms_field_guide_yearly', row(now + 1)), now), true);
  assert.equal(hasUnlimitedNames(user('search_by_photo', row(now + 1)), now), false);
  assert.equal(hasUnlimitedNames({ 'lifetime subscription': true }), true);
  assert.equal(
    hasUnlimitedNames({ 'lifetime subscription': true, ...user('field_guide_yearly', row(now - 1)) }, now),
    true,
  );
  assert.equal(hasUnlimitedNames({ 'lifetime subscription': false }), false);
  assert.equal(hasUnlimitedNames({ 'lifetime subscription': 'true' }), false);
  assert.equal(hasUnlimitedNames(null), false);
});

function memoryDb(live: (id: string) => boolean = (id) => id === uid): EntitlementDb & { tree: Record<string, unknown> } {
  const tree: Record<string, unknown> = {};
  const read = (path: string): unknown => {
    let cursor: unknown = tree;
    for (const part of path.split('/')) {
      if (!cursor || typeof cursor !== 'object' || !(part in cursor)) return null;
      cursor = (cursor as Record<string, unknown>)[part];
    }
    return cursor ?? null;
  };
  return {
    tree,
    async get(path) {
      return read(path);
    },
    async set(path, value) {
      putPath(tree, path, value);
    },
    async remove(path) {
      const parts = path.split('/');
      let cursor: unknown = tree;
      for (const part of parts.slice(0, -1)) {
        if (!cursor || typeof cursor !== 'object') return;
        cursor = (cursor as Record<string, unknown>)[part];
      }
      if (cursor && typeof cursor === 'object') {
        delete (cursor as Record<string, unknown>)[parts[parts.length - 1]];
      }
    },
    async transaction(path, update) {
      const stored = read(path);
      // Same order as the Realtime Database client: a cache miss, then the stored row.
      const guessed = update(null);
      if (guessed === undefined) return false;
      if (stored == null) {
        putPath(tree, path, guessed);
        return true;
      }
      const confirmed = update(stored);
      if (confirmed === undefined) return false;
      putPath(tree, path, confirmed);
      return true;
    },
    async authExists(id) {
      return live(id);
    },
  };
}

test('granting then releasing removes the proof and the account record', async () => {
  const db = memoryDb();
  const granted = await grantPurchase(db, uid, yearly(), now);
  assert.equal('products' in granted && granted.products.field_guide_yearly, true);
  const proofs = db.tree.purchase_proofs as Record<string, unknown>;
  assert.ok(proofs.app_store_1000);
  await releaseStorePurchases(db, uid);
  assert.equal(proofs.app_store_1000, undefined);
  const account = (db.tree.users as Record<string, Record<string, unknown>> | undefined)?.[uid];
  assert.equal(account?.entitlements, undefined);
  const accounts = db.tree.store_accounts as Record<string, unknown> | undefined;
  assert.equal(accounts?.[token], undefined);
});

test('a receipt without an account token is claimed by the first live account', async () => {
  const db = memoryDb(() => true);
  const purchase = yearly({ accountToken: null });
  const first = await grantPurchase(db, uid, purchase, now);
  assert.equal('products' in first && first.products.field_guide_yearly, true);
  const again = await grantPurchase(db, uid, purchase, now + 1);
  assert.equal('products' in again && again.products.field_guide_yearly, true);
  const second = await grantPurchase(db, 'user-2', purchase, now);
  assert.deepEqual(second, { error: 'other-account' });
});

test('two concurrent claims of a token-less receipt cannot both win', async () => {
  const db = memoryDb(() => true);
  const purchase = yearly({ accountToken: null });
  const [left, right] = await Promise.all([
    grantPurchase(db, uid, purchase, now),
    grantPurchase(db, 'user-2', purchase, now),
  ]);
  const won = [left, right].filter((result) => 'products' in result);
  const lost = [left, right].filter((result) => 'error' in result);
  assert.equal(won.length, 1);
  assert.equal(lost.length, 1);
  assert.equal('error' in lost[0] && lost[0].error, 'other-account');
  const proofs = db.tree.purchase_proofs as Record<string, { uid: string }>;
  const owner = proofs.app_store_1000.uid;
  const users = db.tree.users as Record<string, { entitlements?: unknown }>;
  assert.ok(users[owner]?.entitlements);
  const other = owner === uid ? 'user-2' : uid;
  assert.equal(users[other]?.entitlements, undefined);
});

type StoredRow = { active?: boolean; willNotRenew?: boolean; expiresAt?: number };

function storedProduct(db: { tree: Record<string, unknown> }, owner: string, productId: string): StoredRow {
  const users = db.tree.users as Record<string, { entitlements?: { products?: Record<string, StoredRow> } }>;
  return users[owner]?.entitlements?.products?.[productId] ?? {};
}

test('a stored token is read again and an unverified lookup is not a cancel', async () => {
  const db = memoryDb();
  const purchase = yearly({
    store: 'play',
    token: 'play-token-1',
    productId: 'field_guide_monthly',
    accountToken: token,
  });
  const granted = await grantPurchase(db, uid, purchase, now);
  assert.equal('products' in granted && granted.products.field_guide_monthly, true);
  await grantPurchase(
    db,
    'user-2',
    yearly({
      store: 'play',
      token: 'play-token-2',
      productId: 'field_guide_yearly',
      accountToken: storeAccountToken('user-2'),
    }),
    now,
  );

  let seen = '';
  let calls = 0;
  const unknown = await refreshAccountProofs(db, uid, now + 1, async (proof) => {
    calls += 1;
    seen = proof.token;
    return { status: 'unknown' };
  });
  assert.equal(calls, 1);
  assert.equal(seen, 'play-token-1');
  assert.equal(unknown.retry, true);
  assert.deepEqual(unknown.products, {});
  assert.equal(storedProduct(db, uid, 'field_guide_monthly').active, true);

  const unavailable = await refreshAccountProofs(db, uid, now + 1, async () => {
    throw new Error('play down');
  });
  assert.equal(unavailable.retry, true);
  assert.equal(storedProduct(db, uid, 'field_guide_monthly').active, true);

  const ending = await refreshAccountProofs(db, uid, now + 2, async () => ({
    status: 'verified',
    purchase: yearly({
      store: 'play',
      token: 'play-token-1',
      productId: 'field_guide_monthly',
      expiresAt: now + 300_000,
      revoked: false,
      willNotRenew: true,
      accountToken: token,
    }),
  }));
  assert.equal(ending.retry, false);
  assert.equal(ending.products.field_guide_monthly, true);
  assert.equal(storedProduct(db, uid, 'field_guide_monthly').willNotRenew, true);
  assert.equal(storedProduct(db, uid, 'field_guide_monthly').expiresAt, now + 300_000);
  assert.equal(storedProduct(db, 'user-2', 'field_guide_yearly').active, true);

  const ended = await refreshAccountProofs(db, uid, now + 3, async () => ({
    status: 'verified',
    purchase: yearly({
      store: 'play',
      token: 'play-token-1',
      productId: 'field_guide_monthly',
      expiresAt: now - 1,
      revoked: true,
      willNotRenew: false,
      accountToken: token,
    }),
  }));
  assert.equal(ended.retry, false);
  assert.equal(ended.products.field_guide_monthly, false);
  assert.equal(storedProduct(db, uid, 'field_guide_monthly').active, false);
  assert.equal(storedProduct(db, uid, 'field_guide_monthly').willNotRenew, false);
});

test('an unverified re-check does not keep a lapsed plan, and a verified renewal does', async () => {
  const db = memoryDb();
  const expiresAt = now + 1_000;
  const granted = await grantPurchase(db, uid, yearly({ expiresAt }), now);
  assert.equal('products' in granted && granted.products.field_guide_yearly, true);
  const user = () => (db.tree.users as Record<string, Record<string, unknown>>)[uid];
  assert.deepEqual(activeEntitlementIds(user(), expiresAt - 1), ['field_guide_yearly']);

  const unknown = await refreshAccountProofs(db, uid, expiresAt + 1, async () => ({ status: 'unknown' }));
  assert.equal(unknown.retry, true);
  assert.equal(storedProduct(db, uid, 'field_guide_yearly').active, true);
  assert.deepEqual(activeEntitlementIds(user(), expiresAt + 1), []);

  const renewed = await refreshAccountProofs(db, uid, expiresAt + 1, async () => ({
    status: 'verified',
    purchase: yearly({ expiresAt: expiresAt + 86_400_000, willNotRenew: false }),
  }));
  assert.equal(renewed.retry, false);
  assert.equal(renewed.products.field_guide_yearly, true);
  assert.deepEqual(activeEntitlementIds(user(), expiresAt + 1), ['field_guide_yearly']);
  assert.equal(storedProduct(db, uid, 'field_guide_yearly').expiresAt, expiresAt + 86_400_000);
});

test('an Apple plan that will not renew is stored and still ends at expiresAt', () => {
  const plan = planGrant({
    uid,
    now,
    purchase: yearly({ willNotRenew: true, expiresAt: now + 1 }),
    existing: null,
    previousOwnerExists: false,
    products: {},
  });
  assert.equal('error' in plan, false);
  if ('error' in plan) return;
  const written = plan.writes.find((write) => write.path.endsWith('/field_guide_yearly'));
  const value = written?.value as EntitlementRow;
  assert.equal(value.willNotRenew, true);
  assert.equal(value.active, true);
  assert.deepEqual(
    activeEntitlementIds({ entitlements: { products: { field_guide_yearly: value } } }, now + 2),
    [],
  );
});
