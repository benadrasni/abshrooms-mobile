import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whats_that_mushroom/ads/ad_units.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';

/// Collects consent before the first ad request.
///
/// The published AdMob message is Google's consent form. Outside the EEA,
/// the UK, and Switzerland this completes without a form. A failure still
/// lets the SDK start.
///
/// Returns true when the request failed. Analytics then stays off. A shown
/// form returns false and [applyAnalyticsConsent] reads the choice.
Future<bool> gatherAdConsent() async {
  final updated = Completer<void>();
  var failed = false;
  try {
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!updated.isCompleted) updated.complete();
      },
      (_) {
        failed = true;
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        failed = true;
      },
    );
    if (failed) return true;
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    return false;
  } catch (error) {
    debugPrint('ads consent: $error');
    return true;
  }
}

/// Writes the ads-consent choice onto Firebase Analytics.
Future<void> applyAnalyticsConsent({
  bool umpFailed = false,
  bool? trackingAuthorized,
}) async {
  if (umpFailed) {
    await GuideAnalytics.applyConsent(
      umpFailed: true,
      trackingAuthorized: trackingAuthorized,
    );
    return;
  }
  try {
    final status = await ConsentInformation.instance.getConsentStatus();
    final canAds = await ConsentInformation.instance.canRequestAds();
    await GuideAnalytics.applyConsent(
      trackingAuthorized: trackingAuthorized,
      consentKnown: status != ConsentStatus.unknown,
      consentRequired:
          status == ConsentStatus.required || status == ConsentStatus.obtained,
      canRequestAds: canAds,
    );
  } catch (error) {
    debugPrint('analytics consent: $error');
    await GuideAnalytics.applyConsent(
      umpFailed: true,
      trackingAuthorized: trackingAuthorized,
    );
  }
}

/// True when the published message requires a way to change the choice.
Future<bool> adPrivacyOptionsRequired() async {
  if (!Ads.enabled) return false;
  try {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  } catch (error) {
    debugPrint('ads privacy: $error');
    return false;
  }
}

Future<void> showAdPrivacyOptions() async {
  if (!Ads.enabled) return;
  final done = Completer<void>();
  try {
    ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await applyAnalyticsConsent();
  } catch (error) {
    debugPrint('ads privacy: $error');
  }
}
