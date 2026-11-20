import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whats_that_mushroom/person/auth.dart';

/// The account a rewarded view can credit, or null when it cannot.
String? rewardedAdAccountId() => Auth.appUser?.uid;

/// Tells AdMob which account earned the view. [admobReward] reads `user_id`.
///
/// Returns false when no account can be credited. The ad is left unchanged.
Future<bool> tieRewardedAd(RewardedAd ad) async {
  final uid = rewardedAdAccountId();
  if (uid == null) return false;
  await ad.setServerSideOptions(ServerSideVerificationOptions(userId: uid));
  return true;
}
