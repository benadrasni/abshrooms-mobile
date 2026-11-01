/** Minimum gap between refreshEntitlements store reads for one user. */
export const refreshEntitlementsMinGapMs = 60_000;

/**
 * A sideloaded release cannot mint a Play Integrity token. This callable is
 * what clears an ended test subscription after restore returns nothing, so
 * App Check stays off. Sign-in is checked in the function.
 */
export const refreshEntitlementsEnforceAppCheck = false;

export function refreshedAtOf(node: unknown): number | null {
  if (!node || typeof node !== 'object') return null;
  const value = (node as { refreshedAt?: unknown }).refreshedAt;
  return typeof value === 'number' ? value : null;
}

/**
 * Whether [node] may start a store read at [now]. This does not reserve
 * the slot. A call inside the window is throttled.
 */
export function nextRefreshReservation(
  node: unknown,
  now: number,
  gapMs = refreshEntitlementsMinGapMs,
): { allowed: false } | { allowed: true; refreshedAt: number } {
  const last = refreshedAtOf(node);
  if (last != null && now - last < gapMs) return { allowed: false };
  return { allowed: true, refreshedAt: now };
}

/**
 * The entitlements object to write when the slot is reserved. Products
 * already on the row stay. A window that is still open returns reserved false
 * and does not change the timestamp.
 */
export function stampRefresh(
  node: unknown,
  now: number,
  gapMs = refreshEntitlementsMinGapMs,
): { reserved: false } | { reserved: true; entitlements: Record<string, unknown> } {
  const decision = nextRefreshReservation(node, now, gapMs);
  if (!decision.allowed) return { reserved: false };
  const current = node && typeof node === 'object' ? { ...(node as Record<string, unknown>) } : {};
  const products = current.products;
  if (products && typeof products === 'object') {
    current.products = { ...(products as Record<string, unknown>) };
  }
  current.refreshedAt = decision.refreshedAt;
  return { reserved: true, entitlements: current };
}
