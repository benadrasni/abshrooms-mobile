import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
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
  registerStoreAccount as registerAccount,
  releaseStorePurchases as releaseAccount,
  subscriptionProofs,
} from './store_handlers';
import {
  fetchAppleSubscription,
  fetchPlayPurchase,
  playBearer,
  playCredentialsOf,
  StoreUnavailable,
  verifiedApple,
  type AppStoreCredentials,
} from './store_fetch';

const playPublisherJson = defineSecret('PLAY_PUBLISHER_JSON');
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
 */
export const submitPurchase = onCall(
  { region: 'us-central1', enforceAppCheck: true, secrets: [playPublisherJson] },
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
        const purchase =
          fetched.status === 'verified' ? fetched.purchase : { ...revokedProof(proof), revoked: true };
        await applyVerifiedNotification(db, purchase, now);
      } else {
        const fetched = await fetchPlayPurchase(
          notice.token,
          notice.productId,
          notice.kind === 'subscription',
          credentials,
          now,
          fetch,
        );
        if (fetched.status === 'verified') await applyVerifiedNotification(db, fetched.purchase, now);
      }
    } catch (error) {
      logger.error('playStoreNotification', { error: String(error) });
      res.status(503).send('retry');
      return;
    }
    res.status(200).send('ok');
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
    const proofs = (await subscriptionProofs(db)).slice(0, 500);
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
          if (fetched.status === 'verified') purchase = fetched.purchase;
          else purchase = { ...revokedProof(proof), revoked: true };
        } else if (play && bearer) {
          const fetched = await fetchPlayPurchase(proof.token, proof.productId, true, play, now, fetch, bearer);
          if (fetched.status === 'verified') purchase = fetched.purchase;
          else purchase = { ...revokedProof(proof), revoked: true };
        }
        if (purchase) await grantPurchase(db, proof.uid, purchase, now);
      } catch (error) {
        logger.error('refreshStoreEntitlements', { store: proof.store, error: String(error) });
      }
    }
  },
);

function revokedProof(proof: {
  store: VerifiedPurchase['store'];
  productId: string;
  token: string;
  expiresAt: number | null;
  accountToken: string | null;
  environment: string | null;
}): VerifiedPurchase {
  return {
    store: proof.store,
    productId: proof.productId,
    token: proof.token,
    expiresAt: proof.expiresAt,
    revoked: true,
    accountToken: proof.accountToken,
    environment: proof.environment,
    subscription: true,
  };
}
