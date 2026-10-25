import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/keys.dart';

/// Ads stay off in tests. [main] turns this on after the SDK starts.
///
/// Banner and rewarded unit ids come from [getBannerAdUnitId] and
/// [getRewardAdUnitId]. The AdMob app ids stay in the platform manifests,
/// same values as [getAdAppId].
class Ads {
  static var enabled = false;
  static final ready = ValueNotifier<int>(0);

  static void markReady() {
    enabled = true;
    ready.value++;
  }

  static void resetForTest() {
    enabled = false;
  }

  static String? bannerUnitId() => _id(getBannerAdUnitId);

  static String? rewardUnitId() => _id(getRewardAdUnitId);

  static String? _id(String Function() read) {
    if (kIsWeb) return null;
    final mobile = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    if (!mobile) return null;
    final id = read();
    return id.isEmpty ? null : id;
  }
}
