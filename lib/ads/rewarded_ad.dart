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

/// AdMob calls `admobReward` a moment after the ad closes. The meter moves
/// when this month's `adGrants` grows. A month rollover reads as zero and
/// is not a grant. False when the server meter does not show a new grant.
Future<bool> waitForNameGrant(int grantsBefore) async {
  final uid = Auth.appUser?.uid;
  if (uid == null || Firebase.apps.isEmpty) return false;
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    final next = await _loadPhotoQuota(uid);
    if (next == null || !nameGrantArrived(grantsBefore, next)) continue;
    Names.applyServer(
      signedIn: true,
      charged: false,
      anonymousFreeUsed: false,
      namesUsed: next.namesUsed,
      adGrants: next.adGrants,
      fromPhoto: false,
    );
    return true;
  }
  return false;
}

Future<NameMonth?> _loadPhotoQuota(String uid) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('photo_quota')
        .doc(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 4));
    final raw = snap.data();
    return nameMonthFromQuota(raw, DateTime.now());
  } catch (error) {
    debugPrint('photo quota: $error');
    return null;
  }
}
