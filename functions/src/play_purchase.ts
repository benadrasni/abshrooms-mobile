export const playPackageName = 'sk.ab.shrooms';

const activeSubscriptionStates = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  'SUBSCRIPTION_STATE_CANCELED',
]);

export type PlayPurchase = {
  productId: string;
  expiresAt: number | null;
  revoked: boolean;
  /** Play CANCELED while expiryTime is still ahead. A later renewal omits it. */
  willNotRenew: boolean;
  obfuscatedAccountId: string | null;
  subscription: boolean;
};

function playLicenseTest(record: Record<string, unknown>): boolean {
  if (record.purchaseType === 0) return true;
  const test = record.testPurchase;
  return test != null && typeof test === 'object';
}

function obfuscatedAccount(record: Record<string, unknown>): string | null {
  const nested = record.externalAccountIdentifiers;
  if (nested && typeof nested === 'object') {
    const id = (nested as { obfuscatedExternalAccountId?: unknown }).obfuscatedExternalAccountId;
    if (typeof id === 'string' && id.length > 0) return id;
  }
  const direct = record.obfuscatedExternalAccountId;
  return typeof direct === 'string' && direct.length > 0 ? direct : null;
}

/// How long an in-progress renewal keeps its grant after expiryTime.
/// Anchored to that expiry, so a later check does not push it forward.
/// Only SUBSCRIPTION_STATE_ACTIVE and SUBSCRIPTION_STATE_IN_GRACE_PERIOD
/// use it. A canceled or expired plan is not held.
export const playRenewalHoldMs = 15 * 60 * 1000;

/// Subscriptions v2. A canceled plan stays active until expiryTime and is
/// marked will-not-renew. Once that time has passed, or Play says expired,
/// the grant ends immediately. Active and in-grace plans stay granted for
/// [playRenewalHoldMs] after expiryTime. A held or paused state does not
/// grant. testPurchase means the tester was not charged. It does not end a
/// period Play still says is open. A license test follows the same states.
export function playSubscription(body: unknown, now: number): PlayPurchase | null {
  if (!body || typeof body !== 'object') return null;
  const record = body as Record<string, unknown>;
  const state = record.subscriptionState;
  if (typeof state !== 'string' || !Array.isArray(record.lineItems)) return null;
  let best: { productId: string; expiresAt: number } | null = null;
  for (const item of record.lineItems) {
    if (!item || typeof item !== 'object') continue;
    const row = item as Record<string, unknown>;
    if (typeof row.productId !== 'string' || typeof row.expiryTime !== 'string') continue;
    if (!/^[A-Za-z0-9_]{1,64}$/.test(row.productId)) continue;
    const expiresAt = Date.parse(row.expiryTime);
    if (!Number.isFinite(expiresAt)) continue;
    if (!best || expiresAt > best.expiresAt) best = { productId: row.productId, expiresAt };
  }
  if (!best) return null;
  const renewing =
    state === 'SUBSCRIPTION_STATE_ACTIVE' ||
    state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD';
  const canceled = state === 'SUBSCRIPTION_STATE_CANCELED';
  const lapsed = best.expiresAt <= now;
  const heldUntil = best.expiresAt + playRenewalHoldMs;
  const inHold = renewing && lapsed && heldUntil > now;
  const stateActive = activeSubscriptionStates.has(state);
  return {
    productId: best.productId,
    expiresAt: inHold ? heldUntil : best.expiresAt,
    revoked: inHold ? false : !stateActive || lapsed,
    willNotRenew: canceled && !lapsed,
    obfuscatedAccountId: obfuscatedAccount(record),
    subscription: true,
  };
}

/// One-time product. purchaseState 0 is purchased, 1 is canceled.
/// A license test does not grant. A normal purchase omits purchaseType and testPurchase.
export function playOneTime(body: unknown, productId: string): PlayPurchase | null {
  if (!body || typeof body !== 'object') return null;
  if (!/^[A-Za-z0-9_]{1,64}$/.test(productId)) return null;
  const record = body as Record<string, unknown>;
  const state = record.purchaseState;
  if (state !== 0 && state !== 1) return null;
  return {
    productId,
    expiresAt: null,
    revoked: state === 1 || playLicenseTest(record),
    willNotRenew: false,
    obfuscatedAccountId: obfuscatedAccount(record),
    subscription: false,
  };
}
