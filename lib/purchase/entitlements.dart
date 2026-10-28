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
  static EntitlementWatch? _rowWatch;
  static Object? _user;
  static String? _uid;
  static int? _recheckedExpiry;
  static int? _settledExpiry;
  static Future<void>? _recheck;

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
    _listen(signed.uid);
    unawaited(registerStoreAccount());
    unawaited(flushPendingStoreProofs());
  }

  static void _listen(String uid) {
    final watch = EntitlementWatch();
    _rowWatch = watch;
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

  /// The server `active` flag keeps the plan. A stored `willNotRenew` ends it
  /// at expiry. When that expiry is due, the server reads the stored token.
  static void _apply(EntitlementWatch watch) {
    final parsed = accountEntitlementsOf(_user);
    if (!watch.shouldApply(parsed)) return;
    applyAccountEntitlements(parsed);
    Auth.syncAnalytics();
    _armExpiry(watch);
  }

  /// Re-reads the stored row. A plan that will not renew leaves as soon as
  /// its expiry has passed, including when the phone was asleep.
  static void applyIfLoaded() {
    final watch = _rowWatch;
    if (watch == null || _uid == null) return;
    _apply(watch);
  }

  /// Asks the server to read the stored token once the expiry has been due
  /// for [entitlementRecheckDelay]. A resume retries a check that failed.
  /// A lookup the store does not verify is tried again. It is not a cancel.
  static Future<void> recheckIfDue({bool force = false}) {
    if (_uid == null) return Future<void>.value();
    final now = DateTime.now();
    final dueAt = fieldGuideExpiryDueAt(_user, now);
    if (dueAt == null) return Future<void>.value();
    final overdue = now.difference(DateTime.fromMillisecondsSinceEpoch(dueAt));
    if (overdue < entitlementRecheckDelay) return Future<void>.value();
    if (!force && _recheckedExpiry == dueAt) return Future<void>.value();
    final current = _recheck;
    if (current != null) return current;
    _recheckedExpiry = dueAt;
    final run = _refreshDue(dueAt);
    _recheck = run;
    return run.whenComplete(() {
      if (identical(_recheck, run)) _recheck = null;
    });
  }

  static Future<void> _refreshDue(int dueAt) async {
    try {
      final settled = await refreshStoredEntitlements();
      if (_recheckedExpiry != dueAt && _settledExpiry != dueAt) return;
      if (settled) {
        _settledExpiry = dueAt;
        return;
      }
      if (_recheckedExpiry == dueAt) _recheckedExpiry = null;
      if (_settledExpiry == dueAt) _settledExpiry = null;
    } catch (error) {
      if (_recheckedExpiry == dueAt) _recheckedExpiry = null;
      if (_settledExpiry == dueAt) _settledExpiry = null;
      debugPrint('entitlement recheck: $error');
    }
  }

  static void _armExpiry(EntitlementWatch watch) {
    _expiry?.cancel();
    _expiry = null;
    final now = DateTime.now();
    final dueAt = fieldGuideExpiryDueAt(_user, now);
    if (dueAt != null) {
      final overdue = now.difference(DateTime.fromMillisecondsSinceEpoch(dueAt));
      if (overdue < entitlementRecheckDelay) {
        _expiry = Timer(entitlementRecheckDelay - overdue, () {
          if (_uid == null) return;
          _apply(watch);
        });
        return;
      }
      final settled = _settledExpiry == dueAt;
      if (!settled) unawaited(recheckIfDue());
      _expiry = Timer(settled ? entitlementExpiryWait : entitlementRecheckDelay, () {
        if (_uid == null) return;
        if (_settledExpiry != dueAt && _recheck == null) _recheckedExpiry = null;
        _apply(watch);
      });
      return;
    }
    final when = nextFieldGuideExpiry(_user, now);
    if (when == null) return;
    var delay = when.difference(now);
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
    _recheckedExpiry = null;
    _settledExpiry = null;
    _rowWatch = null;
    _user = null;
    final sub = _docSub;
    _docSub = null;
    if (sub != null) unawaited(sub.cancel());
  }
}
