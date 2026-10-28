import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/purchase/names.dart';

/// Tells AdMob which account earned the view. [admobReward] reads `user_id`.
Future<void> tieRewardedAd(RewardedAd ad) async {
  final uid = Auth.appUser?.uid;
  if (uid == null) return;
  await ad.setServerSideOptions(ServerSideVerificationOptions(userId: uid));
}

/// Account whose `photo_quota` document the grant listener reads.
/// Tests set this. Production uses the signed-in account.
@visibleForTesting
String? nameGrantUidForTest;

/// Replaces the Firestore snapshot stream. Tests push `photo_quota` maps.
@visibleForTesting
Stream<Object?> Function(String uid)? photoQuotaSnapshotsForTest;

/// Drops the grant listener and the test hooks.
@visibleForTesting
void resetNameGrantWatchForTest() {
  nameGrantUidForTest = null;
  photoQuotaSnapshotsForTest = null;
  _watch?.close();
  _watch = null;
}

_NameGrantWatch? _watch;

/// AdMob calls `admobReward` after the ad closes. Listen to this account's
/// meter until this month's `adGrants` grows. The baseline is read here.
/// A month rollover reads as zero and is not a grant.
///
/// The limit sheet waits about 30 seconds ([wait]). The same listener stays
/// open after that, while the app is still running, so a callback that lands
/// later still applies once. A repeated snapshot of that count does not
/// grant again. False when nothing new arrives during [wait].
Future<bool> waitForNameGrant({Duration wait = const Duration(seconds: 30)}) {
  final uid = nameGrantUidForTest ?? Auth.appUser?.uid;
  if (uid == null) return Future.value(false);
  final before = _grantsThisMonth();
  var watch = _watch;
  if (watch != null && watch.uid != uid) {
    watch.close();
    if (identical(_watch, watch)) _watch = null;
    watch = null;
  }
  if (watch == null) {
    final snapshots = photoQuotaSnapshotsForTest;
    if (snapshots == null && Firebase.apps.isEmpty) {
      return Future.value(false);
    }
    watch = _NameGrantWatch(uid, (snapshots ?? _photoQuota)(uid));
    _watch = watch;
  }
  if (_grantsThisMonth() > before) return Future.value(true);
  return watch.wait(wait);
}

Stream<Object?> _photoQuota(String uid) {
  return FirebaseFirestore.instance
      .collection('photo_quota')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.data());
}

int _grantsThisMonth() {
  final count = Names.count;
  if (count.month != quotaMonth(DateTime.now())) return 0;
  if (count.adGrants < 0) return 0;
  return count.adGrants;
}

/// One `photo_quota` listener. A higher `adGrants` is copied from the
/// server document. The same count is not applied again.
class _NameGrantWatch {
  _NameGrantWatch(this.uid, Stream<Object?> snapshots) {
    _sub = snapshots.listen(
      _onSnapshot,
      onError: (Object error) {
        debugPrint('photo quota: $error');
      },
    );
  }

  final String uid;
  StreamSubscription<Object?>? _sub;
  Completer<bool>? _pending;
  var _closed = false;

  void _onSnapshot(Object? raw) {
    if (_closed) return;
    final current = nameGrantUidForTest ?? Auth.appUser?.uid;
    if (current != uid) {
      close();
      if (identical(_watch, this)) _watch = null;
      return;
    }
    final next = nameMonthFromQuota(raw, DateTime.now());
    if (!nameGrantArrived(_grantsThisMonth(), next)) return;
    Names.applyServer(
      signedIn: true,
      charged: false,
      anonymousFreeUsed: false,
      namesUsed: next.namesUsed,
      adGrants: next.adGrants,
      fromPhoto: false,
    );
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(true);
  }

  Future<bool> wait(Duration limit) {
    final done = Completer<bool>();
    _pending = done;
    return done.future.timeout(
      limit,
      onTimeout: () {
        if (identical(_pending, done)) _pending = null;
        return false;
      },
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    final sub = _sub;
    _sub = null;
    if (sub != null) unawaited(sub.cancel());
  }
}
