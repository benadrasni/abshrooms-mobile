import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';

const _ownedKey = 'field_guide_products';

const appleWriteReview =
    'https://apps.apple.com/app/id6826707489?action=write-review';
const playListing =
    'https://play.google.com/store/apps/details?id=sk.ab.shrooms';
const playMarket = 'market://details?id=sk.ab.shrooms';

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

String? storeAccountName() {
  if (Firebase.apps.isEmpty) return null;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return null;
  return uid;
}

/// Listens for Play and App Store receipts and finishes them.
class FieldGuideBilling {
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> start() async {
    await _readOwned();
    final store = InAppPurchase.instance;
    _subscription = store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        debugPrint('purchase stream: $error');
        Purchases.noteFailure();
      },
    );
    final available = await store.isAvailable();
    if (!available) return;
    try {
      await store.restorePurchases();
    } catch (error) {
      debugPrint('restore: $error');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  Future<void> _readOwned() async {
    final prefs = await SharedPreferences.getInstance();
    Purchases.restoreOwned(
      (prefs.getStringList(_ownedKey) ?? const <String>[]).toSet(),
    );
  }

  Future<void> _writeOwned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_ownedKey, Purchases.owned.toList());
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    var changed = false;
    for (final purchase in purchases) {
      final id = purchase.productID;
      if (id.isEmpty) continue;
      final granted = purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;
      if (granted && FieldGuideIds.isFieldGuide(id)) {
        Purchases.purchases[id] = purchase;
        final before = Purchases.owned.length;
        Purchases.remember(id);
        changed = changed || Purchases.owned.length != before;
      } else if (purchase.status == PurchaseStatus.error &&
          !storePurchaseCanceled(purchase)) {
        Purchases.noteFailure();
      }
      if (purchase.pendingCompletePurchase) {
        unawaited(_complete(purchase));
      }
    }
    if (changed) unawaited(_writeOwned());
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
  final account = storeAccountName();
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
