import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/purchase/account_entitlements.dart';

const _pendingProofs = 'pending_store_proofs';

enum StoreProofResult { accepted, rejected, deferred }

class StoreProofOutcome {
  final StoreProofResult result;
  final Map<String, bool> products;

  /// The callable may have written the plan, and this phone never saw the body.
  final bool responseLost;

  /// The store purchase may be finished. The receipt was verified, refused,
  /// or saved for the account that bought it.
  final bool readyToFinish;

  const StoreProofOutcome(
    this.result, [
    this.products = const {},
    this.responseLost = false,
    this.readyToFinish = false,
  ]);
}

/// A receipt waiting to be sent. [uid] is empty when the phone was signed out.
class PendingStoreProof {
  final String uid;
  final String store;
  final String productId;
  final String proof;

  const PendingStoreProof(this.uid, this.store, this.productId, this.proof);

  Map<String, String> toJson() => {
    'uid': uid,
    'store': store,
    'productId': productId,
    'proof': proof,
  };
}

class PendingProofDecode {
  final List<PendingStoreProof> proofs;
  final bool dropped;

  const PendingProofDecode(this.proofs, {this.dropped = false});
}

/// Proofs saved before they carried an account are dropped, not sent.
PendingProofDecode decodePendingProofs(String raw) {
  if (raw.isEmpty) return const PendingProofDecode([]);
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const PendingProofDecode([], dropped: true);
    final proofs = <PendingStoreProof>[];
    var dropped = false;
    for (final item in decoded) {
      if (item is! Map) {
        dropped = true;
        continue;
      }
      final uid = item['uid'];
      final store = item['store'];
      final productId = item['productId'];
      final proof = item['proof'];
      if (uid is! String ||
          store is! String ||
          productId is! String ||
          proof is! String ||
          proof.isEmpty) {
        dropped = true;
        continue;
      }
      proofs.add(PendingStoreProof(uid, store, productId, proof));
    }
    if (proofs.length != decoded.length) dropped = true;
    return PendingProofDecode(proofs, dropped: dropped);
  } catch (_) {
    return const PendingProofDecode([], dropped: true);
  }
}

/// [uid] may send its own receipts and a receipt saved while signed out.
List<PendingStoreProof> pendingProofsForAccount(
  List<PendingStoreProof> pending,
  String uid,
) {
  if (uid.isEmpty) return const [];
  return [
    for (final item in pending)
      if (item.uid.isEmpty || item.uid == uid) item,
  ];
}

/// A response may change this phone only while [uid] is still signed in.
bool storeProofAppliesLocally(String uid, String? current) {
  return uid.isNotEmpty && current == uid;
}

/// The signed-in account the callable will use. [Auth.appUser] can still be
/// null when the auth stream has already delivered this user.
@visibleForTesting
String? Function()? debugStoreUid;

@visibleForTesting
Future<void> Function()? debugRegisterStoreAccount;

@visibleForTesting
void debugResetStoreProofHooks() {
  debugStoreUid = null;
  debugRegisterStoreAccount = null;
}

String? currentStoreUid() {
  final override = debugStoreUid;
  if (override != null) return override();
  try {
    if (Firebase.apps.isEmpty) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    if (!acceptsSignedInUser(
      anonymous: user.isAnonymous,
      emailVerified: user.emailVerified,
      providerIds: [for (final info in user.providerData) info.providerId],
    )) {
      return null;
    }
    return user.uid;
  } catch (error) {
    debugPrint('store account: $error');
    return null;
  }
}

/// Sends the store proof to `submitPurchase`. A signed-out phone keeps the
/// proof and sends it after sign-in. An invalid proof is rejected. A receipt
/// already owned by another account is rejected. A network failure stays
/// deferred and does not unlock the product.
Future<StoreProofOutcome> submitStorePurchase(
  PurchaseDetails purchase, {
  String? accountId,
}) {
  final store = purchase.verificationData.source;
  if (store != 'app_store' && store != 'google_play') {
    return Future<StoreProofOutcome>.value(
      const StoreProofOutcome(StoreProofResult.deferred),
    );
  }
  return submitStoreProof(
    store: store,
    productId: purchase.productID,
    proof: purchase.verificationData.serverVerificationData,
    accountId: accountId,
  );
}

Future<StoreProofOutcome> submitStoreProof({
  required String store,
  required String productId,
  required String proof,
  String? accountId,
}) async {
  if (productId.isEmpty || proof.isEmpty) {
    return const StoreProofOutcome(StoreProofResult.deferred);
  }
  final uid = accountId ?? currentStoreUid();
  if (uid == null || uid.isEmpty) {
    final queued = await _tryRemember('', store, productId, proof);
    return StoreProofOutcome(
      StoreProofResult.deferred,
      const {},
      false,
      queued,
    );
  }
  if (!storeProofAppliesLocally(uid, currentStoreUid())) {
    final queued = await _tryRemember(uid, store, productId, proof);
    return StoreProofOutcome(
      StoreProofResult.deferred,
      const {},
      false,
      queued,
    );
  }
  try {
    final response = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
          'submitPurchase',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call({'store': store, 'productId': productId, 'proof': proof});
    if (!storeProofAppliesLocally(uid, currentStoreUid())) {
      await _dropPending(uid, store, productId);
      return const StoreProofOutcome(
        StoreProofResult.deferred,
        {},
        false,
        true,
      );
    }
    final products = checkedProductsOf(response.data);
    await _dropPending(uid, store, productId);
    // A switch during the queue write must not unlock the new account.
    if (!storeProofAppliesLocally(uid, currentStoreUid())) {
      return const StoreProofOutcome(
        StoreProofResult.deferred,
        {},
        false,
        true,
      );
    }
    applyCheckedProducts(products);
    return StoreProofOutcome(StoreProofResult.accepted, products, false, true);
  } on FirebaseFunctionsException catch (error) {
    if (error.code == 'invalid-argument' || error.code == 'already-exists') {
      try {
        await _dropPending(uid, store, productId);
      } catch (dropError) {
        debugPrint('store proof queue: $dropError');
      }
      debugPrint(
        error.code == 'already-exists'
            ? 'store proof already exists'
            : 'store proof rejected',
      );
      return const StoreProofOutcome(
        StoreProofResult.rejected,
        {},
        false,
        true,
      );
    }
    final queued = await _tryRemember(uid, store, productId, proof);
    debugPrint('store proof: ${error.code}');
    return StoreProofOutcome(StoreProofResult.deferred, const {}, true, queued);
  } catch (error) {
    final queued = await _tryRemember(uid, store, productId, proof);
    debugPrint('store proof: $error');
    return StoreProofOutcome(StoreProofResult.deferred, const {}, true, queued);
  }
}

/// Asks the server to read this account's stored purchase tokens.
/// [StoredRefresh.retry] is an unverified lookup and should be tried again.
/// [StoredRefresh.throttled] is not that, and it is not a settled read.
/// An empty or unverified result does not clear the plan.
Future<StoredRefresh> refreshStoredEntitlements() async {
  final uid = currentStoreUid();
  if (uid == null || uid.isEmpty) return StoredRefresh.retry;
  try {
    final response = await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
          'refreshEntitlements',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call();
    if (!storeProofAppliesLocally(uid, currentStoreUid())) {
      return StoredRefresh.retry;
    }
    final data = response.data;
    final read = storedRefreshOf(data);
    if (read != StoredRefresh.throttled) {
      applyCheckedProducts(checkedProductsOf(data));
    }
    return read;
  } catch (error) {
    debugPrint('entitlement refresh: $error');
    return StoredRefresh.retry;
  }
}

Future<void> registerStoreAccount() async {
  final uid = currentStoreUid();
  if (uid == null || uid.isEmpty) return;
  if (!storeProofAppliesLocally(uid, currentStoreUid())) return;
  try {
    final hook = debugRegisterStoreAccount;
    if (hook != null) {
      await hook();
      return;
    }
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
          'registerStoreAccount',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
        )
        .call();
  } catch (error) {
    debugPrint('store account: $error');
  }
}

Future<void> flushPendingStoreProofs() async {
  final uid = currentStoreUid();
  if (uid == null || uid.isEmpty) return;
  final pending = pendingProofsForAccount(await _readPending(), uid);
  for (final item in pending) {
    if (!storeProofAppliesLocally(uid, currentStoreUid())) return;
    final owner = item.uid.isEmpty ? uid : item.uid;
    if (item.uid.isEmpty) {
      await _rememberPending(owner, item.store, item.productId, item.proof);
      await _dropPending('', item.store, item.productId);
      if (!storeProofAppliesLocally(uid, currentStoreUid())) return;
    }
    await submitStoreProof(
      store: item.store,
      productId: item.productId,
      proof: item.proof,
      accountId: owner,
    );
  }
}

Future<void> releaseStorePurchases() async {
  final uid = currentStoreUid();
  if (uid == null || uid.isEmpty) return;
  if (!storeProofAppliesLocally(uid, currentStoreUid())) return;
  try {
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
          'releaseStorePurchases',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call();
  } catch (error) {
    debugPrint('release purchases: $error');
    rethrow;
  }
}

Future<List<PendingStoreProof>> _readPending() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_pendingProofs) ?? '';
  final decoded = decodePendingProofs(raw);
  if (decoded.dropped) await _writePending(decoded.proofs);
  return decoded.proofs;
}

Future<void> _writePending(List<PendingStoreProof> pending) async {
  final prefs = await SharedPreferences.getInstance();
  if (pending.isEmpty) {
    await prefs.remove(_pendingProofs);
    return;
  }
  await prefs.setString(
    _pendingProofs,
    jsonEncode(pending.map((item) => item.toJson()).toList()),
  );
}

Future<bool> _tryRemember(
  String uid,
  String store,
  String productId,
  String proof,
) async {
  try {
    await _rememberPending(uid, store, productId, proof);
    return true;
  } catch (error) {
    debugPrint('store proof queue: $error');
    return false;
  }
}

Future<void> _rememberPending(
  String uid,
  String store,
  String productId,
  String proof,
) async {
  final pending = await _readPending();
  pending.removeWhere(
    (item) =>
        item.uid == uid && item.store == store && item.productId == productId,
  );
  pending.add(PendingStoreProof(uid, store, productId, proof));
  final kept = pending.length > 8
      ? pending.sublist(pending.length - 8)
      : pending;
  await _writePending(kept);
}

Future<void> _dropPending(String uid, String store, String productId) async {
  final pending = await _readPending();
  final next = pending.where(
    (item) =>
        item.uid != uid || item.store != store || item.productId != productId,
  );
  if (next.length == pending.length) return;
  await _writePending(next.toList());
}
