import assert from 'node:assert/strict';
import { test } from 'node:test';
import { playNotice } from './store_handlers';
import { playOneTime, playRenewalHoldMs, playSubscription } from './play_purchase';

const now = Date.parse('2026-10-06T12:00:00Z');

test('an active Play subscription stays on until expiry', () => {
  const parsed = playSubscription(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_CANCELED',
      lineItems: [{ productId: 'field_guide_yearly', expiryTime: '2027-10-06T12:00:00Z' }],
      externalAccountIdentifiers: { obfuscatedExternalAccountId: 'token-1' },
    },
    now,
  );
  assert.equal(parsed?.revoked, false);
  assert.equal(parsed?.willNotRenew, true);
  assert.equal(parsed?.expiresAt, Date.parse('2027-10-06T12:00:00Z'));
  assert.equal(parsed?.productId, 'field_guide_yearly');
  assert.equal(parsed?.obfuscatedAccountId, 'token-1');
});

test('a held or expired Play subscription does not grant', () => {
  assert.equal(
    playSubscription(
      {
        subscriptionState: 'SUBSCRIPTION_STATE_ON_HOLD',
        lineItems: [{ productId: 'field_guide_monthly', expiryTime: '2027-01-01T00:00:00Z' }],
      },
      now,
    )?.revoked,
    true,
  );
  assert.equal(
    playSubscription(
      {
        subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED',
        lineItems: [{ productId: 'field_guide_monthly', expiryTime: '2026-10-01T00:00:00Z' }],
      },
      now,
    )?.revoked,
    true,
  );
});

test('an active Play subscription stays granted while the next expiry is posted', () => {
  const expiry = now - 30_000;
  const parsed = playSubscription(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [{ productId: 'field_guide_monthly', expiryTime: new Date(expiry).toISOString() }],
    },
    now,
  );
  assert.equal(parsed?.revoked, false);
  assert.equal(parsed?.willNotRenew, false);
  assert.equal(parsed?.expiresAt, expiry + playRenewalHoldMs);
  const ended = playSubscription(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [{ productId: 'field_guide_monthly', expiryTime: '2026-10-01T00:00:00Z' }],
    },
    now,
  );
  assert.equal(ended?.revoked, true);
  assert.equal(ended?.expiresAt, Date.parse('2026-10-01T00:00:00Z'));
  const grace = playSubscription(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
      lineItems: [{ productId: 'field_guide_monthly', expiryTime: new Date(expiry).toISOString() }],
    },
    now,
  );
  assert.equal(grace?.revoked, false);
  assert.equal(grace?.willNotRenew, false);
});

test('a canceled or expired Play subscription ends when expiryTime has passed', () => {
  const ahead = playSubscription(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_CANCELED',
      testPurchase: {},
      lineItems: [{ productId: 'field_guide_monthly', expiryTime: '2026-10-06T12:05:00Z' }],
    },
    now,
  );
  assert.equal(ahead?.revoked, false);
  assert.equal(ahead?.willNotRenew, true);
  assert.equal(ahead?.expiresAt, Date.parse('2026-10-06T12:05:00Z'));

  const past = now - 30_000;
  const canceled = playSubscription(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_CANCELED',
      testPurchase: {},
      lineItems: [{ productId: 'field_guide_monthly', expiryTime: new Date(past).toISOString() }],
    },
    now,
  );
  assert.equal(canceled?.revoked, true);
  assert.equal(canceled?.willNotRenew, false);
  assert.equal(canceled?.expiresAt, past);

  const expired = playSubscription(
    {
      subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED',
      testPurchase: {},
      lineItems: [{ productId: 'field_guide_monthly', expiryTime: new Date(past).toISOString() }],
    },
    now,
  );
  assert.equal(expired?.revoked, true);
  assert.equal(expired?.willNotRenew, false);
  assert.equal(expired?.expiresAt, past);
});

test('a canceled or license-test one-time Play product does not grant', () => {
  assert.equal(playOneTime({ purchaseState: 0, obfuscatedExternalAccountId: 'abc' }, 'no_ads')?.revoked, false);
  assert.equal(playOneTime({ purchaseState: 0, purchaseType: 0 }, 'no_ads')?.revoked, true);
  assert.equal(playOneTime({ purchaseState: 1 }, 'offline')?.revoked, true);
  assert.equal(playOneTime({ purchaseState: 2 }, 'offline'), null);
});

test('a license-test Play subscription grants while it is active', () => {
  const yearly = {
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    lineItems: [{ productId: 'field_guide_yearly', expiryTime: '2027-10-06T12:00:00Z' }],
  };
  assert.equal(playSubscription(yearly, now)?.revoked, false);
  assert.equal(playSubscription({ ...yearly, testPurchase: {} }, now)?.revoked, false);
  assert.equal(playSubscription({ ...yearly, testPurchase: {} }, now)?.willNotRenew, false);
  assert.equal(
    playSubscription(
      {
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        testPurchase: {},
        lineItems: [{ productId: 'field_guide_monthly', expiryTime: '2026-10-01T00:00:00Z' }],
      },
      now,
    )?.revoked,
    true,
  );
});

test('a Play notification keeps the purchase token', () => {
  const data = Buffer.from(
    JSON.stringify({
      packageName: 'sk.ab.shrooms',
      subscriptionNotification: {
        notificationType: 2,
        purchaseToken: 'token-1',
        subscriptionId: 'field_guide_yearly',
      },
    }),
  ).toString('base64');
  assert.deepEqual(playNotice({ message: { data } }), {
    kind: 'subscription',
    token: 'token-1',
    productId: 'field_guide_yearly',
  });
  const bare = Buffer.from(
    JSON.stringify({
      packageName: 'sk.ab.shrooms',
      subscriptionNotification: { notificationType: 13, purchaseToken: 'token-22' },
    }),
  ).toString('base64');
  assert.deepEqual(playNotice({ message: { data: bare } }), {
    kind: 'subscription',
    token: 'token-22',
    productId: '',
  });
  assert.equal(playNotice({ message: { data: Buffer.from('{"packageName":"other"}').toString('base64') } }), null);
});
