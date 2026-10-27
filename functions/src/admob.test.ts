import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import {
  adGrantAccount,
  admobCallbackQuery,
  applyVerifiedAdGrant,
  resetAdmobVerifierKeys,
  settleAdmobReward,
  verifyAdmobCallback,
  type AdmobClaim,
  type VerifiedAdGrant,
} from './admob';
import { type QuotaState } from './quota';

const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const pem = publicKey.export({ type: 'spki', format: 'pem' }).toString();

const keysResponse = () => new Response(JSON.stringify({ keys: [{ keyId: 42, pem }] }));

function signed(message: string): string {
  const signature = sign('sha256', Buffer.from(message), privateKey).toString('base64url');
  return `${message}&signature=${signature}&key_id=42`;
}

const message =
  'ad_network=5450213213286189855&ad_unit=1234&reward_amount=1&reward_item=name' +
  '&timestamp=1790000000000&transaction_id=abc123&user_id=uid42';

const march = Date.parse('2026-03-02T12:00:00Z');

function installKeys(): void {
  resetAdmobVerifierKeys();
  globalThis.fetch = (async () => keysResponse()) as typeof fetch;
}

test('accepts a callback signed by a listed key', async () => {
  installKeys();
  const params = await verifyAdmobCallback(signed(message));
  assert.equal(params?.get('user_id'), 'uid42');
  assert.equal(params?.get('transaction_id'), 'abc123');
});

test('rejects a callback whose signed part was changed', async () => {
  installKeys();
  const forged = signed(message).replace('user_id=uid42', 'user_id=other');
  assert.equal(await verifyAdmobCallback(forged), null);
});

test('rejects an unsigned callback and an unknown key', async () => {
  installKeys();
  assert.equal(await verifyAdmobCallback(message), null);
  assert.equal(await verifyAdmobCallback(signed(message).replace('key_id=42', 'key_id=7')), null);
});

test('reads the raw callback query without rebuilding it', () => {
  const query = 'user_id=uid42&transaction_id=abc123&signature=abc&key_id=42';
  assert.equal(admobCallbackQuery(`/admobReward?${query}`), query);
  assert.equal(admobCallbackQuery('/admobReward', `/?${query}`), query);
  assert.equal(admobCallbackQuery(undefined), '');
});

test('a key-fetch failure is a clean rejection', async () => {
  resetAdmobVerifierKeys();
  globalThis.fetch = (async () => {
    throw new Error('network');
  }) as typeof fetch;
  let called = false;
  const outcome = await settleAdmobReward('GET', signed(message), async () => {
    called = true;
    return 'granted';
  });
  assert.equal(outcome.status, 503);
  assert.equal(outcome.body, 'keys');
  assert.equal(called, false);

  resetAdmobVerifierKeys();
  globalThis.fetch = (async () => new Response('no', { status: 500 })) as typeof fetch;
  const down = await settleAdmobReward('GET', signed(message), async () => 'granted');
  assert.equal(down.status, 503);

  resetAdmobVerifierKeys();
  globalThis.fetch = (async () => new Response('not-json', { status: 200 })) as typeof fetch;
  const junk = await settleAdmobReward('GET', signed(message), async () => 'granted');
  assert.equal(junk.status, 503);
});

test('an anonymous account and a mismatched uid are not the callback user', () => {
  assert.equal(adGrantAccount(null, 'uid42'), false);
  assert.equal(adGrantAccount({ uid: 'other', providers: ['google.com'] }, 'uid42'), false);
  assert.equal(adGrantAccount({ uid: 'uid42', providers: [] }, 'uid42'), false);
  assert.equal(adGrantAccount({ uid: 'uid42', providers: ['google.com'] }, 'uid42'), true);
});

test('a verified callback grants that uid once and a replay does not', async () => {
  installKeys();
  const quotas = new Map<string, QuotaState | null>();
  const seen = new Map<string, string>();
  let now = march;
  let claims = 0;

  async function claim(identity: { uid: string; transactionId: string }): Promise<AdmobClaim> {
    claims += 1;
    const allowed = adGrantAccount(
      { uid: identity.uid, providers: ['google.com'] },
      identity.uid,
    );
    if (!allowed) return 'unbound';
    const applied: VerifiedAdGrant = applyVerifiedAdGrant(
      {
        transactionUid: seen.has(identity.transactionId)
          ? seen.get(identity.transactionId)
          : undefined,
        quota: quotas.get(identity.uid) ?? null,
      },
      now,
    );
    if (applied.result === 'replay') return 'replay';
    seen.set(identity.transactionId, identity.uid);
    quotas.set(identity.uid, applied.quota);
    return applied.result;
  }

  const first = await settleAdmobReward('GET', signed(message), claim);
  assert.equal(first.status, 200);
  assert.equal(first.body, 'ok');
  assert.equal(quotas.get('uid42')?.adGrants, 1);
  assert.equal(seen.get('abc123'), 'uid42');
  assert.equal(quotas.has('other'), false);

  const replay = await settleAdmobReward('GET', signed(message), claim);
  assert.equal(replay.status, 200);
  assert.equal(replay.body, 'replay');
  assert.equal(quotas.get('uid42')?.adGrants, 1);

  now = march + 1000;
  const soon = signed(message.replace('transaction_id=abc123', 'transaction_id=soon'));
  const second = await settleAdmobReward('GET', soon, claim);
  assert.equal(second.status, 200);
  assert.equal(second.body, 'ok');
  assert.equal(quotas.get('uid42')?.adGrants, 2);
  assert.equal(seen.get('soon'), 'uid42');

  const fullState = quotas.get('uid42');
  quotas.set('uid42', { ...fullState, adGrants: 5 });
  const fullQuery = signed(message.replace('transaction_id=abc123', 'transaction_id=full'));
  const full = await settleAdmobReward('GET', fullQuery, claim);
  assert.equal(full.status, 200);
  assert.equal(full.body, 'capped');
  assert.equal(quotas.get('uid42')?.adGrants, 5);
  assert.equal(seen.get('full'), 'uid42');

  const fullReplay = await settleAdmobReward('GET', fullQuery, claim);
  assert.equal(fullReplay.status, 200);
  assert.equal(fullReplay.body, 'replay');
  assert.equal(quotas.get('uid42')?.adGrants, 5);
  assert.equal(claims, 5);
});

test('a forged callback and a guest do not grant', async () => {
  installKeys();
  let called = false;
  const forged = signed(message).replace('user_id=uid42', 'user_id=other');
  const rejected = await settleAdmobReward('GET', forged, async () => {
    called = true;
    return 'granted';
  });
  assert.equal(rejected.status, 403);
  assert.equal(called, false);

  const post = await settleAdmobReward('POST', signed(message), async () => {
    called = true;
    return 'granted';
  });
  assert.equal(post.status, 405);
  assert.equal(called, false);

  const guest = await settleAdmobReward('GET', signed(message), async (identity) => {
    called = true;
    return adGrantAccount({ uid: identity.uid, providers: [] }, identity.uid)
      ? 'granted'
      : 'unbound';
  });
  assert.equal(guest.status, 403);
  assert.equal(guest.body, 'user');
  assert.equal(called, true);

  called = false;
  const nameless = signed(
    'ad_network=1&reward_amount=1&timestamp=1790000000000&transaction_id=abc123',
  );
  const missing = await settleAdmobReward('GET', nameless, async () => {
    called = true;
    return 'granted';
  });
  assert.equal(missing.status, 400);
  assert.equal(called, false);
});

test('a repeated transaction does not grant a different account', () => {
  const first = applyVerifiedAdGrant({ quota: null }, march);
  assert.equal(first.result, 'granted');
  const replay = applyVerifiedAdGrant(
    { transactionUid: 'uid42', quota: first.quota },
    march + 1000,
  );
  assert.equal(replay.result, 'replay');
  assert.equal(first.quota.adGrants, 1);
});

test('two signed views a second apart both count, and a new month is not capped', () => {
  const first = applyVerifiedAdGrant({ quota: null }, march);
  assert.equal(first.result, 'granted');
  const second = applyVerifiedAdGrant({ quota: first.quota }, march + 1000);
  assert.equal(second.result, 'granted');
  assert.equal(second.quota.adGrants, 2);

  const end = Date.parse('2026-03-31T23:59:59.000Z');
  const late = applyVerifiedAdGrant({ quota: null }, end);
  assert.equal(late.result, 'granted');
  const start = Date.parse('2026-04-01T00:00:01.000Z');
  const next = applyVerifiedAdGrant({ quota: late.quota }, start);
  assert.equal(next.result, 'granted');
  assert.equal(next.quota.adGrants, 1);
  assert.equal(next.quota.month, '2026-04');
});

test('a temporary refusal is not a 200', async () => {
  installKeys();
  let claimed = false;
  const outcome = await settleAdmobReward('GET', signed(message), async () => {
    claimed = true;
    return 'unavailable';
  });
  assert.equal(claimed, true);
  assert.equal(outcome.status, 503);
  assert.equal(outcome.body, 'retry');
});

test('the client callable no longer grants a name', () => {
  const source = readFileSync(join(__dirname, '..', 'src', 'index.ts'), 'utf8');
  assert.equal(source.includes('grantPhotoName'), false);
  assert.equal(source.includes('takeAdGrant'), false);
  assert.match(source, /export const admobReward = onRequest/);
  assert.match(source, /settleAdmobReward/);
  assert.match(source, /applyVerifiedAdGrant/);
});
