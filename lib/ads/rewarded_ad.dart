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

/// AdMob calls `admobReward` after the ad closes. Listen to this account's
/// meter until this month's `adGrants` grows. The baseline is read here.
/// A month rollover reads as zero and is not a grant. False on timeout.
Future<bool> waitForNameGrant() async {
  final uid = Auth.appUser?.uid;
  if (uid == null || Firebase.apps.isEmpty) return false;
  final before = _grantsThisMonth();
  final done = Completer<bool>();
  final sub = FirebaseFirestore.instance
      .collection('photo_quota')
      .doc(uid)
      .snapshots()
      .listen(
        (snap) {
          if (done.isCompleted) return;
          final next = nameMonthFromQuota(snap.data(), DateTime.now());
          if (!nameGrantArrived(before, next)) return;
          Names.applyServer(
            signedIn: true,
            charged: false,
            anonymousFreeUsed: false,
            namesUsed: next.namesUsed,
            adGrants: next.adGrants,
            fromPhoto: false,
          );
          done.complete(true);
        },
        onError: (Object error) {
          debugPrint('photo quota: $error');
        },
      );
  try {
    return await done.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => false,
    );
  } finally {
    await sub.cancel();
  }
}

int _grantsThisMonth() {
  final count = Names.count;
  if (count.month != quotaMonth(DateTime.now())) return 0;
  if (count.adGrants < 0) return 0;
  return count.adGrants;
}
