import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import {
  type AdmobClaim,
  adGrantAccount,
  admobCallbackQuery,
  applyVerifiedAdGrant,
  settleAdmobReward,
} from './admob';
import { hasUnlimitedNames } from './entitlements';
import {
  plantIdBody,
  plantIdFinished,
  plantIdLanguage,
  plantIdSuggestions,
  plantIdUrl,
  suggestionsForMushrooms,
} from './plantid';
import {
  type QuotaState,
  type Refusal,
  anonymousLifetimeCalls,
  cooldownMs,
  dailyCeilingFree,
  dailyCeilingUnlimited,
  freeNotMushroomPerMonth,
  meterCounts,
  photoHash,
  releaseAnonymousFree,
  releaseName,
  rememberPhoto,
  repeatWindowMs,
  reserveIdentify,
  storedQuota,
  takeAnonymousFree,
  takeFreeNotMushroom,
} from './quota';

initializeApp();

const plantIdKey = defineSecret('PLANT_ID_KEY');
const maxImageChars = 8 * 1024 * 1024;

function quotaRef(uid: string) {
  return getFirestore().collection('photo_quota').doc(uid);
}

async function updateQuota<T>(
  uid: string,
  step: (current: QuotaState | null) => { state: QuotaState; value: T },
): Promise<T> {
  return getFirestore().runTransaction(async (tx) => {
    const ref = quotaRef(uid);
    const snap = await tx.get(ref);
    const current = snap.exists ? (snap.data() as QuotaState) : null;
    const next = step(current);
    tx.set(ref, storedQuota(next.state));
    return next.value;
  });
}

async function accountHasFieldGuide(uid: string): Promise<boolean> {
  const snap = await getFirestore().collection('users').doc(uid).get();
  const data = snap.data();
  return hasUnlimitedNames(data ?? null);
}

function refusalError(reason: Refusal, state: QuotaState | null, now: number): HttpsError {
  const meter = meterCounts(state, now);
  return new HttpsError('resource-exhausted', reason, {
    reason,
    namesUsed: meter.namesUsed,
    adGrants: meter.adGrants,
  });
}

export const identifyMushroom = onCall(
  {
    region: 'us-central1',
    secrets: [plantIdKey],
    enforceAppCheck: true,
    memory: '512MiB',
    timeoutSeconds: 60,
    maxInstances: 5,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'sign-in');
    const image = request.data?.image;
    if (typeof image !== 'string' || image.length === 0 || image.length > maxImageChars) {
      throw new HttpsError('invalid-argument', 'image');
    }
    const rawLanguage = request.data?.language;
    const language =
      typeof rawLanguage === 'string' && /^[a-z]{2,3}(-[A-Za-z]{2,4})?$/.test(rawLanguage)
        ? rawLanguage
        : 'en';

    const anonymous = request.auth?.token.firebase?.sign_in_provider === 'anonymous';
    const subscribed = await accountHasFieldGuide(uid);
    const guest = anonymous && !subscribed;
    const hash = photoHash(image);
    const now = Date.now();

    const chargeName = !subscribed && !guest;
    const reserved = await updateQuota<{ refusal: Refusal } | { charged: boolean }>(uid, (current) => {
      const result = reserveIdentify(
        current,
        now,
        hash,
        {
          dailyCeiling: subscribed ? dailyCeilingUnlimited : dailyCeilingFree,
          cooldownMs,
          repeatWindowMs,
          lifetimeCeiling: guest ? anonymousLifetimeCalls : undefined,
        },
        chargeName,
      );
      if ('refusal' in result) return { state: current ?? {}, value: { refusal: result.refusal } };
      return { state: result.state, value: { charged: result.charged } };
    });
    if ('refusal' in reserved) {
      const state = (await quotaRef(uid).get()).data() as QuotaState | undefined;
      throw refusalError(reserved.refusal, state ?? null, now);
    }

    const releaseFree = () =>
      updateQuota(uid, (current) => ({ state: releaseAnonymousFree(current), value: true }));
    if (guest) {
      const free = await updateQuota<boolean>(uid, (current) => {
        const taken = takeAnonymousFree(current);
        return { state: taken.state, value: taken.free };
      });
      if (!free) {
        const state = (await quotaRef(uid).get()).data() as QuotaState | undefined;
        throw refusalError('sign-in', state ?? null, now);
      }
    }

    const held = reserved.charged;

    let body: Record<string, unknown>;
    try {
      const response = await fetch(plantIdUrl(plantIdLanguage(language)), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Api-Key': plantIdKey.value(),
        },
        body: JSON.stringify(plantIdBody(image)),
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok) throw new Error(`Plant.id ${response.status}`);
      body = (await response.json()) as Record<string, unknown>;
      if (!plantIdFinished(body)) throw new Error('Plant.id incomplete');
    } catch (error) {
      logger.error('identifyMushroom failed', { error: String(error) });
      if (held) await updateQuota(uid, (current) => ({ state: releaseName(current), value: true }));
      if (guest) await releaseFree();
      throw new HttpsError('unavailable', 'identify-failed');
    }

    await updateQuota(uid, (current) => ({
      state: rememberPhoto(current, now, hash),
      value: true,
    }));

    const suggestions = suggestionsForMushrooms(plantIdSuggestions(body));
    let charged = held;
    if (suggestions.length === 0 && held) {
      const free = await updateQuota<boolean>(uid, (current) => {
        const taken = takeFreeNotMushroom(current, now, freeNotMushroomPerMonth);
        return { state: taken.state, value: taken.free };
      });
      if (free) {
        await updateQuota(uid, (current) => ({ state: releaseName(current), value: true }));
        charged = false;
      }
    }
    if (guest && suggestions.length === 0) await releaseFree();

    const meter = meterCounts(
      ((await quotaRef(uid).get()).data() as QuotaState | undefined) ?? null,
      now,
    );
    return {
      charged,
      namesUsed: meter.namesUsed,
      adGrants: meter.adGrants,
      anonymousFreeUsed: guest && suggestions.length > 0,
      guest,
      suggestions: suggestions.map((item) => {
        const details = item.plant_details as {
          scientific_name?: unknown;
          common_names?: unknown;
        };
        return {
          scientificName: details.scientific_name,
          probability: item.probability,
          commonNames: Array.isArray(details.common_names) ? details.common_names : [],
        };
      }),
    };
  },
);

/**
 * AdMob rewarded-ad server-side verification.
 *
 * Google GETs this after a view. The callback is signed, `transaction_id`
 * is stored so a replay cannot grant again, and `user_id` has to be that
 * Firebase account. The monthly name is granted only for that callback.
 * A guest has no ad names. The AdMob console callback URL has to point here.
 */
export const admobReward = onRequest(
  {
    region: 'us-central1',
    invoker: 'public',
    memory: '256MiB',
    timeoutSeconds: 30,
    maxInstances: 5,
  },
  async (req, res) => {
    try {
      const outcome = await settleAdmobReward(
        req.method,
        admobCallbackQuery(req.originalUrl, req.url),
        claimAdmobReward,
      );
      if (outcome.status >= 500) {
        logger.error('admobReward', { status: outcome.status, body: outcome.body });
      }
      res.status(outcome.status).send(outcome.body);
    } catch (error) {
      logger.error('admobReward', { error: String(error) });
      res.status(503).send('retry');
    }
  },
);

async function claimAdmobReward(identity: {
  uid: string;
  transactionId: string;
}): Promise<AdmobClaim> {
  const account = await rewardAccount(identity.uid);
  if (account !== 'ok') return account;
  const db = getFirestore();
  const rewardRef = db.collection('admob_rewards').doc(identity.transactionId);
  const meter = quotaRef(identity.uid);
  return db.runTransaction(async (tx) => {
    const reward = await tx.get(rewardRef);
    const snap = await tx.get(meter);
    const current = snap.exists ? (snap.data() as QuotaState) : null;
    const now = Date.now();
    const applied = applyVerifiedAdGrant(
      {
        transactionUid: reward.exists ? String(reward.get('uid') ?? '') : undefined,
        quota: current,
      },
      now,
    );
    if (applied.result === 'replay') return 'replay';
    tx.set(rewardRef, { uid: identity.uid, at: now });
    tx.set(meter, storedQuota(applied.quota));
    return applied.result;
  });
}

async function rewardAccount(uid: string): Promise<'ok' | 'unbound' | 'unavailable'> {
  try {
    const user = await getAuth().getUser(uid);
    const providers = user.providerData.map((entry) => entry.providerId);
    return adGrantAccount({ uid: user.uid, providers }, uid) ? 'ok' : 'unbound';
  } catch (error) {
    const code = errorCode(error);
    if (code === 'auth/user-not-found' || code === 'auth/invalid-uid') return 'unbound';
    logger.error('admobReward account', { error: String(error) });
    return 'unavailable';
  }
}

function errorCode(error: unknown): string {
  if (typeof error !== 'object' || error === null || !('code' in error)) return '';
  const code = (error as { code?: unknown }).code;
  return typeof code === 'string' ? code : '';
}

export {
  appleStoreNotification,
  playStoreNotification,
  refreshStoreEntitlements,
  registerStoreAccount,
  releaseStorePurchases,
  submitPurchase,
} from './store_callables';
