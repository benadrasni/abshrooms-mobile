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
        final raw = snapshot.data();
        final parsed = accountEntitlementsOf(raw);
        if (!watch.shouldApply(parsed)) return;
        applyAccountEntitlements(parsed);
        Auth.syncAnalytics();
      },
      onError: (Object error) {
        debugPrint('entitlements: $error');
      },
    );
  }

  static void _stopDoc() {
    final sub = _docSub;
    _docSub = null;
    if (sub != null) unawaited(sub.cancel());
  }
}
