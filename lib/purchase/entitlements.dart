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
  static final LostSubmitRecovery _lost = LostSubmitRecovery();
  static Future<Object?> Function(String uid) _readUser = _firestoreUser;
  static Future<void>? _reread;

  static Future<Object?> _firestoreUser(String uid) async {
    if (Firebase.apps.isEmpty) return null;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return snap.data();
  }

  static void start() {
    if (Firebase.apps.isEmpty) return;
    _authSub ??= FirebaseAuth.instance.userChanges().listen(_onUser);
  }

  static Future<void> afterAppCheck() async {
    await rereadLostGrant();
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
    unawaited(rereadLostGrant());
    unawaited(registerStoreAccount());
    unawaited(flushPendingStoreProofs());
  }

  static void _listen(String uid) {
    final watch = EntitlementWatch();
    _rowWatch = watch;
    _docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
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

  /// A Field Guide plan ends at its stored expiry. When that expiry is due,
  /// the server reads the stored token. A verified renewal writes a later
  /// expiry. An unverified read does not keep the lapsed plan.
  static void _apply(EntitlementWatch watch) {
    final parsed = accountEntitlementsOf(_user);
    if (!watch.shouldApply(parsed)) return;
    applyAccountEntitlements(parsed);
    Auth.syncAnalytics();
    _armExpiry(watch);
  }

  /// Re-reads the stored row, including when the phone was asleep.
  static void applyIfLoaded() {
    final watch = _rowWatch;
    if (watch == null || _uid == null) return;
    _apply(watch);
  }

  /// Asks the server to read the stored token once the expiry has been due
  /// for [entitlementRecheckDelay]. A resume retries a check that failed.
  /// A lookup the store does not verify is tried again and does not extend
  /// a lapsed plan.
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
      await rereadLostGrant();
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
      final overdue = now.difference(
        DateTime.fromMillisecondsSinceEpoch(dueAt),
      );
      if (overdue < entitlementRecheckDelay) {
        _expiry = Timer(entitlementRecheckDelay - overdue, () {
          if (_uid == null) return;
          _apply(watch);
        });
        return;
      }
      final settled = _settledExpiry == dueAt;
      if (!settled) unawaited(recheckIfDue());
      _expiry = Timer(
        settled ? entitlementExpiryWait : entitlementRecheckDelay,
        () {
          if (_uid == null) return;
          if (_settledExpiry != dueAt && _recheck == null)
            _recheckedExpiry = null;
          _apply(watch);
        },
      );
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

  /// The callable response never arrived. The account row is applied when
  /// it already shows the plan, and read again until it does.
  static Future<void> recoverLostSubmit(String productId) async {
    if (_lost.note(productId, accountEntitlementsOf(_user))) {
      _touch();
      return;
    }
    await rereadLostGrant();
  }

  /// Resume, the next refresh, and the read after a lost response.
  static Future<void> rereadLostGrant() async {
    final productId = _lost.pendingProduct;
    final uid = _uid;
    if (productId == null || uid == null) return;
    if (_lost.reread(accountEntitlementsOf(_user))) {
      _touch();
      return;
    }
    Object? data;
    try {
      data = await _readUser(uid);
    } catch (error) {
      debugPrint('entitlement reread: $error');
      return;
    }
    if (_lost.pendingProduct != productId || _uid != uid) return;
    final fresh = accountEntitlementsOf(data);
    if (!_lost.reread(fresh)) return;
    if (_uid != uid) return;
    _user = data;
    _touch();
  }

  static void _touch() {
    final watch = _rowWatch;
    if (watch != null) {
      _apply(watch);
      return;
    }
    Auth.syncAnalytics();
  }

  /// Applies the stored row, then reads again if a purchase response was lost.
  static void onResume() {
    applyIfLoaded();
    final run = rereadLostGrant();
    _reread = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_reread, run)) _reread = null;
      }),
    );
    unawaited(recheckIfDue(force: true));
  }

  @visibleForTesting
  static Future<void> get debugReread => _reread ?? Future<void>.value();

  @visibleForTesting
  static void debugReset({
    String? uid,
    Object? user,
    Future<Object?> Function(String uid)? readUser,
  }) {
    _stopDoc();
    _uid = uid;
    _user = user;
    _rowWatch = uid == null ? null : EntitlementWatch();
    _readUser = readUser ?? _firestoreUser;
    _lost.pendingProduct = null;
    _reread = null;
  }

  static void _stopDoc() {
    _expiry?.cancel();
    _expiry = null;
    _recheckedExpiry = null;
    _settledExpiry = null;
    _lost.pendingProduct = null;
    _rowWatch = null;
    _user = null;
    final sub = _docSub;
    _docSub = null;
    if (sub != null) unawaited(sub.cancel());
  }
}
