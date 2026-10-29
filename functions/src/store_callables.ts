import { logger } from 'firebase-functions';
import { defineSecret, defineString } from 'firebase-functions/params';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { appleTransaction, verifyAppleSignedPayload } from './apple_jws';
import { proofKey, proofRecordOf, subscriptionProducts, type VerifiedPurchase } from './entitlements';
import { firestoreEntitlements } from './firestore_entitlements';
import {
  appleNotice,
  applyVerifiedNotification,
  grantPurchase,
  playNotice,
  refreshAccountProofs,
  registerStoreAccount as registerAccount,
  releaseStorePurchases as releaseAccount,
  subscriptionProofs,
} from './store_handlers';
import {
  fetchAppleSubscription,
  fetchPlayPurchase,
  playBearer,
  playCredentialsOf,
  purchaseIfVerified,
  StoreUnavailable,
  verifiedApple,
  type AppStoreCredentials,
} from './store_fetch';
import { authorizePubSub, googlePubSubKey, PubSubKeysUnavailable } from './pubsub_auth';
import {
  refreshEntitlementsAllowed,
  refreshEntitlementsEnforceAppCheck,
} from './refresh_limit';

const playPublisherJson = defineSecret('PLAY_PUBLISHER_JSON');
const playPubsubEmail = defineString('PLAY_PUBSUB_EMAIL', { default: '' });
const playPubsubAudience = defineString('PLAY_PUBSUB_AUDIENCE', { default: '' });

const appStoreIssuerId = defineSecret('APP_STORE_ISSUER_ID');
const appStoreKeyId = defineSecret('APP_STORE_KEY_ID');
const appStorePrivateKey = defineSecret('APP_STORE_PRIVATE_KEY');

const firebaseKey = /^[^.#$[\]/]{1,128}$/;

function signedInUid(uid: string | undefined, provider: string | undefined): string {
  if (!uid || !firebaseKey.test(uid) || provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'sign-in');
  }
  return uid;
}

/**
 * Checks a StoreKit 2 transaction or a Play purchase token and writes
 * `users/{uid}.entitlements`. The client cannot write that field.
 * App Store notifications: `appleStoreNotification`.
 * Play real-time notifications: `playStoreNotification`.
 * App Check is not enforced. A sideloaded release cannot mint a Play Integrity
 * JWT, and the callable then sends a dummy token. The store proof is the check.
 */
export const submitPurchase = onCall(
  { region: 'us-central1', enforceAppCheck: false, secrets: [playPublisherJson] },
  async (request) => {
    const uid = signedInUid(request.auth?.uid, request.auth?.token.firebase?.sign_in_provider);
    const store = request.data?.store;
    const productId = request.data?.productId;
    const proof = request.data?.proof;
    if (
      (store !== 'app_store' && store !== 'google_play') ||
      typeof productId !== 'string' ||
      typeof proof !== 'string' ||
      proof.length === 0 ||
      proof.length > 32768
    ) {
      throw new HttpsError('invalid-argument', 'proof');
    }
    const now = Date.now();
    let purchase: VerifiedPurchase | null = null;
    if (store === 'app_store') {
      const payload = verifyAppleSignedPayload(proof, now);
      const transaction = payload ? appleTransaction(payload) : null;
      purchase = transaction ? verifiedApple(transaction) : null;
    } else {
      const credentials = playCredentialsOf(playPublisherJson.value());
      if (!credentials) throw new HttpsError('failed-precondition', 'play');
      try {
        const fetched = await fetchPlayPurchase(
          proof,
          productId,
          subscriptionProducts.has(productId),
          credentials,
          now,
          fetch,
        );
        purchase = fetched.status === 'verified' ? fetched.purchase : null;
      } catch (error) {
        if (error instanceof StoreUnavailable) throw new HttpsError('unavailable', 'play');
        throw error;
      }
    }
    if (!purchase) throw new HttpsError('invalid-argument', 'proof');
    const result = await grantPurchase(firestoreEntitlements(), uid, purchase, now);
    if ('error' in result) {
      const code = result.error === 'other-account' ? 'already-exists' : 'invalid-argument';
      throw new HttpsError(code, result.error);
    }
    return { products: result.products };
  },
);

export const registerStoreAccount = onCall(
  { region: 'us-central1', enforceAppCheck: true },
  async (request) => {
    const uid = signedInUid(request.auth?.uid, request.auth?.token.firebase?.sign_in_provider);
    await registerAccount(firestoreEntitlements(), uid);
    return { ok: true };
  },
);

export const releaseStorePurchases = onCall(
  { region: 'us-central1', enforceAppCheck: true },
  async (request) => {
    const uid = signedInUid(request.auth?.uid, request.auth?.token.firebase?.sign_in_provider);
    await releaseAccount(firestoreEntitlements(), uid);
    return { ok: true };
  },
);

export const appleStoreNotification = onRequest(
  { region: 'us-central1', invoker: 'public' },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('method');
      return;
    }
    const notice = appleNotice(req.body, Date.now(), verifiedApple);
    if (notice.kind === 'bad') {
      res.status(400).send('signature');
      return;
    }
    if (notice.kind === 'ignore') {
      res.status(200).send('ignored');
      return;
    }
    try {
      await applyVerifiedNotification(firestoreEntitlements(), notice.purchase, Date.now());
    } catch (error) {
      logger.error('appleStoreNotification', { error: String(error) });
      res.status(503).send('retry');
      return;
    }
    res.status(200).send('ok');
  },
);

export const playStoreNotification = onRequest(
  { region: 'us-central1', invoker: 'public', secrets: [playPublisherJson] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('method');
      return;
    }
    const serviceAccount = playPubsubEmail.value();
    const configuredAudience = playPubsubAudience.value();
    const host = req.get('host') ?? '';
    const path = req.path || '/';
    const audiences = configuredAudience
      ? [configuredAudience]
      : host
        ? [`https://${host}`, `https://${host}${path.startsWith('/') ? path : `/${path}`}`]
        : [];
    try {
      const allowed = await authorizePubSub(req.get('authorization'), {
        nowSec: Math.floor(Date.now() / 1000),
        audiences,
        serviceAccount,
        keyForKid: (kid) => googlePubSubKey(kid),
      });
      if (!allowed) {
        res.status(401).send('pubsub');
        return;
      }
    } catch (error) {
      if (error instanceof PubSubKeysUnavailable) {
        logger.error('playStoreNotification certs', { error: String(error) });
        res.status(503).send('retry');
        return;
      }
      res.status(401).send('pubsub');
      return;
    }
    const notice = playNotice(req.body);
    if (!notice) {
      res.status(200).send('ignored');
      return;
    }
    const credentials = playCredentialsOf(playPublisherJson.value());
    if (!credentials) {
      res.status(503).send('retry');
      return;
    }
    const now = Date.now();
    try {
      const db = firestoreEntitlements();
      if (notice.kind === 'voided') {
        const key = proofKey('play', notice.token);
        const proof = key ? proofRecordOf(await db.get(`purchase_proofs/${key}`)) : null;
        if (!proof) {
          res.status(200).send('ignored');
          return;
        }
        const fetched = await fetchPlayPurchase(
          notice.token,
          proof.productId,
          proof.subscription,
          credentials,
          now,
          fetch,
        );
        const purchase = purchaseIfVerified(fetched);
        if (purchase) await applyVerifiedNotification(db, purchase, now);
      } else {
        const fetched = await fetchPlayPurchase(
          notice.token,
          notice.productId,
          notice.kind === 'subscription',
          credentials,
          now,
          fetch,
        );
        const purchase = purchaseIfVerified(fetched);
        if (purchase) await applyVerifiedNotification(db, purchase, now);
      }
    } catch (error) {
      logger.error('playStoreNotification', { error: String(error) });
      res.status(503).send('retry');
      return;
    }
    res.status(200).send('ok');
  },
);

const refreshSlots = new Map<string, number>();

/**
 * Reads this account's stored subscription tokens and writes the current
 * Play or App Store state. The phone calls this when a stored expiry is due,
 * because a restore often returns nothing for an ended test subscription.
 * App Check is required. A second call for the same user inside the window
 * does not load purchase tokens and is returned as retry. An unverified
 * lookup is also returned as retry and is not written.
 */
export const refreshEntitlements = onCall(
  {
    region: 'us-central1',
    // Cloud Run must accept the callable. Sign-in is checked in the function.
    invoker: 'public',
    enforceAppCheck: refreshEntitlementsEnforceAppCheck,
    secrets: [playPublisherJson, appStoreIssuerId, appStoreKeyId, appStorePrivateKey],
  },
  async (request) => {
    const uid = signedInUid(request.auth?.uid, request.auth?.token.firebase?.sign_in_provider);
    const now = Date.now();
    if (!refreshEntitlementsAllowed(uid, now, refreshSlots)) {
      return { products: {}, retry: true };
    }
    const play = playCredentialsOf(playPublisherJson.value());
    const issuer = appStoreIssuerId.value();
    const keyId = appStoreKeyId.value();
    const privateKey = appStorePrivateKey.value();
    const apple: AppStoreCredentials | null =
      issuer && keyId && privateKey ? { issuerId: issuer, keyId, privateKey } : null;
    let bearer: string | undefined;
    if (play) {
      try {
        bearer = await playBearer(play, fetch, now);
      } catch (error) {
        logger.error('refreshEntitlements: play auth', { error: String(error) });
      }
    }
    return refreshAccountProofs(firestoreEntitlements(), uid, now, async (proof) => {
      try {
        if (proof.store === 'app_store') {
          if (!apple) return { status: 'unavailable' };
          const fetched = await fetchAppleSubscription(proof.token, proof.environment, apple, now, fetch);
          return fetched.status === 'verified'
            ? { status: 'verified', purchase: fetched.purchase }
            : { status: 'unknown' };
        }
        if (!play || !bearer) return { status: 'unavailable' };
        const fetched = await fetchPlayPurchase(proof.token, proof.productId, true, play, now, fetch, bearer);
        return fetched.status === 'verified'
          ? { status: 'verified', purchase: fetched.purchase }
          : { status: 'unknown' };
      } catch (error) {
        if (error instanceof StoreUnavailable) return { status: 'unavailable' };
        throw error;
      }
    });
  },
);

export const refreshStoreEntitlements = onSchedule(
  {
    region: 'us-central1',
    schedule: 'every 24 hours',
    secrets: [playPublisherJson, appStoreIssuerId, appStoreKeyId, appStorePrivateKey],
  },
  async () => {
    const db = firestoreEntitlements();
    const proofs = await subscriptionProofs(db);
    const play = playCredentialsOf(playPublisherJson.value());
    const issuer = appStoreIssuerId.value();
    const keyId = appStoreKeyId.value();
    const privateKey = appStorePrivateKey.value();
    const apple: AppStoreCredentials | null =
      issuer && keyId && privateKey ? { issuerId: issuer, keyId, privateKey } : null;
    let bearer: string | undefined;
    const now = Date.now();
    if (play) {
      try {
        bearer = await playBearer(play, fetch, now);
      } catch (error) {
        logger.error('refreshStoreEntitlements: play auth', { error: String(error) });
      }
    }
    for (const proof of proofs) {
      try {
        let purchase: VerifiedPurchase | null = null;
        if (proof.store === 'app_store') {
          if (!apple) continue;
          const fetched = await fetchAppleSubscription(proof.token, proof.environment, apple, now, fetch);
          purchase = purchaseIfVerified(fetched);
        } else if (play && bearer) {
          const fetched = await fetchPlayPurchase(proof.token, proof.productId, true, play, now, fetch, bearer);
          purchase = purchaseIfVerified(fetched);
        }
        if (purchase) await grantPurchase(db, proof.uid, purchase, now);
      } catch (error) {
        logger.error('refreshStoreEntitlements', { store: proof.store, error: String(error) });
      }
    }
  },
);
