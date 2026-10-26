import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, type Firestore } from 'firebase-admin/firestore';
import type { EntitlementDb } from './store_handlers';

const userEntitlements = /^users\/([^/]+)\/entitlements$/;
const userProduct = /^users\/([^/]+)\/entitlements\/products\/([^/]+)$/;
const userUpdated = /^users\/([^/]+)\/entitlements\/updatedAt$/;
const proofDoc = /^purchase_proofs\/([^/]+)$/;
const accountDoc = /^store_accounts\/([^/]+)$/;

type EntitlementsNode = { products?: Record<string, unknown>; updatedAt?: number };

function userRef(db: Firestore, uid: string) {
  return db.collection('users').doc(uid);
}

function entitlementsOf(value: unknown): EntitlementsNode {
  if (!value || typeof value !== 'object') return {};
  const node = value as EntitlementsNode;
  return {
    ...node,
    products: { ...(node.products ?? {}) },
  };
}

async function writeEntitlement(
  db: Firestore,
  uid: string,
  change: (current: EntitlementsNode) => EntitlementsNode,
): Promise<void> {
  const ref = userRef(db, uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const next = change(entitlementsOf(snap.data()?.entitlements));
    tx.set(ref, { entitlements: next }, { merge: true });
  });
}

/// Firestore backing for the same paths the plants app stores in Realtime
/// Database. `users/{uid}.entitlements` is what the phone reads. Proofs and
/// store account tokens stay server-only.
export function firestoreEntitlements(): EntitlementDb {
  const db = getFirestore();
  return {
    async get(path) {
      if (path === 'purchase_proofs') {
        const snap = await db.collection('purchase_proofs').get();
        const all: Record<string, unknown> = {};
        snap.forEach((doc) => {
          all[doc.id] = doc.data();
        });
        return all;
      }
      const proof = path.match(proofDoc);
      if (proof) {
        const snap = await db.collection('purchase_proofs').doc(proof[1]).get();
        return snap.exists ? (snap.data() ?? null) : null;
      }
      const account = path.match(accountDoc);
      if (account) {
        const snap = await db.collection('store_accounts').doc(account[1]).get();
        const uid = snap.data()?.uid;
        return typeof uid === 'string' ? uid : null;
      }
      const entitlements = path.match(userEntitlements);
      if (entitlements) {
        const snap = await userRef(db, entitlements[1]).get();
        return snap.data()?.entitlements ?? null;
      }
      return null;
    },

    async set(path, value) {
      const proof = path.match(proofDoc);
      if (proof) {
        if (value && typeof value === 'object') {
          await db.collection('purchase_proofs').doc(proof[1]).set(value as Record<string, unknown>);
        }
        return;
      }
      const account = path.match(accountDoc);
      if (account) {
        if (typeof value === 'string') {
          await db.collection('store_accounts').doc(account[1]).set({ uid: value });
        }
        return;
      }
      const product = path.match(userProduct);
      if (product && value && typeof value === 'object') {
        const productId = product[2];
        await writeEntitlement(db, product[1], (current) => {
          current.products = { ...(current.products ?? {}), [productId]: value };
          return current;
        });
        return;
      }
      const updated = path.match(userUpdated);
      if (updated && typeof value === 'number') {
        await writeEntitlement(db, updated[1], (current) => {
          current.updatedAt = value;
          return current;
        });
      }
    },

    async remove(path) {
      const proof = path.match(proofDoc);
      if (proof) {
        await db.collection('purchase_proofs').doc(proof[1]).delete();
        return;
      }
      const account = path.match(accountDoc);
      if (account) {
        await db.collection('store_accounts').doc(account[1]).delete();
        return;
      }
      const product = path.match(userProduct);
      if (product) {
        const productId = product[2];
        await writeEntitlement(db, product[1], (current) => {
          const products = { ...(current.products ?? {}) };
          delete products[productId];
          current.products = products;
          return current;
        });
        return;
      }
      const entitlements = path.match(userEntitlements);
      if (!entitlements) return;
      const ref = userRef(db, entitlements[1]);
      const snap = await ref.get();
      if (!snap.exists) return;
      await ref.update({ entitlements: FieldValue.delete() });
    },

    async transaction(path, update) {
      const proof = path.match(proofDoc);
      if (!proof) return false;
      const ref = db.collection('purchase_proofs').doc(proof[1]);
      return db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const current = snap.exists ? (snap.data() ?? null) : null;
        const next = update(current);
        if (next === undefined) return false;
        if (next == null) tx.delete(ref);
        else tx.set(ref, next as Record<string, unknown>);
        return true;
      });
    },

    async authExists(uid) {
      try {
        await getAuth().getUser(uid);
        return true;
      } catch (error) {
        if ((error as { code?: string }).code === 'auth/user-not-found') return false;
        throw error;
      }
    },
  };
}
