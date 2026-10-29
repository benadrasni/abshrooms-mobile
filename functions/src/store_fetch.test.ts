import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { AppleTransaction } from './apple_jws';
import { StoreUnavailable, chooseAppleStatusPurchase, readAppleSubscriptionStatus } from './store_fetch';

const now = Date.parse('2026-10-06T12:00:00Z');

function tx(id: string, productId: string, expiresAt: number, revoked = false): AppleTransaction {
  return {
    productId,
    originalTransactionId: id,
    expiresAt,
    revoked,
    appAccountToken: null,
    environment: 'Production',
  };
}

test('a refunded yearly is not replaced by another subscription grace date', () => {
  const yearlyExpires = now + 86_400_000;
  const graceAt = now + 10 * 86_400_000;
  const purchase = chooseAppleStatusPurchase(
    [
      {
        transaction: tx('1000', 'field_guide_yearly', yearlyExpires),
        status: 5,
        renewal: { autoRenewStatus: 0, gracePeriodExpiresAt: null },
      },
      {
        transaction: tx('2000', 'field_guide_monthly', now - 1_000),
        status: 4,
        renewal: { autoRenewStatus: 1, gracePeriodExpiresAt: graceAt },
      },
    ],
    '1000',
    'field_guide_yearly',
    now,
  );
  assert.equal(purchase.productId, 'field_guide_yearly');
  assert.equal(purchase.token, '1000');
  assert.equal(purchase.revoked, true);
  assert.equal(purchase.expiresAt, yearlyExpires);
  assert.notEqual(purchase.expiresAt, graceAt);
});

test('a revoked row does not outrank an active row on the same original transaction', () => {
  const purchase = chooseAppleStatusPurchase(
    [
      {
        transaction: tx('1000', 'field_guide_yearly', now + 10 * 86_400_000, true),
        status: 5,
        renewal: { autoRenewStatus: 0, gracePeriodExpiresAt: null },
      },
      {
        transaction: tx('1000', 'field_guide_yearly', now + 86_400_000),
        status: 1,
        renewal: { autoRenewStatus: 1, gracePeriodExpiresAt: null },
      },
    ],
    '1000',
    'field_guide_yearly',
    now,
  );
  assert.equal(purchase.revoked, false);
  assert.equal(purchase.expiresAt, now + 86_400_000);
});

test('a different product on the same original transaction is not granted', () => {
  assert.throws(
    () =>
      chooseAppleStatusPurchase(
        [
          {
            transaction: tx('1000', 'field_guide_monthly', now + 86_400_000),
            status: 1,
            renewal: { autoRenewStatus: 1, gracePeriodExpiresAt: null },
          },
        ],
        '1000',
        'field_guide_yearly',
        now,
      ),
    (error: unknown) => error instanceof StoreUnavailable,
  );
});

test('a signed renewal that does not verify writes nothing', () => {
  const verify = (jws: string) => {
    if (jws === 'yearly') {
      return {
        bundleId: 'sk.ab.shrooms',
        productId: 'field_guide_yearly',
        originalTransactionId: '1000',
        expiresDate: now - 1_000,
      };
    }
    return null;
  };
  assert.throws(
    () =>
      readAppleSubscriptionStatus({
        body: {
          data: [
            {
              lastTransactions: [
                { status: 4, signedTransactionInfo: 'yearly', signedRenewalInfo: 'broken' },
              ],
            },
          ],
        },
        originalTransactionId: '1000',
        productId: 'field_guide_yearly',
        now,
        verify,
      }),
    (error: unknown) => error instanceof StoreUnavailable,
  );
});

test('grace is applied from a verified renewal and not from another subscription', () => {
  const graceAt = now + 50_000;
  const verify = (jws: string) => {
    const table: Record<string, Record<string, unknown>> = {
      yearly: {
        bundleId: 'sk.ab.shrooms',
        productId: 'field_guide_yearly',
        originalTransactionId: '1000',
        expiresDate: now + 86_400_000,
        revocationDate: now - 10,
      },
      yearlyRenewal: { autoRenewStatus: 0, originalTransactionId: '1000' },
      monthly: {
        bundleId: 'sk.ab.shrooms',
        productId: 'field_guide_monthly',
        originalTransactionId: '2000',
        expiresDate: now - 1_000,
      },
      grace: { autoRenewStatus: 1, gracePeriodExpiresDate: graceAt, originalTransactionId: '2000' },
    };
    return table[jws] ?? null;
  };
  const body = {
    data: [
      {
        lastTransactions: [
          { status: 5, signedTransactionInfo: 'yearly', signedRenewalInfo: 'yearlyRenewal' },
          { status: 4, signedTransactionInfo: 'monthly', signedRenewalInfo: 'grace' },
        ],
      },
    ],
  };
  const yearly = readAppleSubscriptionStatus({
    body,
    originalTransactionId: '1000',
    productId: 'field_guide_yearly',
    now,
    verify,
  });
  assert.equal(yearly.productId, 'field_guide_yearly');
  assert.equal(yearly.revoked, true);
  assert.notEqual(yearly.expiresAt, graceAt);

  const monthly = readAppleSubscriptionStatus({
    body,
    originalTransactionId: '2000',
    productId: 'field_guide_monthly',
    now,
    verify,
  });
  assert.equal(monthly.productId, 'field_guide_monthly');
  assert.equal(monthly.revoked, false);
  assert.equal(monthly.expiresAt, graceAt);
});
