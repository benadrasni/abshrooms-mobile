import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// App Store product ids. They cannot repeat What's that flower? on this team.
const fieldGuideMonthlyApple = 'shrooms_field_guide_monthly';
const fieldGuideYearlyApple = 'shrooms_field_guide_yearly';

/// Play product ids. A package may reuse the flower ids.
const fieldGuideMonthlyPlay = 'field_guide_monthly';
const fieldGuideYearlyPlay = 'field_guide_yearly';

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

/// Field Guide receipts on this phone. There is no account entitlement yet,
/// so a purchased or restored store receipt is the grant.
class Purchases {
  static final Map<String, PurchaseDetails> purchases = {};
  static final Set<String> owned = {};
  static final ValueNotifier<int> revision = ValueNotifier(0);
  static final ValueNotifier<int> failures = ValueNotifier(0);

  static bool hasFieldGuide() => owned.any(FieldGuideIds.isFieldGuide);

  static void remember(String id) {
    if (!FieldGuideIds.isFieldGuide(id) || !owned.add(id)) return;
    revision.value++;
  }

  static void restoreOwned(Set<String> ids) {
    final next = ids.where(FieldGuideIds.isFieldGuide).toSet();
    if (next.length == owned.length && owned.containsAll(next)) return;
    owned
      ..clear()
      ..addAll(next);
    revision.value++;
  }

  static void noteFailure() {
    failures.value++;
  }

  static void resetForTest() {
    purchases.clear();
    owned.clear();
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
