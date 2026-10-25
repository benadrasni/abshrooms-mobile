import { createHash } from 'node:crypto';

/** Server state in `photo_quota/{uid}`. Days and months are UTC. */
export interface QuotaState {
  day?: string;
  dayCalls?: number;
  month?: string;
  notMushroomFree?: number;
  adGrants?: number;
  /** Mushroom results, and not-a-mushroom answers past the free ones, this UTC month. */
  namesUsed?: number;
  lastCallAt?: number;
  lastHash?: string;
  lastHashAt?: number;
  totalCalls?: number;
  anonymousFreeUsed?: boolean;
}

export interface CallLimits {
  dailyCeiling: number;
  cooldownMs: number;
  repeatWindowMs: number;
  /** Calls an account may ever make. Set for a guest who is not subscribed. */
  lifetimeCeiling?: number;
}

export type Refusal = 'cooldown' | 'daily-ceiling' | 'repeat-photo' | 'sign-in' | 'no-names';

/** Included photo names each UTC month for a signed-in account. */
export const includedNamesPerMonth = 5;

/** Rewarded-ad grants each UTC month. */
export const adGrantsPerMonth = 5;

/** Not-a-mushroom answers that do not spend a monthly name. */
export const freeNotMushroomPerMonth = 3;

/** Guest attempts, including failures. One successful mushroom still uses the free name. */
export const anonymousLifetimeCalls = 3;

export const dailyCeilingFree = 15;
export const dailyCeilingUnlimited = 30;
export const cooldownMs = 5_000;
export const repeatWindowMs = 24 * 60 * 60 * 1000;

export function utcDay(now: number): string {
  return new Date(now).toISOString().slice(0, 10);
}

export function utcMonth(now: number): string {
  return new Date(now).toISOString().slice(0, 7);
}

export function photoHash(image: string): string {
  return createHash('sha256').update(image).digest('base64url');
}

/** Drops empty fields so Firestore accepts the document. */
export function storedQuota(state: QuotaState): QuotaState {
  const out: QuotaState = {};
  for (const [key, value] of Object.entries(state)) {
    if (value !== undefined) (out as Record<string, unknown>)[key] = value;
  }
  return out;
}

/** Clears the day counter on a new UTC day and the month counters on a new month. */
export function rollOver(state: QuotaState | null, now: number): QuotaState {
  const next: QuotaState = { ...(state ?? {}) };
  const day = utcDay(now);
  if (next.day !== day) {
    next.day = day;
    next.dayCalls = 0;
  }
  const month = utcMonth(now);
  if (next.month !== month) {
    next.month = month;
    next.notMushroomFree = 0;
    next.adGrants = 0;
    next.namesUsed = 0;
  }
  return next;
}

/**
 * Reserves one monthly name before Plant.id. Released when the call fails
 * or the photo is one of the month's free not-a-mushroom answers.
 */
export function takeName(
  state: QuotaState | null,
  now: number,
): { state: QuotaState; taken: boolean } {
  const next = rollOver(state, now);
  const cap = includedNamesPerMonth + (next.adGrants ?? 0);
  if ((next.namesUsed ?? 0) >= cap) return { state: next, taken: false };
  next.namesUsed = (next.namesUsed ?? 0) + 1;
  return { state: next, taken: true };
}

export function releaseName(state: QuotaState | null): QuotaState {
  const next: QuotaState = { ...(state ?? {}) };
  const used = next.namesUsed ?? 0;
  if (used > 0) next.namesUsed = used - 1;
  return next;
}

export function meterCounts(
  state: QuotaState | null,
  now: number,
): { namesUsed: number; adGrants: number } {
  const next = rollOver(state, now);
  return { namesUsed: next.namesUsed ?? 0, adGrants: next.adGrants ?? 0 };
}

/**
 * Counts one Plant.id call before it is made. The same photo inside the
 * repeat window is refused so a not-a-mushroom answer cannot be replayed.
 */
export function reserveCall(
  state: QuotaState | null,
  now: number,
  hash: string,
  limits: CallLimits,
): { state: QuotaState } | { refusal: Refusal } {
  const next = rollOver(state, now);
  if (
    limits.lifetimeCeiling !== undefined &&
    (next.totalCalls ?? 0) >= limits.lifetimeCeiling
  ) {
    return { refusal: 'sign-in' };
  }
  if (next.lastCallAt !== undefined && now - next.lastCallAt < limits.cooldownMs) {
    return { refusal: 'cooldown' };
  }
  if (
    next.lastHash === hash &&
    next.lastHashAt !== undefined &&
    now - next.lastHashAt < limits.repeatWindowMs
  ) {
    return { refusal: 'repeat-photo' };
  }
  if ((next.dayCalls ?? 0) >= limits.dailyCeiling) {
    return { refusal: 'daily-ceiling' };
  }
  next.dayCalls = (next.dayCalls ?? 0) + 1;
  next.totalCalls = (next.totalCalls ?? 0) + 1;
  next.lastCallAt = now;
  return { state: next };
}

/**
 * A guest's one free identification. Taken before the call and given back
 * when Plant.id fails or finds no mushroom. Linking the account on sign-in
 * keeps the uid, so the name is not handed out again.
 */
export function takeAnonymousFree(state: QuotaState | null): { state: QuotaState; free: boolean } {
  const next: QuotaState = { ...(state ?? {}) };
  if (next.anonymousFreeUsed === true) return { state: next, free: false };
  next.anonymousFreeUsed = true;
  return { state: next, free: true };
}

export function releaseAnonymousFree(state: QuotaState | null): QuotaState {
  return { ...(state ?? {}), anonymousFreeUsed: false };
}

export function rememberPhoto(state: QuotaState | null, now: number, hash: string): QuotaState {
  return { ...(state ?? {}), lastHash: hash, lastHashAt: now };
}

export function takeFreeNotMushroom(
  state: QuotaState | null,
  now: number,
  perMonth: number,
): { state: QuotaState; free: boolean } {
  const next = rollOver(state, now);
  const used = next.notMushroomFree ?? 0;
  if (used >= perMonth) return { state: next, free: false };
  next.notMushroomFree = used + 1;
  return { state: next, free: true };
}

export function takeAdGrant(
  state: QuotaState | null,
  now: number,
  perMonth: number,
): { state: QuotaState; granted: boolean } {
  const next = rollOver(state, now);
  const used = next.adGrants ?? 0;
  if (used >= perMonth) return { state: next, granted: false };
  next.adGrants = used + 1;
  return { state: next, granted: true };
}
