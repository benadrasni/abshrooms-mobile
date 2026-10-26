import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
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
  adGrantsPerMonth,
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
  reserveCall,
  storedQuota,
  takeAdGrant,
  takeAnonymousFree,
  takeFreeNotMushroom,
  takeName,
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

    const reserved = await updateQuota<Refusal | undefined>(uid, (current) => {
      const result = reserveCall(current, now, hash, {
        dailyCeiling: subscribed ? dailyCeilingUnlimited : dailyCeilingFree,
        cooldownMs,
        repeatWindowMs,
        lifetimeCeiling: guest ? anonymousLifetimeCalls : undefined,
      });
      if ('refusal' in result) return { state: current ?? {}, value: result.refusal };
      return { state: result.state, value: undefined };
    });
    if (reserved) {
      const state = (await quotaRef(uid).get()).data() as QuotaState | undefined;
      throw refusalError(reserved, state ?? null, now);
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

    let held = false;
    if (!subscribed && !guest) {
      const taken = await updateQuota<boolean>(uid, (current) => {
        const result = takeName(current, now);
        return { state: result.state, value: result.taken };
      });
      if (!taken) {
        const state = (await quotaRef(uid).get()).data() as QuotaState | undefined;
        throw refusalError('no-names', state ?? null, now);
      }
      held = true;
    }

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

/** One more monthly name after a rewarded ad. A guest has no ad names. */
export const grantPhotoName = onCall(
  {
    region: 'us-central1',
    enforceAppCheck: true,
    memory: '256MiB',
    timeoutSeconds: 30,
    maxInstances: 5,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'sign-in');
    const anonymous = request.auth?.token.firebase?.sign_in_provider === 'anonymous';
    if (anonymous) throw new HttpsError('failed-precondition', 'sign-in');
    const now = Date.now();
    const granted = await updateQuota<boolean>(uid, (current) => {
      const taken = takeAdGrant(current, now, adGrantsPerMonth);
      return { state: taken.state, value: taken.granted };
    });
    const meter = meterCounts(
      ((await quotaRef(uid).get()).data() as QuotaState | undefined) ?? null,
      now,
    );
    return { granted, namesUsed: meter.namesUsed, adGrants: meter.adGrants };
  },
);

export {
  appleStoreNotification,
  playStoreNotification,
  refreshStoreEntitlements,
  registerStoreAccount,
  releaseStorePurchases,
  submitPurchase,
} from './store_callables';
