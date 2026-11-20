import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whats_that_mushroom/ads/ad_consent.dart';

void main() {
  test('a consent form error fails the gather', () async {
    final failed = await gatherAdConsent(
      requestUpdate: () async {},
      showForm: (onDismissed) async {
        onDismissed(FormError(errorCode: 2, message: 'unavailable'));
      },
    );
    expect(failed, isTrue);
  });

  test('a dismissed form without an error does not fail the gather', () async {
    final failed = await gatherAdConsent(
      requestUpdate: () async {},
      showForm: (onDismissed) async {
        onDismissed(null);
      },
    );
    expect(failed, isFalse);
  });

  test('an update failure skips the form', () async {
    var shown = false;
    final failed = await gatherAdConsent(
      requestUpdate: () async => throw StateError('offline'),
      showForm: (onDismissed) async {
        shown = true;
        onDismissed(null);
      },
    );
    expect(failed, isTrue);
    expect(shown, isFalse);
  });
}
