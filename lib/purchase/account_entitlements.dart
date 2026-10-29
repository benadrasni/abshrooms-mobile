import 'package:whats_that_mushroom/purchase/purchases.dart';

class AccountEntitlements {
  final bool present;
  final Map<String, bool> products;

  const AccountEntitlements({required this.present, required this.products});
}

/// Disk persistence can emit an empty entitlements row before the server row.
/// An empty cache must not wipe a plan. A later empty row, after a real one,
/// removes the plan.
class EntitlementWatch {
  bool _sawRow = false;

  bool shouldApply(AccountEntitlements snapshot) {
    if (!snapshot.present && !_sawRow) return false;
    if (snapshot.present) _sawRow = true;
    return true;
  }
}

/// The soonest Field Guide expiry still ahead of [now]. The timer fires then
/// so the plan can leave. A later expiry is re-armed within
/// [entitlementExpiryWait].
const entitlementExpiryWait = Duration(hours: 12);

/// How long the phone waits after a stored Field Guide expiry before asking
/// the server to read that purchase token again. The plan has already ended.
/// A verified renewal writes a later expiresAt and the plan returns.
const entitlementRecheckDelay = Duration(minutes: 2);

DateTime? nextFieldGuideExpiry(Object? userValue, DateTime now) {
  if (userValue is! Map) return null;
  final node = userValue['entitlements'];
  if (node is! Map) return null;
  final raw = node['products'];
  if (raw is! Map) return null;
  final nowMs = now.millisecondsSinceEpoch;
  var found = false;
  var soonest = 0;
  raw.forEach((key, value) {
    if (key is! String || !FieldGuideIds.isFieldGuide(key) || value is! Map) {
      return;
    }
    if (value['active'] != true) return;
    final expiresAt = value['expiresAt'];
    if (expiresAt is! num) return;
    final at = expiresAt.toInt();
    if (at <= nowMs) return;
    if (!found || at < soonest) {
      found = true;
      soonest = at;
    }
  });
  if (!found) return null;
  return DateTime.fromMillisecondsSinceEpoch(soonest);
}

/// The latest Field Guide expiry that is already due, while the server still
/// says the plan is active. Null when nothing needs a receipt check.
int? fieldGuideExpiryDueAt(Object? userValue, DateTime now) {
  if (userValue is! Map) return null;
  final node = userValue['entitlements'];
  if (node is! Map) return null;
  final raw = node['products'];
  if (raw is! Map) return null;
  final nowMs = now.millisecondsSinceEpoch;
  int? due;
  raw.forEach((key, value) {
    if (key is! String || !FieldGuideIds.isFieldGuide(key) || value is! Map) {
      return;
    }
    if (value['active'] != true) return;
    final expiresAt = value['expiresAt'];
    if (expiresAt is! num) return;
    final at = expiresAt.toInt();
    if (at > nowMs) return;
    if (due == null || at > due!) due = at;
  });
  return due;
}

/// A Field Guide plan ends at expiresAt. A verified renewal writes a later
/// time. An unverified re-check does not keep a lapsed plan. A missing
/// expiry stays on the active flag. willNotRenew does not extend it.
bool entitlementRowActive(String id, Map value, int nowMs) {
  if (value['active'] != true) return false;
  if (!FieldGuideIds.isFieldGuide(id)) return true;
  final expiresAt = value['expiresAt'];
  if (expiresAt is! num) return true;
  return expiresAt.toInt() > nowMs;
}

/// How the phone should treat one `refreshEntitlements` body.
enum StoredRefresh { settled, retry, throttled }

/// `throttled` is checked first so it is never read as an unverified retry.
StoredRefresh storedRefreshOf(Object? data) {
  if (data is Map && data['throttled'] == true) return StoredRefresh.throttled;
  if (data is Map && data['retry'] == true) return StoredRefresh.retry;
  return StoredRefresh.settled;
}

class RefreshMarks {
  final int? rechecked;
  final int? settled;

  const RefreshMarks({this.rechecked, this.settled});
}

/// A throttled read leaves [RefreshMarks.settled] alone. An unverified
/// retry clears a settle for [dueAt]. A settled read records [dueAt].
RefreshMarks refreshMarksAfter(
  RefreshMarks marks,
  int dueAt,
  StoredRefresh read,
) {
  if (read == StoredRefresh.settled) {
    return RefreshMarks(rechecked: marks.rechecked, settled: dueAt);
  }
  if (read == StoredRefresh.throttled) {
    return RefreshMarks(rechecked: marks.rechecked, settled: marks.settled);
  }
  return RefreshMarks(
    rechecked: marks.rechecked == dueAt ? null : marks.rechecked,
    settled: marks.settled == dueAt ? null : marks.settled,
  );
}

/// A lost `submitPurchase` response is not a refusal. The optimistic grant
/// is already off. The account row puts it back when that row shows the
/// plan. Until then [pendingProduct] is read again on resume and the next call.
class LostSubmitRecovery {
  String? pendingProduct;

  /// True when [account] grants [productId] and that grant was applied.
  bool note(String productId, AccountEntitlements account) {
    if (productId.isEmpty) return false;
    if (_grants(account, productId)) {
      applyAccountEntitlements(account);
      pendingProduct = null;
      return true;
    }
    pendingProduct = productId;
    return false;
  }

  /// Resume or a later read. Applies the row only when it grants the pending
  /// plan, so an older read cannot clear a newer one.
  bool reread(AccountEntitlements account) {
    final productId = pendingProduct;
    if (productId == null) return false;
    if (!_grants(account, productId)) return false;
    applyAccountEntitlements(account);
    pendingProduct = null;
    return true;
  }

  bool _grants(AccountEntitlements account, String productId) {
    return account.present && account.products[productId] == true;
  }
}

/// Active and inactive products under `users/{uid}.entitlements`.
/// Absent when the account has never had a checked receipt.
AccountEntitlements accountEntitlementsOf(Object? userValue, {DateTime? now}) {
  if (userValue is! Map || !userValue.containsKey('entitlements')) {
    return const AccountEntitlements(present: false, products: {});
  }
  final node = userValue['entitlements'];
  if (node is! Map) {
    return const AccountEntitlements(present: true, products: {});
  }
  final raw = node['products'];
  if (raw is! Map) {
    return const AccountEntitlements(present: true, products: {});
  }
  final products = <String, bool>{};
  final clock = (now ?? DateTime.now()).millisecondsSinceEpoch;
  raw.forEach((key, value) {
    if (key is! String || key.isEmpty || value is! Map) return;
    if (value['active'] is! bool) return;
    products[key] = entitlementRowActive(key, value, clock);
  });
  return AccountEntitlements(present: true, products: products);
}

/// Unlocks the signed-in account's checked products and drops the ones the
/// server has marked inactive, including on the phone that bought them.
void applyAccountEntitlements(AccountEntitlements snapshot) {
  if (!snapshot.present) {
    Purchases.clearAccountProducts();
    return;
  }
  final active = <String>{};
  for (final entry in snapshot.products.entries) {
    if (entry.value) {
      active.add(entry.key);
    } else {
      Purchases.purchases.remove(entry.key);
    }
  }
  Purchases.replaceAccountProducts(active);
}

/// Merges one receipt check into the account set. A refusal drops that
/// product on this phone.
void applyCheckedProducts(Map<String, bool> products) {
  if (products.isEmpty) return;
  final active = Set<String>.of(Purchases.accountProducts);
  for (final entry in products.entries) {
    if (entry.key.isEmpty) continue;
    if (entry.value) {
      active.add(entry.key);
    } else {
      active.remove(entry.key);
      Purchases.purchases.remove(entry.key);
    }
  }
  Purchases.replaceAccountProducts(active);
}

Map<String, bool> checkedProductsOf(Object? data) {
  if (data is! Map) return const {};
  final raw = data['products'];
  if (raw is! Map) return const {};
  final products = <String, bool>{};
  raw.forEach((key, value) {
    if (key is String && key.isNotEmpty && value is bool) products[key] = value;
  });
  return products;
}
