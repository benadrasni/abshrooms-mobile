import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { test } from 'node:test';
import { signedJwt } from './jwt';
import { authorizePubSub, pubSubPushAllowed, verifyRs256 } from './pubsub_auth';
import { subscriptionProofs, type EntitlementDb } from './store_handlers';
import { purchaseIfVerified, type StoreFetch } from './store_fetch';
import type { VerifiedPurchase } from './entitlements';

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const pem = publicKey.export({ type: 'spki', format: 'pem' }).toString();
const privatePem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
const now = 1_700_000_000;
const email = 'play-push@abshrooms-a9d4c.iam.gserviceaccount.com';
const audience = 'https://us-central1-abshrooms-a9d4c.cloudfunctions.net/playStoreNotification';

function token(overrides: Record<string, unknown> = {}): string {
  return signedJwt(
    { alg: 'RS256', kid: 'test-key', typ: 'JWT' },
    {
      iss: 'https://accounts.google.com',
      email,
      email_verified: true,
      aud: audience,
      exp: now + 60,
      ...overrides,
    },
    privatePem,
    'RS256',
  );
}

test('a Play push needs a signed token for the configured service account', async () => {
  const claims = verifyRs256(token(), pem);
  assert.ok(claims);
  assert.equal(
    pubSubPushAllowed(claims, { nowSec: now, audiences: [audience], serviceAccount: email }),
    true,
  );
  assert.equal(
    pubSubPushAllowed(claims, { nowSec: now, audiences: [audience], serviceAccount: '' }),
    false,
  );
  assert.equal(
    await authorizePubSub(`Bearer ${token()}`, {
      nowSec: now,
      audiences: [audience],
      serviceAccount: email,
      keyForKid: async () => pem,
    }),
    true,
  );
  assert.equal(
    await authorizePubSub(`Bearer ${token({ aud: 'https://other.example' })}`, {
      nowSec: now,
      audiences: [audience],
      serviceAccount: email,
      keyForKid: async () => pem,
    }),
    false,
  );
  assert.equal(
    await authorizePubSub(undefined, {
      nowSec: now,
      audiences: [audience],
      serviceAccount: email,
      keyForKid: async () => pem,
    }),
    false,
  );
  const tampered = `${token().slice(0, -4)}abcd`;
  assert.equal(verifyRs256(tampered, pem), null);
});

test('an unverified store lookup is not stored as revoked', () => {
  const purchase: VerifiedPurchase = {
    store: 'play',
    productId: 'field_guide_yearly',
    token: 'token',
    expiresAt: now,
    revoked: false,
    accountToken: null,
    environment: null,
    subscription: true,
  };
  const verified: StoreFetch = { status: 'verified', purchase };
  const missing: StoreFetch = { status: 'unknown' };
  assert.equal(purchaseIfVerified(verified)?.revoked, false);
  assert.equal(purchaseIfVerified(missing), null);
});

test('subscription proofs include every stored subscription', async () => {
  const proofs: Record<string, unknown> = {};
  for (let index = 0; index < 501; index += 1) {
    proofs[`p${index}`] = {
      uid: 'user',
      store: 'play',
      productId: 'field_guide_yearly',
      token: `token-${index}`,
      subscription: true,
      active: true,
      updatedAt: 1,
    };
  }
  proofs.once = {
    uid: 'user',
    store: 'play',
    productId: 'other',
    token: 'once',
    subscription: false,
    active: true,
    updatedAt: 1,
  };
  const db = {
    get: async (path: string) => (path === 'purchase_proofs' ? proofs : null),
  } as EntitlementDb;
  const rows = await subscriptionProofs(db);
  assert.equal(rows.length, 501);
});
