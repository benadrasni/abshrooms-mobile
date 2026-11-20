import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whats_that_mushroom/ads/ad_units.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';

/// Collects consent before the first ad request.
///
/// The published AdMob message is Google's consent form. Outside the EEA,
/// the UK, and Switzerland this completes without a form.
///
/// Returns true when the request or the form failed. Analytics still runs
/// unless a required choice is already missing. The caller starts the Mobile
/// Ads SDK only when [ConsentInformation.canRequestAds] is true. A stored
/// choice can still allow that after a failed form.
///
/// [requestUpdate] and [showForm] replace the UMP calls in tests.
Future<bool> gatherAdConsent({
  Future<void> Function()? requestUpdate,
  Future<void> Function(void Function(FormError? error))? showForm,
}) async {
  final updated = Completer<void>();
  var failed = false;
  try {
    if (requestUpdate != null) {
      await requestUpdate().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          failed = true;
        },
      );
    } else {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!updated.isCompleted) updated.complete();
        },
        (error) {
          debugPrint('ads consent: ${error.errorCode}: ${error.message}');
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
    }
    if (failed) return true;
    FormError? formError;
    await (showForm ?? ConsentForm.loadAndShowConsentFormIfRequired)((error) {
      formError = error;
    });
    final error = formError;
    if (error != null) {
      debugPrint('ads consent: ${error.errorCode}: ${error.message}');
      return true;
    }
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
  var consentKnown = false;
  var consentRequired = false;
  var canRequestAds = false;
  try {
    final status = await ConsentInformation.instance.getConsentStatus();
    canRequestAds = await ConsentInformation.instance.canRequestAds();
    consentKnown = status != ConsentStatus.unknown;
    consentRequired =
        status == ConsentStatus.required || status == ConsentStatus.obtained;
  } catch (error) {
    debugPrint('analytics consent: $error');
    umpFailed = true;
  }
  await GuideAnalytics.applyConsent(
    umpFailed: umpFailed,
    trackingAuthorized: trackingAuthorized,
    consentKnown: consentKnown,
    consentRequired: consentRequired,
    canRequestAds: canRequestAds,
  );
}

/// True when the published message requires a way to change the choice.
///
/// This stays available when ads are refused, so the choice can be changed.
Future<bool> adPrivacyOptionsRequired() async {
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
  try {
    FormError? formError;
    await ConsentForm.showPrivacyOptionsForm((error) {
      formError = error;
    });
    final error = formError;
    if (error != null) {
      debugPrint('ads privacy: ${error.errorCode}: ${error.message}');
    }
    await applyAnalyticsConsent();
    if (Ads.enabled) return;
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    Ads.markReady();
  } catch (error) {
    debugPrint('ads privacy: $error');
  }
}
