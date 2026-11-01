import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  mintPlayBearerIfDue,
  refreshEntitlementsEnforceAppCheck,
  refreshEntitlementsMinGapMs,
  stampRefresh,
} from './refresh_limit';
import type { VerifiedPurchase } from './entitlements';
import { runEntitlementRefresh, type EntitlementDb } from './store_handlers';

const now = Date.parse('2026-10-06T12:00:00Z');
const uid = 'user-1';

function proofDb(): EntitlementDb {
  const proofs = {
    play_1: {
      uid,
      store: 'play',
      productId: 'field_guide_monthly',
      token: 'play-token-1',
      subscription: true,
      active: true,
      updatedAt: 1,
    },
  };
  return {
    async get(path) {
      return path === 'purchase_proofs' ? proofs : null;
    },
    async set() {},
    async remove() {},
    async transaction() {
      return false;
    },
    async authExists() {
      return true;
    },
  };
}

test('a refresh stamp keeps the products and ignores a call inside the window', () => {
  const first = stampRefresh(
    { products: { field_guide_yearly: { active: true } } },
    now,
  );
  assert.equal(first.reserved, true);
  if (!first.reserved) return;
  assert.equal(first.entitlements.refreshedAt, now);
  const products = first.entitlements.products as { field_guide_yearly?: { active?: boolean } };
  assert.equal(products.field_guide_yearly?.active, true);

  const again = stampRefresh(first.entitlements, now + refreshEntitlementsMinGapMs - 1);
  assert.equal(again.reserved, false);
  assert.equal(refreshEntitlementsEnforceAppCheck, false);
});

test('a throttled refresh does not mint a Play bearer', async () => {
  const events: string[] = [];
  const blocked = await mintPlayBearerIfDue({ refreshedAt: now }, now + 1_000, async () => {
    events.push('bearer');
  });
  assert.equal(blocked, false);
  assert.equal(events.length, 0);

  const opened = await mintPlayBearerIfDue(null, now, async () => {
    events.push('bearer');
  });
  assert.equal(opened, true);
  assert.deepEqual(events, ['bearer']);
});

test('throttle skips the lookup, and the slot is reserved before proofs are scanned', async () => {
  const db = proofDb();
  let node: unknown = { refreshedAt: now };
  const blocked: string[] = [];
  const throttled = await runEntitlementRefresh({
    db,
    uid,
    now: now + 1_000,
    node,
    canFetch: () => true,
    reserve: async () => {
      blocked.push('reserve');
      return true;
    },
    lookup: async () => {
      blocked.push('lookup');
      return { status: 'unavailable' };
    },
  });
  assert.equal(throttled.throttled, true);
  assert.equal(throttled.retry, false);
  assert.deepEqual(blocked, []);

  node = null;
  const idle: string[] = [];
  const skipped = await runEntitlementRefresh({
    db,
    uid,
    now,
    node,
    canFetch: () => false,
    reserve: async () => {
      idle.push('reserve');
      return true;
    },
    lookup: async () => {
      idle.push('lookup');
      return { status: 'verified', purchase: samplePurchase() };
    },
  });
  assert.equal(skipped.throttled, false);
  assert.equal(skipped.retry, true);
  assert.deepEqual(idle, ['reserve']);

  const startedEvents: string[] = [];
  const started = await runEntitlementRefresh({
    db,
    uid,
    now,
    node,
    canFetch: () => true,
    reserve: async (at) => {
      startedEvents.push('reserve');
      const stamped = stampRefresh(node, at);
      if (!stamped.reserved) return false;
      node = stamped.entitlements;
      return true;
    },
    lookup: async () => {
      startedEvents.push('lookup');
      return { status: 'unavailable' };
    },
  });
  assert.equal(started.throttled, false);
  assert.equal(started.retry, true);
  assert.deepEqual(startedEvents, ['reserve', 'lookup']);

  const again: string[] = [];
  const second = await runEntitlementRefresh({
    db,
    uid,
    now: now + 1_000,
    node,
    canFetch: () => true,
    reserve: async () => {
      again.push('reserve');
      return true;
    },
    lookup: async () => {
      again.push('lookup');
      return { status: 'unavailable' };
    },
  });
  assert.equal(second.throttled, true);
  assert.equal(second.retry, false);
  assert.deepEqual(again, []);
});

test('parallel refreshes reserve once and scan the proofs once', async () => {
  let slot: unknown = null;
  let scans = 0;
  const proofs = {
    play_1: {
      uid,
      store: 'play',
      productId: 'field_guide_monthly',
      token: 'play-token-1',
      subscription: true,
      active: true,
      updatedAt: 1,
    },
  };
  const db: EntitlementDb = {
    async get(path) {
      if (path === 'purchase_proofs') {
        scans += 1;
        return proofs;
      }
      return null;
    },
    async set() {},
    async remove() {},
    async transaction() {
      return false;
    },
    async authExists() {
      return true;
    },
  };
  let chain = Promise.resolve();
  const reserve = (at: number) => {
    const run = chain.then(() => {
      const stamped = stampRefresh(slot, at);
      if (!stamped.reserved) return false;
      slot = stamped.entitlements;
      return true;
    });
    chain = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  };
  const [first, second] = await Promise.all([
    runEntitlementRefresh({
      db,
      uid,
      now,
      node: null,
      canFetch: () => true,
      reserve,
      lookup: async () => ({ status: 'unavailable' }),
    }),
    runEntitlementRefresh({
      db,
      uid,
      now,
      node: null,
      canFetch: () => true,
      reserve,
      lookup: async () => ({ status: 'unavailable' }),
    }),
  ]);
  assert.equal(scans, 1);
  assert.equal(first.throttled !== second.throttled, true);
});

function samplePurchase(): VerifiedPurchase {
  return {
    store: 'play',
    productId: 'field_guide_monthly',
    token: 'play-token-1',
    expiresAt: now + 1,
    revoked: false,
    accountToken: null,
    environment: null,
    subscription: true,
  };
}
