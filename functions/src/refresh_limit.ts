/** Minimum gap between refreshEntitlements store reads for one user. */
export const refreshEntitlementsMinGapMs = 60_000;

/** The callable rejects a missing App Check token. */
export const refreshEntitlementsEnforceAppCheck = true;

/**
 * One refresh per user per [gapMs] on this instance. A call inside the
 * window does not read purchase tokens. The caller returns retry so the
 * phone asks again later.
 */
export function refreshEntitlementsAllowed(
  uid: string,
  now: number,
  slots: Map<string, number>,
  gapMs = refreshEntitlementsMinGapMs,
): boolean {
  const last = slots.get(uid);
  if (last != null && now - last < gapMs) return false;
  slots.set(uid, now);
  if (slots.size > 1000) {
    for (const [key, at] of slots) {
      if (now - at >= gapMs) slots.delete(key);
    }
  }
  return true;
}
