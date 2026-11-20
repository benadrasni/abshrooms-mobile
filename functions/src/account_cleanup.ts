import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { logger } from 'firebase-functions';
import { onUserDeleted } from 'firebase-functions/v2/identity';
import { firestoreEntitlements } from './firestore_entitlements';
import { releaseStorePurchases } from './store_handlers';

/// Sighting photos. Catalog plates stay on `abshrooms-resources`.
const sightingStorageBucket = 'abshrooms-a9d4c.firebasestorage.app';

/// A Firebase uid that can be one path segment. `.` `#` `$` `[` `]` `/` `\` are refused.
const accountUidOk = /^[^.#$[\]/\\]{1,128}$/;

export function deletedAccountUidOk(uid: string): boolean {
  return accountUidOk.test(uid);
}

export type DeletedSighting = { id: string; photo: string | null };

/// Object paths for one account's Sightings. A stored photo outside that
/// account is left out. The public copy is `sightings/public/{id}.jpg`.
export function deletedSightingObjects(uid: string, rows: DeletedSighting[]): string[] {
  const paths = new Set<string>();
  for (const row of rows) {
    const id = row.id.trim();
    if (!id || id.includes('/') || id.includes('\\') || id.includes('..')) continue;
    paths.add(`sightings/${uid}/${id}.jpg`);
    paths.add(`sightings/public/${id}.jpg`);
    const photo = (row.photo ?? '').trim();
    if (photo.startsWith(`sightings/${uid}/`) && photo.endsWith('.jpg')) paths.add(photo);
  }
  return [...paths].sort();
}

/// Owner folders. The public JPEG is named by sighting id, not by this prefix.
export function deletedAccountPrefixes(uid: string): string[] {
  return [`private/${uid}/`, `sightings/${uid}/`];
}

export type AccountCleanupStore = {
  sightings(uid: string): Promise<DeletedSighting[]>;
  deleteObjects(paths: string[]): Promise<void>;
  deletePrefixes(prefixes: string[]): Promise<void>;
  deleteSightings(ids: string[]): Promise<void>;
  releasePurchases(uid: string): Promise<void>;
  deletePhotoQuota(uid: string): Promise<void>;
  deleteUserTree(uid: string): Promise<void>;
};

/// Removes the cloud rows for an auth user that is already gone.
/// A bad uid does nothing. Another account's rows are not visited.
export async function removeDeletedAccount(
  uid: string,
  store: AccountCleanupStore = firestoreAccountCleanup(),
): Promise<void> {
  if (!deletedAccountUidOk(uid)) return;
  const rows = await store.sightings(uid);
  const ids = [
    ...new Set(
      rows
        .map((row) => row.id.trim())
        .filter((id) => id.length > 0 && !id.includes('/') && !id.includes('\\') && !id.includes('..')),
    ),
  ];
  await store.deleteObjects(deletedSightingObjects(uid, rows));
  await store.deletePrefixes(deletedAccountPrefixes(uid));
  await store.deleteSightings(ids);
  await store.releasePurchases(uid);
  await store.deletePhotoQuota(uid);
  await store.deleteUserTree(uid);
}

function firestoreAccountCleanup(): AccountCleanupStore {
  return {
    async sightings(uid) {
      const snap = await getFirestore().collection('sightings').where('uid', '==', uid).get();
      return snap.docs.map((doc) => {
        const photo = doc.get('photo');
        return { id: doc.id, photo: typeof photo === 'string' ? photo : null };
      });
    },
    async deleteObjects(paths) {
      if (paths.length === 0) return;
      const bucket = getStorage().bucket(sightingStorageBucket);
      await Promise.all(paths.map((path) => bucket.file(path).delete({ ignoreNotFound: true })));
    },
    async deletePrefixes(prefixes) {
      const bucket = getStorage().bucket(sightingStorageBucket);
      for (const prefix of prefixes) {
        await bucket.deleteFiles({ prefix, force: true });
      }
    },
    async deleteSightings(ids) {
      const db = getFirestore();
      for (const id of ids) {
        if (!/^[A-Za-z0-9_-]{1,80}$/.test(id)) continue;
        await db.collection('sightings_public').doc(id).delete();
        await db.collection('sightings').doc(id).delete();
      }
    },
    async releasePurchases(uid) {
      await releaseStorePurchases(firestoreEntitlements(), uid);
    },
    async deletePhotoQuota(uid) {
      await getFirestore().collection('photo_quota').doc(uid).delete();
    },
    async deleteUserTree(uid) {
      const db = getFirestore();
      await db.recursiveDelete(db.collection('users').doc(uid));
    },
  };
}

/// Runs after Firebase Auth deletes the user. A failure is retried.
/// Sightings, the notebook, store proofs, and `users/{uid}` go only then,
/// so a canceled reauthentication leaves them in place.
export const cleanupDeletedAccount = onUserDeleted(
  { region: 'us-central1', timeoutSeconds: 540 },
  async (event) => {
    const uid = event.data.uid;
    try {
      await removeDeletedAccount(uid);
    } catch (error) {
      logger.error('cleanupDeletedAccount', { uid, error: String(error) });
      throw error;
    }
  },
);
