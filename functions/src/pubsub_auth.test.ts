import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { test } from 'node:test';
import { signedJwt } from './jwt';
import { authorizePubSub, pubSubPushAllowed, verifyRs256 } from './pubsub_auth';
import { pageItems } from './store_handlers';
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

test('the daily refresh walks past the first 500 proofs', () => {
  const ids = Array.from({ length: 501 }, (_, index) => index);
  const pages = pageItems(ids, 500);
  assert.equal(pages.length, 2);
  assert.equal(pages[0].length, 500);
  assert.deepEqual(pages[1], [500]);
  assert.equal(pages.flat().length, 501);
});
