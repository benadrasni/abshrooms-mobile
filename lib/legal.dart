import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const termsOfUseUrl =
    'https://storage.googleapis.com/abshrooms-resources/misc/TermsOfServiceofWhatsthatmushroom.htm';
const privacyPolicyUrl =
    'https://storage.googleapis.com/abshrooms-resources/misc/PrivacyPolicyofWhatsthatmushroom.htm';

/// Opens a terms or privacy page in the browser.
Future<void> openLegal(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('legal: $error');
  }
}
