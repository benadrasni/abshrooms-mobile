import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/purchase/store_account.dart';
import 'package:whats_that_mushroom/purchase/store_proof.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';

const appleWriteReview =
    'https://apps.apple.com/app/id6826707489?action=write-review';
const playListing =
    'https://play.google.com/store/apps/details?id=sk.ab.shrooms';
const playMarket = 'market://details?id=sk.ab.shrooms';

const storeRestoreKey = 'store_restore_done';

/// Restores on the first launch. A thrown store call still marks it done,
/// so a later cold start does not try again. An explicit restore is
/// [restoreFieldGuidePurchases].
Future<void> restoreOnFirstLaunch({
  required Future<void> Function() restorePurchases,
  Future<SharedPreferences> Function()? preferences,
}) async {
  final SharedPreferences prefs;
  try {
    prefs = await (preferences ?? SharedPreferences.getInstance)();
  } catch (error) {
    debugPrint('restore: $error');
    return;
  }
  if (prefs.getBool(storeRestoreKey) ?? false) return;
  try {
    await restorePurchases();
  } catch (error) {
    debugPrint('restore: $error');
  }
  try {
    await prefs.setBool(storeRestoreKey, true);
  } catch (error) {
    debugPrint('restore: $error');
  }
}

/// Store listing used by Rate this app.
String writeReviewUrl(TargetPlatform platform) {
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
      ? appleWriteReview
      : playListing;
}

Future<bool> openWriteReview() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return await _launch(appleWriteReview);
    }
    if (await _launch(playMarket)) return true;
    return await _launch(playListing);
  } catch (error) {
    debugPrint('write review: $error');
    return false;
  }
}

Future<bool> _launch(String path) {
  return launchUrl(Uri.parse(path), mode: LaunchMode.externalApplication);
}

/// Listens for Play and App Store receipts and finishes them.
class FieldGuideBilling {
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> start() async {
    final store = InAppPurchase.instance;
    _subscription = store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        debugPrint('purchase stream: $error');
        Purchases.noteFailure();
        unawaited(GuideAnalytics.purchaseFailed(reason: 'stream'));
      },
    );
    final available = await store.isAvailable();
    if (!available) return;
    await restoreOnFirstLaunch(
      restorePurchases: () => store.restorePurchases(),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      final id = purchase.productID;
      if (id.isEmpty) continue;
      final granted =
          purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;
      if (granted && FieldGuideIds.isFieldGuide(id)) {
        unawaited(_confirm(purchase));
      } else if (purchase.status == PurchaseStatus.error &&
          !storePurchaseCanceled(purchase)) {
        Purchases.noteFailure();
        unawaited(
          GuideAnalytics.purchaseFailed(productId: id, reason: 'store'),
        );
      }
      if (purchase.pendingCompletePurchase) {
        unawaited(_complete(purchase));
      }
    }
  }

  Future<void> _confirm(PurchaseDetails purchase) async {
    final outcome = await submitStorePurchase(purchase);
    final id = purchase.productID;
    final confirmed =
        outcome.result == StoreProofResult.accepted &&
        outcome.products[id] == true;
    if (confirmed) {
      Purchases.purchases[id] = purchase;
      Purchases.noteStoreReceipt();
      if (purchase.status == PurchaseStatus.purchased) {
        unawaited(GuideAnalytics.purchase(id));
      }
      return;
    }
    if (purchase.status != PurchaseStatus.purchased ||
        outcome.result == StoreProofResult.deferred) {
      return;
    }
    Purchases.noteFailure();
    unawaited(GuideAnalytics.purchaseFailed(productId: id, reason: 'rejected'));
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    try {
      await InAppPurchase.instance.completePurchase(purchase);
    } catch (error) {
      debugPrint('purchase finish: $error');
    }
  }
}

Future<bool> restoreFieldGuidePurchases() async {
  final store = InAppPurchase.instance;
  final available = await store.isAvailable();
  if (!available) return false;
  await store.restorePurchases();
  return true;
}

Future<bool> buyFieldGuide({
  required ProductDetails product,
  PurchaseDetails? replaces,
}) {
  final account = storeApplicationUserName();
  final PurchaseParam param;
  if (defaultTargetPlatform == TargetPlatform.android &&
      replaces is GooglePlayPurchaseDetails) {
    param = GooglePlayPurchaseParam(
      productDetails: product,
      applicationUserName: account,
      changeSubscriptionParam: ChangeSubscriptionParam(
        oldPurchaseDetails: replaces,
        replacementMode: ReplacementMode.withTimeProration,
      ),
    );
  } else {
    param = PurchaseParam(
      productDetails: product,
      applicationUserName: account,
    );
  }
  return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
}
