import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/crash_reporting.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';

void main() {
  test(
    'consent stays on outside the form and off when the choice is refused',
    () {
      final abroad = guideAnalyticsConsent(
        umpFailed: false,
        consentKnown: true,
        consentRequired: false,
        canRequestAds: true,
        trackingAuthorized: true,
      );
      expect(abroad.analyticsStorage, isTrue);
      expect(abroad.adPersonalization, isTrue);

      final refused = guideAnalyticsConsent(
        umpFailed: false,
        consentKnown: true,
        consentRequired: true,
        canRequestAds: false,
        trackingAuthorized: true,
      );
      expect(refused.analyticsStorage, isFalse);
      expect(refused.adStorage, isFalse);

      final trackingOff = guideAnalyticsConsent(
        umpFailed: false,
        consentKnown: true,
        consentRequired: false,
        canRequestAds: true,
        trackingAuthorized: false,
      );
      expect(trackingOff.analyticsStorage, isTrue);
      expect(trackingOff.adUserData, isFalse);
      expect(trackingOff.adPersonalization, isFalse);

      final unknown = guideAnalyticsConsent(
        umpFailed: false,
        consentKnown: false,
        consentRequired: false,
        canRequestAds: false,
        trackingAuthorized: true,
      );
      expect(unknown.analyticsStorage, isFalse);

      final failed = guideAnalyticsConsent(
        umpFailed: true,
        consentKnown: false,
        consentRequired: false,
        canRequestAds: false,
        trackingAuthorized: false,
      );
      expect(failed.analyticsStorage, isFalse);
      expect(failed.adStorage, isFalse);
      expect(failed.adUserData, isFalse);
      expect(failed.adPersonalization, isFalse);
    },
  );

  test('list ids keep the last safe segment', () {
    expect(guideAnalyticsListId('deadly-poisonous'), 'deadly-poisonous');
    expect(
      guideAnalyticsListId('lists/mushroom-of-the-year-de'),
      'mushroom-of-the-year-de',
    );
    expect(
      guideAnalyticsListId('lists custom/blume des jahres'),
      'blumedesjahres',
    );
    expect(guideAnalyticsListId('///'), '');
    expect(guideAnalyticsListId('a' * 40), 'a' * 36);
    expect(guideListScreen('deadly-poisonous'), 'List/deadly-poisonous');
    expect(guideListScreen(''), 'List');
    expect(guideListScreen('///'), 'List');
  });

  test('auth methods, screens, and product categories stay short', () {
    expect(guideAnalyticsAuthMethod('google.com'), 'google');
    expect(guideAnalyticsAuthMethod('apple.com'), 'apple');
    expect(guideAnalyticsAuthMethod('password'), 'email');
    expect(guideAnalyticsAuthMethod('phone'), 'phone');
    expect(guideAnalyticsAuthMethod('facebook.com'), 'other');
    expect(guideAnalyticsProductCategory(fieldGuideYearlyPlay), 'subscription');
    expect(
      guideAnalyticsProductCategory(fieldGuideMonthlyPlay),
      'subscription',
    );
    expect(
      guideAnalyticsProductCategory(fieldGuideYearlyApple),
      'subscription',
    );
    expect(
      guideAnalyticsProductCategory(fieldGuideMonthlyApple),
      'subscription',
    );
    expect(guideAnalyticsProductCategory('mystery'), 'other');
    expect(guideAnalyticsTab(0), guideScreenFind);
    expect(guideAnalyticsTab(1), guideScreenBook);
    expect(guideAnalyticsTab(2), guideScreenSeen);
    expect(guideAnalyticsTab(9), guideScreenFind);
    expect(guideTaxonScreen('family'), guideScreenFamily);
    expect(guideTaxonScreen('genus'), guideScreenGenus);
    expect(guideTaxonScreen('favorites'), guideScreenFavorites);
    expect(guideTaxonScreen('order'), 'Taxon');
    expect(guideAnalyticsText('  Boletus edulis  '), 'Boletus edulis');
    expect(guideAnalyticsText('   '), isNull);
    expect(guideAnalyticsText('abcdef', max: 3), 'abc');
  });

  test('a lost connection and a dropped plugin are not crash reports', () {
    expect(isIgnorableGuideError(Exception('Failed host lookup')), isTrue);
    expect(
      isIgnorableGuideError(
        Exception('MissingPluginException(method cancel on channel)'),
      ),
      isTrue,
    );
    expect(isIgnorableGuideError(StateError('missing plate')), isFalse);
    expect(
      isIgnorableFlutterError(
        FlutterErrorDetails(
          exception: StateError('decode'),
          library: 'image resource service',
        ),
      ),
      isTrue,
    );
    expect(
      isIgnorableFlutterError(
        FlutterErrorDetails(exception: StateError('missing plate')),
      ),
      isFalse,
    );
  });

  test('helpers stay quiet when Firebase is not running', () async {
    expect(Firebase.apps, isEmpty);
    await GuideAnalytics.screen(guideScreenFind);
    await GuideAnalytics.searchPhoto(source: 'camera', outcome: 'species');
    await GuideAnalytics.offlinePack(scope: 'everything', result: 'ok');
    await GuideAnalytics.viewItem([fieldGuideYearlyPlay]);
    recordGuideError(StateError('test'), StackTrace.current, reason: 'test');
    expect(Firebase.apps, isEmpty);
  });
}
