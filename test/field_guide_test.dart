import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/field_guide/catalog.dart';
import 'package:whats_that_mushroom/field_guide/field_guide_page.dart';
import 'package:whats_that_mushroom/purchase/billing.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  const ids = FieldGuideIds.play;

  tearDown(Purchases.resetForTest);

  test('a free trial is bought and the row shows the paid price', () {
    final choice = fieldGuideOfferChoice([
      (price: r'$24.99', rawPrice: 24.99),
      (price: 'Free', rawPrice: 0),
    ]);
    expect(choice?.buyIndex, 1);
    expect(choice?.displayPrice, r'$24.99');
  });

  test(
    'yearly ownership locks the screen, monthly on this phone can change',
    () {
      final yearly = fieldGuideCatalog(
        ids: ids,
        storeAvailable: true,
        yearlyPrice: r'$24.99',
        monthlyPrice: r'$2.99',
        owned: {ids.yearly},
      );
      expect(
        fieldGuideAccess(catalog: yearly, monthlyOnThisStore: false).locked,
        isTrue,
      );

      final monthly = fieldGuideCatalog(
        ids: ids,
        storeAvailable: true,
        yearlyPrice: r'$24.99',
        monthlyPrice: r'$2.99',
        owned: {ids.monthly},
      );
      final access = fieldGuideAccess(
        catalog: monthly,
        monthlyOnThisStore: true,
      );
      expect(access.upgrade, isTrue);
      expect(access.locked, isFalse);
      expect(
        fieldGuideReplaces(FieldGuidePlan.yearly, ids, {ids.monthly}),
        ids.monthly,
      );
    },
  );

  test('the store row keeps the paid price and buys the free phase', () {
    final loaded = fieldGuideFromStore(
      ids: ids,
      storeAvailable: true,
      products: [
        ProductDetails(
          id: ids.yearly,
          title: 'Yearly',
          description: '',
          price: r'$24.99',
          rawPrice: 24.99,
          currencyCode: 'USD',
        ),
        ProductDetails(
          id: ids.yearly,
          title: 'Yearly trial',
          description: '',
          price: 'Free',
          rawPrice: 0,
          currencyCode: 'USD',
        ),
      ],
      owned: const {},
    );
    expect(loaded.catalog.yearly.price, r'$24.99');
    expect(loaded.products[ids.yearly]?.rawPrice, 0);
  });

  test('version line and the store review link', () {
    expect(
      versionLine(label: 'Version', version: '1.0.0', build: '100'),
      'Version 1.0.0 (100)',
    );
    expect(versionLine(label: 'Version', version: '', build: ''), isEmpty);
    expect(writeReviewUrl(TargetPlatform.iOS), appleWriteReview);
    expect(writeReviewUrl(TargetPlatform.android), playListing);
  });

  test('a dismissed store sheet is not a failed purchase', () {
    expect(storePurchaseCanceled(_purchase(PurchaseStatus.canceled)), isTrue);
    expect(
      storePurchaseCanceled(
        _purchase(PurchaseStatus.error, code: 'user_canceled'),
      ),
      isTrue,
    );
    expect(
      storePurchaseCanceled(
        _purchase(PurchaseStatus.error, code: 'itemUnavailable'),
      ),
      isFalse,
    );
  });

  testWidgets('Field Guide offers yearly and monthly and starts the trial', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FieldGuidePlan? bought;
    await tester.pumpWidget(
      _host(
        FieldGuidePage(
          plate: (_) => const SizedBox.shrink(),
          load: () async => FieldGuideLoaded(
            catalog: fieldGuideCatalog(
              ids: ids,
              storeAvailable: true,
              yearlyPrice: r'$24.99',
              monthlyPrice: r'$2.99',
              owned: const {},
            ),
          ),
          buy: (plan) async {
            bought = plan;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Field Guide'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('The three-step key'), findsOneWidget);
    expect(find.text('Every species page'), findsOneWidget);
    expect(find.text('Seen on this phone'), findsOneWidget);
    expect(find.text('5 names a month, plus up to 5 from ads'), findsOneWidget);
    expect(find.text('Unlimited names from photos'), findsOneWidget);
    expect(find.text('No ads'), findsOneWidget);
    expect(find.text('Seen on all your devices, with photos'), findsOneWidget);
    expect(find.text('The book offline'), findsOneWidget);
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(find.text(r'$2.99'), findsOneWidget);
    expect(find.text('7 days free, then yearly'), findsOneWidget);
    expect(find.text('Start 7 days free'), findsOneWidget);

    await tester.tap(find.text('Start 7 days free'));
    await tester.pump();
    expect(bought, FieldGuidePlan.yearly);

    await tester.tap(find.byKey(fieldGuideMonthlyKey));
    await tester.pump();
    await tester.tap(find.text('Start 7 days free'));
    await tester.pump();
    expect(bought, FieldGuidePlan.monthly);
  });

  testWidgets('an owned plan says subscribed', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        FieldGuidePage(
          plate: (_) => const SizedBox.shrink(),
          load: () async => FieldGuideLoaded(
            catalog: fieldGuideCatalog(
              ids: ids,
              storeAvailable: true,
              yearlyPrice: r'$24.99',
              monthlyPrice: r'$2.99',
              owned: {ids.yearly},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You already have Field Guide.'), findsOneWidget);
    expect(find.text('Subscribed'), findsWidgets);
    expect(find.text('Start 7 days free'), findsNothing);
  });
}

PurchaseDetails _purchase(PurchaseStatus status, {String code = ''}) {
  return PurchaseDetails(
      purchaseID: '1',
      productID: fieldGuideYearlyPlay,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'test',
      ),
      transactionDate: null,
      status: status,
    )
    ..error = code.isEmpty
        ? null
        : IAPError(source: 'test', code: code, message: code);
}

Widget _host(Widget home) {
  return GuideScope(
    catalog: CatalogRepository(),
    notebook: Notebook(),
    settings: GuideSettings(),
    reload: () async {},
    selectTab: (_) {},
    child: MaterialApp(theme: guideTheme(Brightness.light), home: home),
  );
}
