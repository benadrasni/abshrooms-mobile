import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/field_guide/catalog.dart';
import 'package:whats_that_mushroom/purchase/account_entitlements.dart';
import 'package:whats_that_mushroom/purchase/entitlements.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/purchase/store_account.dart';

void main() {
  tearDown(() {
    Purchases.resetForTest();
    Entitlements.debugReset();
  });

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

  test(
    'a plan that will not renew leaves at expiry and a renewal stays active',
    () {
      const now = 1_700_000_000_000;
      final clock = DateTime.fromMillisecondsSinceEpoch(now);
      final parsed = accountEntitlementsOf({
        'entitlements': {
          'products': {
            'field_guide_yearly': {
              'active': true,
              'expiresAt': now + 5_000,
              'willNotRenew': true,
            },
            'shrooms_field_guide_monthly': {
              'active': true,
              'expiresAt': now,
              'willNotRenew': true,
            },
            'field_guide_monthly': {'active': true, 'expiresAt': now - 1},
            'shrooms_field_guide_yearly': {
              'active': false,
              'expiresAt': now + 1,
              'willNotRenew': true,
            },
            'other_product': {'active': true, 'expiresAt': now - 1},
          },
        },
      }, now: clock);
      expect(parsed.products['field_guide_yearly'], isTrue);
      expect(parsed.products['shrooms_field_guide_monthly'], isFalse);
      expect(parsed.products['field_guide_monthly'], isTrue);
      expect(parsed.products['shrooms_field_guide_yearly'], isFalse);
      expect(parsed.products['other_product'], isTrue);
      expect(
        fieldGuideExpiryDueAt({
          'entitlements': {
            'products': {
              'field_guide_yearly': {
                'active': true,
                'expiresAt': now - 5,
                'willNotRenew': true,
              },
              'field_guide_monthly': {'active': true, 'expiresAt': now},
              'shrooms_field_guide_yearly': {
                'active': false,
                'expiresAt': now - 1,
              },
            },
          },
        }, clock),
        now,
      );
      expect(
        fieldGuideExpiryDueAt({
          'entitlements': {
            'products': {
              'field_guide_monthly': {
                'active': true,
                'expiresAt': now + 1,
                'willNotRenew': true,
              },
            },
          },
        }, clock),
        isNull,
      );
    },
  );

  test('a throttled refresh is not settled and does not clear a settle', () {
    expect(storedRefreshOf({'throttled': true}), StoredRefresh.throttled);
    expect(storedRefreshOf({'retry': true}), StoredRefresh.retry);
    expect(
      storedRefreshOf({'throttled': true, 'retry': true}),
      StoredRefresh.throttled,
    );
    expect(
      storedRefreshOf({'products': <String, bool>{}}),
      StoredRefresh.settled,
    );
    const due = 5;
    final kept = refreshMarksAfter(
      const RefreshMarks(rechecked: due, settled: due),
      due,
      StoredRefresh.throttled,
    );
    expect(kept.settled, due);
    final cleared = refreshMarksAfter(
      const RefreshMarks(rechecked: due, settled: due),
      due,
      StoredRefresh.retry,
    );
    expect(cleared.settled, isNull);
    expect(cleared.rechecked, isNull);
  });

  test('a lost submit response restores Field Guide from the account row', () {
    final recovery = LostSubmitRecovery();
    Purchases.grantStorePurchase(fieldGuideMonthlyPlay);
    Purchases.revokeStorePurchase(fieldGuideMonthlyPlay);
    final missing = accountEntitlementsOf({
      'entitlements': {'products': <String, dynamic>{}},
    });
    expect(recovery.note(fieldGuideMonthlyPlay, missing), isFalse);
    expect(Purchases.hasFieldGuide(), isFalse);
    expect(recovery.reread(missing), isFalse);
    final lapsed = accountEntitlementsOf({
      'entitlements': {
        'products': {
          fieldGuideMonthlyPlay: {
            'active': true,
            'expiresAt': 1,
            'willNotRenew': true,
          },
        },
      },
    }, now: DateTime.fromMillisecondsSinceEpoch(5));
    expect(recovery.reread(lapsed), isFalse);
    expect(Purchases.hasFieldGuide(), isFalse);
    final found = accountEntitlementsOf({
      'entitlements': {
        'products': {
          fieldGuideMonthlyPlay: {'active': true},
        },
      },
    });
    expect(recovery.reread(found), isTrue);
    expect(Purchases.hasFieldGuide(), isTrue);
    expect(recovery.pendingProduct, isNull);
  });

  test('a lifetime subscription is Field Guide without a store plan', () {
    expect(lifetimeSubscriptionOf(null), isFalse);
    expect(lifetimeSubscriptionOf({'lifetime subscription': 'true'}), isFalse);
    expect(lifetimeSubscriptionOf({'lifetime subscription': 1}), isFalse);

    Entitlements.debugReset(
      uid: 'user-1',
      user: {'lifetime subscription': true, 'token': 'abc'},
    );
    Entitlements.applyIfLoaded();
    expect(Purchases.lifetimeSubscription, isTrue);
    expect(Purchases.hasFieldGuide(), isTrue);
    expect(Purchases.showsAds(), isFalse);
    expect(Purchases.accountProducts, isEmpty);
    expect(Purchases.fieldGuideFromAccountOnly, isTrue);

    Entitlements.debugReset(
      uid: 'user-1',
      user: {
        'lifetime subscription': true,
        'entitlements': {'products': <String, dynamic>{}},
      },
    );
    Entitlements.applyIfLoaded();
    expect(Purchases.hasFieldGuide(), isTrue);
    expect(Purchases.accountProducts, isEmpty);

    Purchases.replaceAccountProducts({fieldGuideMonthlyPlay});
    Purchases.setLifetimeSubscription(false);
    expect(Purchases.hasFieldGuide(), isTrue);
    expect(Purchases.accountProducts, {fieldGuideMonthlyPlay});

    Entitlements.debugReset(
      uid: 'user-1',
      user: {
        'lifetime subscription': false,
        'entitlements': {'products': <String, dynamic>{}},
      },
    );
    Entitlements.applyIfLoaded();
    expect(Purchases.lifetimeSubscription, isFalse);
    expect(Purchases.hasFieldGuide(), isFalse);
    expect(Purchases.showsAds(), isTrue);
  });

  test('a lost submitPurchase response is read again on resume', () async {
    var reads = 0;
    Entitlements.debugReset(
      uid: 'user-1',
      user: {
        'entitlements': {'products': <String, dynamic>{}},
      },
      readUser: (_) async {
        reads += 1;
        if (reads == 1) {
          return {
            'entitlements': {'products': <String, dynamic>{}},
          };
        }
        return {
          'entitlements': {
            'products': {
              fieldGuideMonthlyPlay: {'active': true},
            },
          },
        };
      },
    );
    Purchases.grantStorePurchase(fieldGuideMonthlyPlay);
    Purchases.revokeStorePurchase(fieldGuideMonthlyPlay);
    await Entitlements.recoverLostSubmit(fieldGuideMonthlyPlay);
    expect(Purchases.hasFieldGuide(), isFalse);
    expect(reads, 1);
    Entitlements.onResume();
    await Entitlements.debugReread;
    expect(reads, 2);
    expect(Purchases.hasFieldGuide(), isTrue);
  });
}
