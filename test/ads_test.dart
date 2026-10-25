import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/ads/ad_units.dart';
import 'package:whats_that_mushroom/ads/app_banner_ad.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  tearDown(() {
    Ads.resetForTest();
    Purchases.resetForTest();
  });

  testWidgets('a banner stays empty until ads are ready', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: guideTheme(Brightness.light),
        home: const Scaffold(
          body: Column(children: [AppBannerAd(pinned: true)]),
        ),
      ),
    );
    expect(find.byType(AppBannerAd), findsOneWidget);
    expect(tester.getSize(find.byType(AppBannerAd)).height, 0);
  });

  test('Field Guide hides ads', () {
    expect(Purchases.showsAds(), isTrue);
    Purchases.remember('field_guide_monthly');
    expect(Purchases.showsAds(), isFalse);
  });
}
