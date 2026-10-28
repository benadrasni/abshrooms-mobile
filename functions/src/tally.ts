import type { DocumentReference, Firestore } from 'firebase-admin/firestore';

/** Admin-only count of photographed Latin names that are not in the book. */
export const photoNameTallyCollection = 'photo_name_tally';

const illegalKey = /[.#$[\]/]/;
const reservedId = /^__.*__$/;
/** `photo_name_tally` document id. Anything else is left alone. */
export const tallyMonth = /^\d{4}-\d{2}$/;

/**
 * Tally document id, matching the plants photo key: lower case, dots removed.
 * Null when the key is empty, too long, or not a legal Firestore id.
 */
export function photoLookupKey(scientificName: string): string | null {
  const key = scientificName.trim().toLowerCase().replaceAll('.', '');
  if (key.length === 0 || key.length > 200 || illegalKey.test(key)) return null;
  if (key === '.' || key === '..' || reservedId.test(key)) return null;
  return key;
}

export function leadingScientificName(suggestions: readonly unknown[]): string | null {
  const first = suggestions[0];
  if (!first || typeof first !== 'object') return null;
  const details = (first as { plant_details?: unknown }).plant_details;
  if (!details || typeof details !== 'object') return null;
  const name = (details as { scientific_name?: unknown }).scientific_name;
  if (typeof name !== 'string') return null;
  const trimmed = name.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export interface NameTally {
  name: string;
  count: number;
}

/**
 * `search/la/names` document id: lower case, diacritics folded, dots kept.
 * Null when it cannot be a Firestore id.
 */
export function foldedSearchKey(scientificName: string): string | null {
  const key = scientificName
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
  if (key.length === 0 || key.length > 1500 || key.includes('/')) return null;
  if (key === '.' || key === '..' || reservedId.test(key)) return null;
  return key;
}

/** Unique tally ids for these Latin names. Skips a name that is not a legal key. */
export function tallyKeys(names: readonly string[]): string[] {
  const keys: string[] = [];
  const seen = new Set<string>();
  for (const name of names) {
    const key = photoLookupKey(name);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    keys.push(key);
  }
  return keys;
}

/** MycoBank homotypic and heterotypic `name` strings. Authors are ignored. */
export function synonymScientificNames(data: unknown): string[] {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return [];
  const names: string[] = [];
  for (const group of ['homotypic', 'heterotypic']) {
    const list = (data as Record<string, unknown>)[group];
    if (!Array.isArray(list)) continue;
    for (const item of list) {
      if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
      const name = (item as { name?: unknown }).name;
      if (typeof name !== 'string') continue;
      const trimmed = name.trim();
      if (trimmed.length > 0) names.push(trimmed);
    }
  }
  return names;
}

/**
 * Rows to delete for one species. `months` maps a document id to the tally
 * keys present that month. A genus-only key is removed only when that genus
 * is one of [names]. Months that are not `yyyy-mm` stay.
 */
export function tallyRowsToRemove(
  months: ReadonlyMap<string, readonly string[]>,
  names: readonly string[],
): { keys: string[]; removed: string[] } {
  const keys = tallyKeys(names);
  const removed: string[] = [];
  if (keys.length === 0) return { keys, removed };
  for (const month of [...months.keys()].sort()) {
    if (!tallyMonth.test(month)) continue;
    const present = new Set(months.get(month) ?? []);
    for (const key of keys) {
      if (present.has(key)) removed.push(`${month}/${key}`);
    }
  }
  return { keys, removed };
}

/**
 * Deletes this species from every `photo_name_tally/{yyyy-mm}/names/{key}`.
 * [names] is the accepted Latin name and its MycoBank synonyms.
 */
export async function removePhotoNameTally(
  db: Firestore,
  names: readonly string[],
): Promise<{ keys: string[]; removed: string[] }> {
  const keys = tallyKeys(names);
  if (keys.length === 0) return { keys, removed: [] };
  const months = await db.collection(photoNameTallyCollection).listDocuments();
  const present = new Map<string, string[]>();
  const refs = new Map<string, DocumentReference>();
  for (const month of months) {
    if (!tallyMonth.test(month.id)) continue;
    const found: string[] = [];
    for (const key of keys) {
      const ref = month.collection('names').doc(key);
      if (!(await ref.get()).exists) continue;
      found.push(key);
      refs.set(`${month.id}/${key}`, ref);
    }
    if (found.length > 0) present.set(month.id, found);
  }
  const plan = tallyRowsToRemove(present, names);
  for (let start = 0; start < plan.removed.length; start += 400) {
    const batch = db.batch();
    for (const row of plan.removed.slice(start, start + 400)) {
      const ref = refs.get(row);
      if (ref) batch.delete(ref);
    }
    await batch.commit();
  }
  return plan;
}

/** One more photo of [name] this month. Keeps a bare number from an older write. */
export function nextNameTally(current: unknown, name: string): NameTally {
  let count = 0;
  if (typeof current === 'number' && Number.isFinite(current)) {
    count = current;
  } else if (current && typeof current === 'object' && !Array.isArray(current)) {
    const raw = (current as { count?: unknown }).count;
    if (typeof raw === 'number' && Number.isFinite(raw)) count = raw;
  }
  if (count < 0) count = 0;
  return { name, count: Math.floor(count) + 1 };
}
