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

/// The soonest Field Guide expiry still ahead of [now]. Person and Field
/// Guide drop the plan then, without waiting for another account write.
/// A yearly plan is rechecked within [entitlementExpiryWait].
const entitlementExpiryWait = Duration(hours: 12);

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

/// A checked product is on only while the server still counts it.
/// Subscriptions follow [expiresAt], same as `hasUnlimitedNames`: a missing
/// expiry stays on the active flag, and the expiry instant itself is off.
bool entitlementRowActive(String id, Map value, int nowMs) {
  if (value['active'] != true) return false;
  if (!FieldGuideIds.isFieldGuide(id)) return true;
  final expiresAt = value['expiresAt'];
  if (expiresAt is! num) return true;
  return expiresAt > nowMs;
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
