import 'dart:async';

import 'package:flutter/foundation.dart';
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

  test('a yearly trial is chosen ahead of a monthly-billed plan', () {
    final pick = fieldGuidePick([
      const FieldGuideCandidate(
        recurringPrice: r'$24.99',
        recurringRaw: 24.99,
        period: 'P1M',
        trial: false,
      ),
      const FieldGuideCandidate(
        recurringPrice: r'$24.99',
        recurringRaw: 24.99,
        period: 'P1Y',
        trial: true,
      ),
    ], yearly: true);
    expect(pick?.index, 1);
    expect(pick?.trial, isTrue);
    expect(pick?.period, 'P1Y');
    expect(pick?.price, r'$24.99');
  });

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

  test('a disconnected store is still asked for the prices', () async {
    var queried = false;
    final loaded = await loadFieldGuideCatalog(
      ids: ids,
      owned: const {},
      storeAvailable: () async => false,
      query: (productIds) async {
        queried = true;
        expect(productIds, {ids.monthly, ids.yearly});
        return ProductDetailsResponse(
          productDetails: [
            ProductDetails(
              id: ids.yearly,
              title: 'Yearly',
              description: '',
              price: r'$24.99',
              rawPrice: 24.99,
              currencyCode: 'USD',
            ),
            ProductDetails(
              id: ids.monthly,
              title: 'Monthly',
              description: '',
              price: r'$2.99',
              rawPrice: 2.99,
              currencyCode: 'USD',
            ),
          ],
          notFoundIDs: const [],
        );
      },
    );
    expect(queried, isTrue);
    expect(loaded.catalog.storeAvailable, isTrue);
    expect(loaded.catalog.yearly.price, r'$24.99');
    expect(loaded.catalog.monthly.price, r'$2.99');
  });

  test('a store query that throws is an empty catalog', () async {
    final loaded = await loadFieldGuideCatalog(
      ids: ids,
      owned: const {},
      storeAvailable: () async => throw StateError('down'),
      query: (productIds) async => throw StateError('disconnected'),
    );
    expect(loaded.catalog.storeAvailable, isFalse);
    expect(loaded.catalog.yearly.price, isNull);
    expect(loaded.catalog.monthly.price, isNull);
    expect(loaded.catalog.error, contains('disconnected'));
  });

  test('missing prices are retried only when the plan can still be bought', () {
    final empty = fieldGuideCatalog(
      ids: ids,
      storeAvailable: false,
      yearlyPrice: null,
      monthlyPrice: null,
      owned: const {},
    );
    expect(fieldGuideShouldRetryPrices(empty, locked: false), isTrue);
    expect(fieldGuideShouldRetryPrices(empty, locked: true), isFalse);

    final yearlyOnly = fieldGuideCatalog(
      ids: ids,
      storeAvailable: true,
      yearlyPrice: r'$24.99',
      monthlyPrice: null,
      owned: const {},
    );
    expect(fieldGuideShouldRetryPrices(yearlyOnly, locked: false), isFalse);
  });

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
    expect(find.text(r'7 days free, then $24.99 a year'), findsOneWidget);
    expect(find.text(r'7 days free, then $2.99 a month'), findsOneWidget);
    expect(
      find.text(
        r'Free for 7 days. The trial ends after 7 days, then $24.99 is charged every year. Cancel in Google Play before the trial ends and you will not be charged.',
      ),
      findsOneWidget,
    );
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Manage or cancel in Google Play'), findsOneWidget);

    await tester.tap(find.text('Subscribe'));
    await tester.pump();
    expect(bought, FieldGuidePlan.yearly);

    await tester.tap(find.byKey(fieldGuideMonthlyKey));
    await tester.pump();
    expect(
      find.text(
        r'Free for 7 days. The trial ends after 7 days, then $2.99 is charged every month. Cancel in Google Play before the trial ends and you will not be charged.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Subscribe'));
    await tester.pump();
    expect(bought, FieldGuidePlan.monthly);
  });

  testWidgets('a second store answer shows the prices and enables Subscribe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    var bought = false;
    await tester.pumpWidget(
      _host(
        FieldGuidePage(
          plate: (_) => const SizedBox.shrink(),
          priceRetry: Duration.zero,
          load: () async {
            calls++;
            if (calls == 1) {
              return FieldGuideLoaded(
                catalog: fieldGuideCatalog(
                  ids: ids,
                  storeAvailable: false,
                  yearlyPrice: null,
                  monthlyPrice: null,
                  owned: const {},
                ),
              );
            }
            return FieldGuideLoaded(
              catalog: fieldGuideCatalog(
                ids: ids,
                storeAvailable: true,
                yearlyPrice: r'$24.99',
                monthlyPrice: r'$2.99',
                owned: const {},
              ),
            );
          },
          buy: (plan) async {
            bought = plan == FieldGuidePlan.yearly;
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Store price'), findsNothing);
    expect(find.text('Subscribe'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Store price'), findsNothing);
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(find.text(r'$2.99'), findsOneWidget);

    await tester.tap(find.text('Subscribe'));
    await tester.pump();
    expect(bought, isTrue);
  });

  testWidgets('retries stop and the plans show Store price', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(
      _host(
        FieldGuidePage(
          plate: (_) => const SizedBox.shrink(),
          priceRetry: Duration.zero,
          load: () async {
            calls++;
            return _unpriced();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, fieldGuidePriceRetries + 1);
    expect(find.text('Store price'), findsNWidgets(2));
    expect(
      find.text('The store doesn’t have these plans yet.'),
      findsOneWidget,
    );
    expect(find.text('Subscribe'), findsOneWidget);
  });

  testWidgets('one priced plan is shown without another store query', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(
      _host(
        FieldGuidePage(
          plate: (_) => const SizedBox.shrink(),
          priceRetry: Duration.zero,
          load: () async {
            calls++;
            return FieldGuideLoaded(
              catalog: fieldGuideCatalog(
                ids: ids,
                storeAvailable: true,
                yearlyPrice: r'$24.99',
                monthlyPrice: null,
                owned: const {},
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(find.text('Store price'), findsOneWidget);
  });

  testWidgets('an owned guide does not keep asking the store for prices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(
      _host(
        FieldGuidePage(
          plate: (_) => const SizedBox.shrink(),
          priceRetry: Duration.zero,
          load: () async {
            calls++;
            return FieldGuideLoaded(
              catalog: fieldGuideCatalog(
                ids: ids,
                storeAvailable: false,
                yearlyPrice: null,
                monthlyPrice: null,
                owned: {ids.yearly},
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('You already have Field Guide.'), findsOneWidget);
    expect(find.text('Subscribed'), findsWidgets);
  });

  testWidgets('coming back reloads missing prices and leaves loaded ones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(
      _host(
        FieldGuidePage(
          plate: (_) => const SizedBox.shrink(),
          priceRetry: Duration.zero,
          load: () async {
            calls++;
            if (calls <= fieldGuidePriceRetries + 1) return _unpriced();
            return _priced();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, fieldGuidePriceRetries + 1);
    expect(find.text('Store price'), findsNWidgets(2));

    await _resume(tester);
    await tester.pumpAndSettle();
    expect(calls, fieldGuidePriceRetries + 2);
    expect(find.text('Store price'), findsNothing);
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(find.text(r'$2.99'), findsOneWidget);

    await _resume(tester);
    await tester.pumpAndSettle();
    expect(calls, fieldGuidePriceRetries + 2);
  });

  testWidgets('coming back during the first load does not query again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<FieldGuideLoaded>();
    var calls = 0;
    await tester.pumpWidget(
      _host(
        FieldGuidePage(
          plate: (_) => const SizedBox.shrink(),
          load: () {
            calls++;
            return gate.future;
          },
        ),
      ),
    );
    await tester.pump();
    expect(calls, 1);

    await _resume(tester);
    expect(calls, 1);

    gate.complete(_priced());
    await tester.pumpAndSettle();
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets('Try again leaves the error and shows the plans loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<FieldGuideLoaded>();
    var calls = 0;
    await tester.pumpWidget(
      _host(
        FieldGuidePage(
          plate: (_) => const SizedBox.shrink(),
          load: () async {
            calls++;
            if (calls == 1) throw StateError('down');
            return gate.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load this.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Couldn’t load this.'), findsNothing);
    expect(find.text('Field Guide'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    gate.complete(_priced());
    await tester.pumpAndSettle();
    expect(find.text(r'$24.99'), findsOneWidget);
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
    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets('a purchase shows subscribed before the server answers', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
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
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Subscribe'), findsOneWidget);

      Purchases.grantStorePurchase(ids.yearly);
      await tester.pump();
      expect(find.text('Subscribed'), findsWidgets);

      Purchases.revokeStorePurchase(ids.yearly);
      await tester.pump();
      expect(find.text('Subscribe'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a lifetime subscription says subscribed', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Purchases.setLifetimeSubscription(true);
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
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You already have Field Guide.'), findsOneWidget);
    expect(find.text('Subscribed'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text(r'7 days free, then $24.99 a year'), findsNothing);
  });

  testWidgets('a monthly plan opens with yearly selected', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
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
              owned: {ids.monthly},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_planBorderWidth(tester, fieldGuideYearlyKey), 2);
    expect(_planBorderWidth(tester, fieldGuideMonthlyKey), 1);
    expect(find.text('Subscribed'), findsWidgets);
  });
}

FieldGuideLoaded _unpriced() {
  return FieldGuideLoaded(
    catalog: fieldGuideCatalog(
      ids: FieldGuideIds.play,
      storeAvailable: false,
      yearlyPrice: null,
      monthlyPrice: null,
      owned: const {},
    ),
  );
}

FieldGuideLoaded _priced() {
  return FieldGuideLoaded(
    catalog: fieldGuideCatalog(
      ids: FieldGuideIds.play,
      storeAvailable: true,
      yearlyPrice: r'$24.99',
      monthlyPrice: r'$2.99',
      owned: const {},
    ),
  );
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

double _planBorderWidth(WidgetTester tester, Key key) {
  final shape = tester.widget<Material>(find.byKey(key)).shape;
  return (shape as RoundedRectangleBorder).side.width;
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
