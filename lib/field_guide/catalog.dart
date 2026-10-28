import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';

enum FieldGuidePlan { yearly, monthly }

class FieldGuideOffer {
  final FieldGuidePlan plan;
  final String productId;
  final String? price;
  final bool owned;

  const FieldGuideOffer({
    required this.plan,
    required this.productId,
    required this.price,
    required this.owned,
  });
}

class FieldGuideCatalog {
  final FieldGuideOffer yearly;
  final FieldGuideOffer monthly;
  final bool storeAvailable;
  final String? error;

  const FieldGuideCatalog({
    required this.yearly,
    required this.monthly,
    required this.storeAvailable,
    this.error,
  });

  /// Yearly stays selected for a monthly subscriber. The owned monthly row
  /// still says Subscribed.
  FieldGuidePlan get initialPlan => FieldGuidePlan.yearly;

  FieldGuideOffer offer(FieldGuidePlan plan) {
    return plan == FieldGuidePlan.yearly ? yearly : monthly;
  }

  FieldGuideCatalog withOwnership(Set<String> owned) {
    return fieldGuideCatalog(
      ids: FieldGuideIds(monthly: monthly.productId, yearly: yearly.productId),
      storeAvailable: storeAvailable,
      yearlyPrice: yearly.price,
      monthlyPrice: monthly.price,
      owned: owned,
      error: error,
    );
  }
}

class FieldGuideLoaded {
  final FieldGuideCatalog catalog;
  final Map<String, ProductDetails> products;

  const FieldGuideLoaded({required this.catalog, this.products = const {}});
}

class FieldGuideChoice {
  final int buyIndex;
  final String displayPrice;

  const FieldGuideChoice({required this.buyIndex, required this.displayPrice});
}

/// A free introductory phase is the one to buy when a paid phase is also
/// present. The price on the row is the paid phase.
FieldGuideChoice? fieldGuideOfferChoice(
  List<({String price, double rawPrice})> offers,
) {
  if (offers.isEmpty) return null;
  var paid = -1;
  var free = -1;
  for (var i = 0; i < offers.length; i++) {
    final raw = offers[i].rawPrice;
    if (raw > 0) {
      if (paid < 0 || raw > offers[paid].rawPrice) paid = i;
    } else if (free < 0 && offers[i].price.trim().isNotEmpty) {
      free = i;
    }
  }
  if (paid < 0 && free < 0) return null;
  if (paid < 0) {
    return FieldGuideChoice(buyIndex: free, displayPrice: offers[free].price);
  }
  return FieldGuideChoice(
    buyIndex: free >= 0 ? free : paid,
    displayPrice: offers[paid].price,
  );
}

class FieldGuideAccess {
  final bool upgrade;
  final bool locked;

  const FieldGuideAccess({required this.upgrade, required this.locked});
}

/// Monthly bought on this phone can move to yearly. A plan that arrived from
/// the account, including one bought on the other store, cannot be changed here.
FieldGuideAccess fieldGuideAccess({
  required FieldGuideCatalog catalog,
  required bool monthlyOnThisStore,
  bool fromAccountOnly = false,
}) {
  final upgrade = monthlyOnThisStore &&
      !fromAccountOnly &&
      catalog.monthly.owned &&
      !catalog.yearly.owned &&
      catalog.yearly.price != null;
  final hasPlan =
      catalog.monthly.owned || catalog.yearly.owned || fromAccountOnly;
  return FieldGuideAccess(upgrade: upgrade, locked: hasPlan && !upgrade);
}

/// The other Field Guide product, when that product is already owned.
String? fieldGuideReplaces(FieldGuidePlan buying, FieldGuideIds ids, Set<String> owned) {
  final other = buying == FieldGuidePlan.yearly ? ids.monthly : ids.yearly;
  return owned.contains(other) ? other : null;
}

FieldGuideCatalog fieldGuideCatalog({
  required FieldGuideIds ids,
  required bool storeAvailable,
  required String? yearlyPrice,
  required String? monthlyPrice,
  required Set<String> owned,
  String? error,
}) {
  return FieldGuideCatalog(
    yearly: FieldGuideOffer(
      plan: FieldGuidePlan.yearly,
      productId: ids.yearly,
      price: _price(yearlyPrice),
      owned: owned.contains(ids.yearly),
    ),
    monthly: FieldGuideOffer(
      plan: FieldGuidePlan.monthly,
      productId: ids.monthly,
      price: _price(monthlyPrice),
      owned: owned.contains(ids.monthly),
    ),
    storeAvailable: storeAvailable,
    error: error,
  );
}

String? _price(String? price) {
  final trimmed = price?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

FieldGuideLoaded fieldGuideFromStore({
  required FieldGuideIds ids,
  required bool storeAvailable,
  required List<ProductDetails> products,
  required Set<String> owned,
  String? error,
}) {
  final yearly = _picked(products, ids.yearly);
  final monthly = _picked(products, ids.monthly);
  return FieldGuideLoaded(
    catalog: fieldGuideCatalog(
      ids: ids,
      storeAvailable: storeAvailable,
      yearlyPrice: yearly?.displayPrice,
      monthlyPrice: monthly?.displayPrice,
      owned: owned,
      error: error,
    ),
    products: {
      if (yearly != null) ids.yearly: yearly.product,
      if (monthly != null) ids.monthly: monthly.product,
    },
  );
}

({ProductDetails product, String displayPrice})? _picked(
  List<ProductDetails> products,
  String id,
) {
  final matches = products.where((product) => product.id == id).toList();
  final choice = fieldGuideOfferChoice([
    for (final product in matches)
      (price: product.price, rawPrice: product.rawPrice),
  ]);
  if (choice == null) return null;
  return (product: matches[choice.buyIndex], displayPrice: choice.displayPrice);
}

/// `Version 1.0.0 (100)`. An empty name or build is left out.
String versionLine({
  required String label,
  required String version,
  required String build,
}) {
  final name = version.trim();
  final number = build.trim();
  if (name.isEmpty && number.isEmpty) return '';
  if (number.isEmpty) return '$label $name';
  if (name.isEmpty) return '$label $number';
  return '$label $name ($number)';
}
