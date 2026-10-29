import assert from 'node:assert/strict';
import { createPrivateKey, X509Certificate } from 'node:crypto';
import { test } from 'node:test';
import {
  appleRenewalHoldMs,
  appleRenewalInfo,
  appleRootCaG3Pem,
  appleRootFingerprint256,
  appleStatusEntries,
  appleTransaction,
  applyAppleRenewal,
  verifyAppleSignedPayload,
} from './apple_jws';
import { signedJwt } from './jwt';
import { appleNotice } from './store_handlers';
import type { VerifiedPurchase } from './entitlements';

const rootPem = `-----BEGIN CERTIFICATE-----
MIIBPDCB46ADAgECAhQ3h/DhJ/IiBwnRLQIEg/KU6KjAvzAKBggqhkjOPQQDAjAU
MRIwEAYDVQQDDAlUZXN0IFJvb3QwHhcNMjQwMTAxMDAwMDAwWhcNMzYwMTAxMDAw
MDAwWjAUMRIwEAYDVQQDDAlUZXN0IFJvb3QwWTATBgcqhkjOPQIBBggqhkjOPQMB
BwNCAAQItEGmwbJSExibjKklKRY2X6DBFX+4n8jRxgBzxWZOS9rz/mhW8Mw8nlGZ
v5iO1Y4ECViwrJ16pMYmDB0BBoC3oxMwETAPBgNVHRMBAf8EBTADAQH/MAoGCCqG
SM49BAMCA0gAMEUCIQD/VPYoGMMM8D2hiOxLllf8IzuAs0jko/6DldTDUV9vxwIg
I9eY1yhRcLx83fIcMekuz+N+V6Nc+cnlxJI/AyZ/+IE=
-----END CERTIFICATE-----`;

const intermediatePem = `-----BEGIN CERTIFICATE-----
MIIBVjCB/aADAgECAhRUKn4Pw/iN355N2hbo+gZC2tV/gjAKBggqhkjOPQQDAjAU
MRIwEAYDVQQDDAlUZXN0IFJvb3QwHhcNMjQwMTAxMDAwMDAwWhcNMzYwMTAxMDAw
MDAwWjAcMRowGAYDVQQDDBFUZXN0IEludGVybWVkaWF0ZTBZMBMGByqGSM49AgEG
CCqGSM49AwEHA0IABN5EXFJUdFQdG7VHdKi/T1b2Lx2HedAeA4dAI2zHepqrVyMW
uYxkmCRtoX0z9jAOo02ZP5on8gyh9c8FLS5b9UWjJTAjMA8GA1UdEwEB/wQFMAMB
Af8wEAYKKoZIhvdjZAYCAQQCBQAwCgYIKoZIzj0EAwIDSAAwRQIhAKk0JiR0eWlM
fCJDM8maAopAElBdX60WDNF/tJMMn+0hAiAk5NkMXe7sHtpE76hSVG5CsFmB+/19
k0ir6X1+E9CQvQ==
-----END CERTIFICATE-----`;

const leafPem = `-----BEGIN CERTIFICATE-----
MIIBUzCB+qADAgECAhQKlFp4Vq0TddhXhw/8Vk9eCdVdqDAKBggqhkjOPQQDAjAc
MRowGAYDVQQDDBFUZXN0IEludGVybWVkaWF0ZTAeFw0yNDAxMDEwMDAwMDBaFw0z
NjAxMDEwMDAwMDBaMBQxEjAQBgNVBAMMCVRlc3QgTGVhZjBZMBMGByqGSM49AgEG
CCqGSM49AwEHA0IABNVHxsdn2nQHC9BrV4sPRtZhYYVegNUvhUhyoIv3YYugPYzC
iS+PlhlzowzBoYrOsF+xw7Z10baxZGgHn1BKHb+jIjAgMAwGA1UdEwEB/wQCMAAw
EAYKKoZIhvdjZAYLAQQCBQAwCgYIKoZIzj0EAwIDSAAwRQIgQ7jORg6vKKYX+rRN
x4zT8MEjNRcqqT4LJvDnVOrXmbgCIQDbi5AK04gwNK7+/aWa0+UJsDRAahyv6zVl
E5eKoxtCMw==
-----END CERTIFICATE-----`;

const leafKey = `-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIGJXcQnAKR9CFgmk9YiygY5nBYpD8AkDS/lIa6K5JbjkoAoGCCqGSM49
AwEHoUQDQgAE1UfGx2fadAcL0GtXiw9G1mFhhV6A1S+FSHKgi/dhi6A9jMKJL4+W
GXOjDMGhis6wX7HDtnXRtrFkaAefUEodvw==
-----END EC PRIVATE KEY-----`;

const directPem = `-----BEGIN CERTIFICATE-----
MIIBTjCB9KADAgECAhQ/+CyY7SL4W77+vpByFRqH9v4whjAKBggqhkjOPQQDAjAU
MRIwEAYDVQQDDAlUZXN0IFJvb3QwHhcNMjQwMTAxMDAwMDAwWhcNMzYwMTAxMDAw
MDAwWjAWMRQwEgYDVQQDDAtUZXN0IERpcmVjdDBZMBMGByqGSM49AgEGCCqGSM49
AwEHA0IABKbakSqKrhAwLLLUyHk2WSxWydR82pwUt+kWrH58dNJZ76HFZq9GTbBg
LaOxx44ri7sYLkfujcuZz/7cYfJmu0+jIjAgMAwGA1UdEwEB/wQCMAAwEAYKKoZI
hvdjZAYLAQQCBQAwCgYIKoZIzj0EAwIDSQAwRgIhAMmT85nD60/MVOv/3GFvn2qD
VqObbznYT3GET/UPmo5XAiEAqiYaqVB29AJXYySzm3KpeMEF8VUlzj4IeR8v3XFe
efA=
-----END CERTIFICATE-----`;

const directKey = `-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIGr3LAMwefbw2bDUP9GsTUEkRG9tQRksvvbrpeO7L/dmoAoGCCqGSM49
AwEHoUQDQgAEptqRKoquEDAsstTIeTZZLFbJ1HzanBS36Rasfnx00lnvocVmr0ZN
sGAto7HHjiuLuxguR+6Ny5nP/txh8ma7Tw==
-----END EC PRIVATE KEY-----`;

const plainPem = `-----BEGIN CERTIFICATE-----
MIIBQjCB6aADAgECAhQbTLNfX1yjjNwomChEvMVfIsX9oDAKBggqhkjOPQQDAjAc
MRowGAYDVQQDDBFUZXN0IEludGVybWVkaWF0ZTAeFw0yNDAxMDEwMDAwMDBaFw0z
NjAxMDEwMDAwMDBaMBUxEzARBgNVBAMMClRlc3QgUGxhaW4wWTATBgcqhkjOPQIB
BggqhkjOPQMBBwNCAAQ2HQxT/71hJXMoELk1ziUVM8lzPa2JKXZatry3exHsLicV
10nVxEkR7FnJcRA5uou4NeO5VTMVxDc3urpalGRSoxAwDjAMBgNVHRMBAf8EAjAA
MAoGCCqGSM49BAMCA0gAMEUCIQCjSSfArr7O/kftgQsPlvpMz4/uvH5CZ4/82DXW
V9Jl0AIgfH/HdlsHvJqtwiQnb2B0PD+2H6e3uXZOEo/WgpIPoIk=
-----END CERTIFICATE-----`;

const plainKey = `-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIHF/j3sPnXWzVy2BcCDWN+RKs8jI3AkNGd5MY4Hu6aSQoAoGCCqGSM49
AwEHoUQDQgAENh0MU/+9YSVzKBC5Nc4lFTPJcz2tiSl2Wra8t3sR7C4nFddJ1cRJ
EexZyXEQObqLuDXjuVUzFcQ3N7q6WpRkUg==
-----END EC PRIVATE KEY-----`;

const noCaPem = `-----BEGIN CERTIFICATE-----
MIIBSjCB8qADAgECAhQ2gxai99O3A0CF1ljZ3PtM9no/szAKBggqhkjOPQQDAjAU
MRIwEAYDVQQDDAlUZXN0IFJvb3QwHhcNMjQwMTAxMDAwMDAwWhcNMzYwMTAxMDAw
MDAwWjAUMRIwEAYDVQQDDAlUZXN0IE5vQ0EwWTATBgcqhkjOPQIBBggqhkjOPQMB
BwNCAAQ3KvcrwwHj2DgBX0/G4lq3gL5znR72oxStsD97Jzjkl9peVPnhXRS+ZHah
ycAJttTfaWUEtWZflsJV2n0IorZooyIwIDAMBgNVHRMBAf8EAjAAMBAGCiqGSIb3
Y2QGAgEEAgUAMAoGCCqGSM49BAMCA0cAMEQCICSVvC1IR81c35u+z9RYM4BxzdCn
lxMpsAXXoHCsYWy7AiApXWclU3KCBduAIJOIKbCNa0yuhqIEivHb66S4qdHGfQ==
-----END CERTIFICATE-----`;

const leafUnderNoCaPem = `-----BEGIN CERTIFICATE-----
MIIBTDCB86ADAgECAhQK8/kpuv57TAQjaFrM7vEUo2d31zAKBggqhkjOPQQDAjAU
MRIwEAYDVQQDDAlUZXN0IE5vQ0EwHhcNMjQwMTAxMDAwMDAwWhcNMzYwMTAxMDAw
MDAwWjAVMRMwEQYDVQQDDApUZXN0IExlYWYyMFkwEwYHKoZIzj0CAQYIKoZIzj0D
AQcDQgAEMeNOYfRrWw4d6AqOOSnLIGT5RRScRZqm9sm95Aryxnp98kITnkxaMtwU
Vd3SGBcj3XyjzHnIQUvFMuB6iiVw3KMiMCAwDAYDVR0TAQH/BAIwADAQBgoqhkiG
92NkBgsBBAIFADAKBggqhkjOPQQDAgNIADBFAiBaX6A3I8zKG0a10fOzdx9wYJQk
vEncrNsmxws5k66SvwIhAIxaKgKggOyyEAlwG4g9uEoGOvsAgEKB19a9rWJttcrp
-----END CERTIFICATE-----`;

const leafUnderNoCaKey = `-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIJYBFJmOyeJn+sBNfmtx8WSFhRdGQfzqaYpdjbslrhLxoAoGCCqGSM49
AwEHoUQDQgAEMeNOYfRrWw4d6AqOOSnLIGT5RRScRZqm9sm95Aryxnp98kITnkxa
MtwUVd3SGBcj3XyjzHnIQUvFMuB6iiVw3A==
-----END EC PRIVATE KEY-----`;

const now = Date.parse('2026-10-06T21:00:00Z');

function jws(payload: Record<string, unknown>, certs: string[], privateKey: string): string {
  const x5c = certs.map((pem) => new X509Certificate(pem).raw.toString('base64'));
  return signedJwt({ alg: 'ES256', x5c } as unknown as Record<string, string>, payload, privateKey, 'ES256');
}

function transaction(): Record<string, unknown> {
  return {
    bundleId: 'sk.ab.shrooms',
    productId: 'field_guide_yearly',
    originalTransactionId: '1000',
    expiresDate: now + 1000,
    environment: 'Sandbox',
  };
}

test('the pinned Apple root matches its published fingerprint', () => {
  assert.equal(new X509Certificate(appleRootCaG3Pem).fingerprint256, appleRootFingerprint256);
});

test('a chained StoreKit transaction verifies and a changed payload does not', () => {
  const signed = jws(transaction(), [leafPem, intermediatePem, rootPem], leafKey);
  const payload = verifyAppleSignedPayload(signed, now, rootPem);
  assert.ok(payload);
  assert.equal(appleTransaction(payload)?.productId, 'field_guide_yearly');
  assert.equal(appleTransaction({ ...payload, bundleId: 'other.app' }), null);

  const parts = signed.split('.');
  const tampered = `${parts[0]}.${Buffer.from('{"bundleId":"sk.ab.shrooms"}').toString('base64url')}.${parts[2]}`;
  assert.equal(verifyAppleSignedPayload(tampered, now, rootPem), null);
  assert.equal(createPrivateKey(leafKey).asymmetricKeyType, 'ec');
});

test('a leaf signed straight by the root is rejected', () => {
  const signed = jws(transaction(), [directPem, rootPem], directKey);
  assert.equal(verifyAppleSignedPayload(signed, now, rootPem), null);
});

test('a leaf missing the receipt OID is rejected', () => {
  const signed = jws(transaction(), [plainPem, intermediatePem, rootPem], plainKey);
  assert.equal(verifyAppleSignedPayload(signed, now, rootPem), null);
});

test('an intermediate without the CA bit is rejected', () => {
  const signed = jws(transaction(), [leafUnderNoCaPem, noCaPem, rootPem], leafUnderNoCaKey);
  assert.equal(verifyAppleSignedPayload(signed, now, rootPem), null);
});

test('Apple renewal status ends a lapsed plan unless a verified renewal extends it', () => {
  const future = now + 86_400_000;
  const active = applyAppleRenewal({
    expiresAt: future,
    revoked: false,
    status: 1,
    renewal: appleRenewalInfo({ autoRenewStatus: 1 }),
    now,
  });
  assert.equal(active.revoked, false);
  assert.equal(active.willNotRenew, false);
  assert.equal(active.expiresAt, future);

  const canceled = applyAppleRenewal({
    expiresAt: future,
    revoked: false,
    status: 1,
    renewal: appleRenewalInfo({ autoRenewStatus: 0 }),
    now,
  });
  assert.equal(canceled.willNotRenew, true);
  assert.equal(canceled.revoked, false);
  assert.equal(canceled.expiresAt, future);

  const stale = now - 1_000;
  const held = applyAppleRenewal({
    expiresAt: stale,
    revoked: false,
    status: 1,
    renewal: appleRenewalInfo({ autoRenewStatus: 1 }),
    now,
  });
  assert.equal(held.revoked, false);
  assert.equal(held.willNotRenew, false);
  assert.equal(held.expiresAt, stale + appleRenewalHoldMs);

  const canceledLapsed = applyAppleRenewal({
    expiresAt: stale,
    revoked: false,
    status: 1,
    renewal: appleRenewalInfo({ autoRenewStatus: 0 }),
    now,
  });
  assert.equal(canceledLapsed.revoked, false);
  assert.equal(canceledLapsed.willNotRenew, false);
  assert.equal(canceledLapsed.expiresAt, stale);

  const tooOld = applyAppleRenewal({
    expiresAt: now - appleRenewalHoldMs,
    revoked: false,
    status: 1,
    renewal: appleRenewalInfo({ autoRenewStatus: 1 }),
    now,
  });
  assert.equal(tooOld.revoked, true);
  assert.equal(tooOld.expiresAt, now - appleRenewalHoldMs);

  for (const status of [2, 3, 5]) {
    const ended = applyAppleRenewal({
      expiresAt: future,
      revoked: false,
      status,
      renewal: appleRenewalInfo({ autoRenewStatus: 1 }),
      now,
    });
    assert.equal(ended.revoked, true, `status ${status}`);
  }

  const graceAt = now + 50_000;
  const grace = applyAppleRenewal({
    expiresAt: stale,
    revoked: false,
    status: 4,
    renewal: appleRenewalInfo({ autoRenewStatus: 1, gracePeriodExpiresDate: graceAt }),
    now,
  });
  assert.equal(grace.revoked, false);
  assert.equal(grace.willNotRenew, false);
  assert.equal(grace.expiresAt, graceAt);

  const graceOver = applyAppleRenewal({
    expiresAt: stale,
    revoked: false,
    status: 4,
    renewal: appleRenewalInfo({ autoRenewStatus: 1, gracePeriodExpiresDate: now - 1 }),
    now,
  });
  assert.equal(graceOver.revoked, true);

  const noticeGrace = applyAppleRenewal({
    expiresAt: stale,
    revoked: false,
    status: null,
    renewal: appleRenewalInfo({ autoRenewStatus: 1, gracePeriodExpiresDate: graceAt }),
    now,
  });
  assert.equal(noticeGrace.expiresAt, graceAt);
  assert.equal(noticeGrace.revoked, false);

  const refunded = applyAppleRenewal({
    expiresAt: future,
    revoked: true,
    status: null,
    renewal: appleRenewalInfo({ autoRenewStatus: 1, gracePeriodExpiresDate: graceAt }),
    now,
  });
  assert.equal(refunded.revoked, true);
  assert.equal(refunded.expiresAt, future);
});

test('subscription status keeps the renewal payload and the numeric status', () => {
  assert.deepEqual(
    appleStatusEntries({
      data: [
        {
          lastTransactions: [
            { status: 1, signedTransactionInfo: 'tx', signedRenewalInfo: 'rn' },
            { status: 2 },
          ],
        },
      ],
    }),
    [{ status: 1, signedTransactionInfo: 'tx', signedRenewalInfo: 'rn' }],
  );
  assert.deepEqual(appleRenewalInfo({ autoRenewStatus: 2 }), {
    autoRenewStatus: null,
    gracePeriodExpiresAt: null,
  });
});

function purchaseFrom(tx: {
  productId: string;
  originalTransactionId: string;
  expiresAt: number | null;
  revoked: boolean;
  appAccountToken: string | null;
  environment: string | null;
}): VerifiedPurchase {
  return {
    store: 'app_store',
    productId: tx.productId,
    token: tx.originalTransactionId,
    expiresAt: tx.expiresAt,
    revoked: tx.revoked,
    accountToken: tx.appAccountToken,
    environment: tx.environment,
    subscription: true,
  };
}

test('an App Store notice applies renewal status', () => {
  const expiresAt = now + 86_400_000;
  const transactionJws = jws(
    { ...transaction(), expiresDate: expiresAt },
    [leafPem, intermediatePem, rootPem],
    leafKey,
  );
  const off = jws(
    { autoRenewStatus: 0, originalTransactionId: '1000', productId: 'field_guide_yearly' },
    [leafPem, intermediatePem, rootPem],
    leafKey,
  );
  const signed = jws(
    {
      notificationType: 'DID_CHANGE_RENEWAL_STATUS',
      data: {
        bundleId: 'sk.ab.shrooms',
        signedTransactionInfo: transactionJws,
        signedRenewalInfo: off,
      },
    },
    [leafPem, intermediatePem, rootPem],
    leafKey,
  );
  const notice = appleNotice({ signedPayload: signed }, now, purchaseFrom, rootPem);
  assert.equal(notice.kind, 'transaction');
  if (notice.kind !== 'transaction') return;
  assert.equal(notice.purchase.willNotRenew, true);
  assert.equal(notice.purchase.revoked, false);
  assert.equal(notice.purchase.expiresAt, expiresAt);

  const graceAt = now + 50_000;
  const graceRenewal = jws(
    { autoRenewStatus: 1, gracePeriodExpiresDate: graceAt, originalTransactionId: '1000' },
    [leafPem, intermediatePem, rootPem],
    leafKey,
  );
  const graceSigned = jws(
    {
      notificationType: 'DID_FAIL_TO_RENEW',
      data: {
        bundleId: 'sk.ab.shrooms',
        signedTransactionInfo: jws(
          { ...transaction(), expiresDate: now - 1_000 },
          [leafPem, intermediatePem, rootPem],
          leafKey,
        ),
        signedRenewalInfo: graceRenewal,
      },
    },
    [leafPem, intermediatePem, rootPem],
    leafKey,
  );
  const grace = appleNotice({ signedPayload: graceSigned }, now, purchaseFrom, rootPem);
  assert.equal(grace.kind, 'transaction');
  if (grace.kind !== 'transaction') return;
  assert.equal(grace.purchase.willNotRenew, false);
  assert.equal(grace.purchase.revoked, false);
  assert.equal(grace.purchase.expiresAt, graceAt);

  const badRenewal = jws(
    {
      notificationType: 'DID_CHANGE_RENEWAL_STATUS',
      data: {
        bundleId: 'sk.ab.shrooms',
        signedTransactionInfo: transactionJws,
        signedRenewalInfo: 'not-a-jws',
      },
    },
    [leafPem, intermediatePem, rootPem],
    leafKey,
  );
  assert.equal(appleNotice({ signedPayload: badRenewal }, now, purchaseFrom, rootPem).kind, 'bad');
});
