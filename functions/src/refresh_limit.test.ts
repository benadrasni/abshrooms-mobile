import assert from 'node:assert/strict';
import { test } from 'node:test';
import { refreshEntitlementsEnforceAppCheck, refreshEntitlementsMinGapMs, stampRefresh } from './refresh_limit';
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
  assert.equal(refreshEntitlementsEnforceAppCheck, true);
});

test('throttle skips the lookup, and the slot is reserved only when a lookup starts', async () => {
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
  assert.deepEqual(idle, []);

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
