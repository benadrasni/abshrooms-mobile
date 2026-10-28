import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// App Store product ids. They cannot repeat What's that flower? on this team.
const fieldGuideMonthlyApple = 'shrooms_field_guide_monthly';
const fieldGuideYearlyApple = 'shrooms_field_guide_yearly';

/// Play product ids. A package may reuse the flower ids.
const fieldGuideMonthlyPlay = 'field_guide_monthly';
const fieldGuideYearlyPlay = 'field_guide_yearly';

const fieldGuideMonthlyIds = {fieldGuideMonthlyApple, fieldGuideMonthlyPlay};
const fieldGuideYearlyIds = {fieldGuideYearlyApple, fieldGuideYearlyPlay};

class FieldGuideIds {
  final String monthly;
  final String yearly;

  const FieldGuideIds({required this.monthly, required this.yearly});

  static const apple = FieldGuideIds(
    monthly: fieldGuideMonthlyApple,
    yearly: fieldGuideYearlyApple,
  );
  static const play = FieldGuideIds(
    monthly: fieldGuideMonthlyPlay,
    yearly: fieldGuideYearlyPlay,
  );

  static FieldGuideIds forPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? apple
        : play;
  }

  bool contains(String id) => id == monthly || id == yearly;

  static bool isFieldGuide(String id) {
    return apple.contains(id) || play.contains(id);
  }
}

/// This phone's product id for a plan the account holds on either store.
Set<String> localFieldGuideIds(Set<String> account, TargetPlatform platform) {
  final ids = FieldGuideIds.forPlatform(platform);
  return {
    if (account.any(fieldGuideYearlyIds.contains)) ids.yearly,
    if (account.any(fieldGuideMonthlyIds.contains)) ids.monthly,
  };
}

/// Field Guide on the signed-in account. A receipt on this phone is kept in
/// [Purchases.purchases] so a plan change can replace it. It is not a grant.
class Purchases {
  static final Map<String, PurchaseDetails> purchases = {};

  /// Product ids a checked receipt granted to the signed-in account.
  static final Set<String> accountProducts = <String>{};

  static final ValueNotifier<int> revision = ValueNotifier(0);
  static final ValueNotifier<int> failures = ValueNotifier(0);

  /// Product ids for this phone's store, including a plan bought on the other.
  static Set<String> get owned =>
      localFieldGuideIds(accountProducts, defaultTargetPlatform);

  static bool hasFieldGuide() => accountProducts.any(FieldGuideIds.isFieldGuide);

  /// Field Guide is the grant that hides ads.
  static bool showsAds() => !hasFieldGuide();

  /// A Field Guide receipt from the store on this phone.
  static bool get fieldGuideOnThisStore {
    final ids = FieldGuideIds.forPlatform(defaultTargetPlatform);
    return purchases.containsKey(ids.monthly) || purchases.containsKey(ids.yearly);
  }

  /// The plan arrived from the account. This phone cannot change it.
  static bool get fieldGuideFromAccountOnly =>
      hasFieldGuide() && !fieldGuideOnThisStore;

  static void replaceAccountProducts(Set<String> ids) {
    final next = ids.where(FieldGuideIds.isFieldGuide).toSet();
    if (next.length == accountProducts.length && accountProducts.containsAll(next)) {
      return;
    }
    accountProducts
      ..clear()
      ..addAll(next);
    revision.value++;
  }

  static void clearAccountProducts() {
    replaceAccountProducts(<String>{});
  }

  /// A purchase just made. The page can show it before the server answers.
  static void grantStorePurchase(String id) {
    if (!FieldGuideIds.isFieldGuide(id)) return;
    replaceAccountProducts({...accountProducts, id});
  }

  /// The server did not accept [grantStorePurchase].
  static void revokeStorePurchase(String id) {
    if (!accountProducts.contains(id)) return;
    replaceAccountProducts(Set<String>.of(accountProducts)..remove(id));
  }

  /// The in-memory store receipt changed. The grant did not.
  static void noteStoreReceipt() {
    revision.value++;
  }

  static void noteFailure() {
    failures.value++;
  }

  static void resetForTest() {
    purchases.clear();
    accountProducts.clear();
  }
}

/// The person dismissed the store sheet. That is not a failed purchase.
bool storePurchaseCanceled(PurchaseDetails purchase) {
  if (purchase.status == PurchaseStatus.canceled) return true;
  final code = purchase.error?.code.toLowerCase() ?? '';
  if (code.isEmpty) return false;
  final folded = code.replaceAll('_', '');
  return code == '2' ||
      code == '15' ||
      code == 'paymentcancelled' ||
      code == 'skerrorpaymentcancelled' ||
      code == 'skerroroverlaycancelled' ||
      folded.contains('usercancel');
}
