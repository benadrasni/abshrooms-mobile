import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/purchase/account_entitlements.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/purchase/store_proof.dart';

/// Keeps Field Guide on the signed-in account. A purchase on either store
/// shows up here, and sign-out drops it.
class Entitlements {
  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  static Timer? _expiry;
  static Object? _user;
  static String? _uid;

  static void start() {
    if (Firebase.apps.isEmpty) return;
    _authSub ??= FirebaseAuth.instance.userChanges().listen(_onUser);
  }

  static Future<void> afterAppCheck() async {
    await registerStoreAccount();
    await flushPendingStoreProofs();
  }

  static void _onUser(User? user) {
    final signed = user == null || user.isAnonymous ? null : user;
    if (signed?.uid == _uid) return;
    _stopDoc();
    _uid = signed?.uid;
    Purchases.clearAccountProducts();
    if (signed == null) return;
    _watch(signed.uid);
    unawaited(registerStoreAccount());
    unawaited(flushPendingStoreProofs());
  }

  static void _watch(String uid) {
    final watch = EntitlementWatch();
    _docSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen(
      (snapshot) {
        if (_uid != uid) return;
        _user = snapshot.data();
        _apply(watch);
      },
      onError: (Object error) {
        debugPrint('entitlements: $error');
      },
    );
  }

  /// The plants guide rewrites `active` from the store. This guide also
  /// follows [expiresAt] on the open account, so a canceled plan leaves
  /// the page when that time passes and Firestore has not written again.
  static void _apply(EntitlementWatch watch) {
    final parsed = accountEntitlementsOf(_user);
    if (!watch.shouldApply(parsed)) return;
    applyAccountEntitlements(parsed);
    Auth.syncAnalytics();
    _armExpiry(watch);
  }

  static void _armExpiry(EntitlementWatch watch) {
    _expiry?.cancel();
    _expiry = null;
    final when = nextFieldGuideExpiry(_user, DateTime.now());
    if (when == null) return;
    var delay = when.difference(DateTime.now());
    if (delay > entitlementExpiryWait) delay = entitlementExpiryWait;
    if (delay < Duration.zero) delay = Duration.zero;
    _expiry = Timer(delay, () {
      if (_uid == null) return;
      _apply(watch);
    });
  }

  static void _stopDoc() {
    _expiry?.cancel();
    _expiry = null;
    _user = null;
    final sub = _docSub;
    _docSub = null;
    if (sub != null) unawaited(sub.cancel());
  }
}
