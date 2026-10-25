import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whats_that_mushroom/ads/ad_units.dart';

/// Collects consent before the first ad request.
///
/// The published AdMob message is Google's consent form. Outside the EEA,
/// the UK, and Switzerland this completes without a form. A failure still
/// lets the SDK start. There is no analytics write: this app does not
/// record an ads-consent choice anywhere else.
Future<void> gatherAdConsent() async {
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
    if (failed) return;
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
  } catch (error) {
    debugPrint('ads consent: $error');
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
  } catch (error) {
    debugPrint('ads privacy: $error');
  }
}
