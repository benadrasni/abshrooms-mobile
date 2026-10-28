import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whats_that_mushroom/person/auth.dart';

/// Tells AdMob which account earned the view. [admobReward] reads `user_id`.
Future<void> tieRewardedAd(RewardedAd ad) async {
  final uid = Auth.appUser?.uid;
  if (uid == null) return;
  await ad.setServerSideOptions(ServerSideVerificationOptions(userId: uid));
}
