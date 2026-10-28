import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/field_guide/catalog.dart';
import 'package:whats_that_mushroom/purchase/account_entitlements.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/purchase/store_account.dart';

void main() {
  tearDown(Purchases.resetForTest);

  test('the store account token matches the server', () {
    expect(storeAccountToken('user-1'), '7fcda779-b5e0-55f8-9459-17d9f3a4f311');
  });

  test(
    'an Android plan unlocks the Apple phone and locks a second purchase',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      Purchases.replaceAccountProducts({fieldGuideYearlyPlay});
      expect(Purchases.hasFieldGuide(), isTrue);
      expect(Purchases.showsAds(), isFalse);
      expect(Purchases.owned, {fieldGuideYearlyApple});
      expect(Purchases.fieldGuideFromAccountOnly, isTrue);

      final catalog = fieldGuideCatalog(
        ids: FieldGuideIds.apple,
        storeAvailable: true,
        yearlyPrice: r'$24.99',
        monthlyPrice: r'$2.99',
        owned: Purchases.owned,
      );
      expect(catalog.yearly.owned, isTrue);
      expect(
        fieldGuideAccess(
          catalog: catalog,
          monthlyOnThisStore: false,
          fromAccountOnly: Purchases.fieldGuideFromAccountOnly,
        ).locked,
        isTrue,
      );
    },
  );

  test('a purchase just made shows before the server answers', () {
    Purchases.grantStorePurchase('not-a-plan');
    expect(Purchases.hasFieldGuide(), isFalse);
    Purchases.grantStorePurchase(fieldGuideMonthlyPlay);
    expect(Purchases.hasFieldGuide(), isTrue);
    Purchases.revokeStorePurchase(fieldGuideMonthlyPlay);
    expect(Purchases.hasFieldGuide(), isFalse);
  });

  test('an account plan is not a receipt on this phone', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    Purchases.replaceAccountProducts({fieldGuideMonthlyPlay});
    expect(Purchases.fieldGuideOnThisStore, isFalse);
    expect(Purchases.owned, {fieldGuideMonthlyPlay});
  });

  test('an empty cached entitlements row does not clear a later plan', () {
    final watch = EntitlementWatch();
    expect(
      watch.shouldApply(
        const AccountEntitlements(present: false, products: {}),
      ),
      isFalse,
    );
    final live = accountEntitlementsOf({
      'entitlements': {
        'products': {
          'shrooms_field_guide_monthly': {'active': true},
        },
      },
    });
    expect(watch.shouldApply(live), isTrue);
    applyAccountEntitlements(live);
    expect(Purchases.accountProducts, {'shrooms_field_guide_monthly'});

    final cleared = accountEntitlementsOf({
      'entitlements': {'products': {}},
    });
    expect(watch.shouldApply(cleared), isTrue);
    applyAccountEntitlements(cleared);
    expect(Purchases.hasFieldGuide(), isFalse);
  });

  test('the next Field Guide expiry is the soonest time still ahead', () {
    const now = 1_700_000_000_000;
    final clock = DateTime.fromMillisecondsSinceEpoch(now);
    final when = nextFieldGuideExpiry({
      'entitlements': {
        'products': {
          'field_guide_yearly': {'active': true, 'expiresAt': now + 5_000},
          'field_guide_monthly': {'active': true, 'expiresAt': now + 1_000},
          'shrooms_field_guide_yearly': {'active': false, 'expiresAt': now + 1},
        },
      },
    }, clock);
    expect(when?.millisecondsSinceEpoch, now + 1_000);
    expect(
      nextFieldGuideExpiry({
        'entitlements': {
          'products': {
            'field_guide_monthly': {'active': true, 'expiresAt': now},
          },
        },
      }, clock),
      isNull,
    );
  });

  test('an expired subscription is not active', () {
    const now = 1_700_000_000_000;
    final clock = DateTime.fromMillisecondsSinceEpoch(now);
    final expired = accountEntitlementsOf({
      'entitlements': {
        'products': {
          'field_guide_yearly': {'active': true, 'expiresAt': now},
          'shrooms_field_guide_monthly': {'active': true, 'expiresAt': now + 1},
          'field_guide_monthly': {'active': true},
          'other_product': {'active': true, 'expiresAt': now - 1},
        },
      },
    }, now: clock);
    expect(expired.products['field_guide_yearly'], isFalse);
    expect(expired.products['shrooms_field_guide_monthly'], isTrue);
    expect(expired.products['field_guide_monthly'], isTrue);
    expect(expired.products['other_product'], isTrue);
  });
}
