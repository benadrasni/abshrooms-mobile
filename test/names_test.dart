import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/purchase/names.dart';

void main() {
  tearDown(Names.resetForTest);

  test('five names are included and an ad adds one', () {
    final open = Names.allowance(
      fieldGuide: false,
      now: DateTime.utc(2026, 10, 2),
    );
    expect(open.namesLeft, 5);
    expect(open.dotCount, 5);
    expect(open.filledDots, 5);
    expect(nameOffersAd(open), isFalse);

    Names.setForTest(used: 5, now: DateTime.utc(2026, 10, 2));
    final gone = Names.allowance(
      fieldGuide: false,
      now: DateTime.utc(2026, 10, 2),
    );
    expect(gone.namesLeft, 0);
    expect(nameOffersAd(gone), isTrue);
    expect(nameMonthExhausted(gone), isFalse);

    Names.setForTest(used: 6, grants: 1, now: DateTime.utc(2026, 10, 2));
    final afterAd = Names.allowance(
      fieldGuide: false,
      now: DateTime.utc(2026, 10, 2),
    );
    expect(afterAd.namesLeft, 0);
    expect(nameOffersAd(afterAd), isTrue);

    Names.setForTest(used: 10, grants: 5, now: DateTime.utc(2026, 10, 2));
    final done = Names.allowance(
      fieldGuide: false,
      now: DateTime.utc(2026, 10, 2),
    );
    expect(done.namesLeft, 0);
    expect(nameOffersAd(done), isFalse);
    expect(nameMonthExhausted(done), isTrue);
  });

  test('a new month starts again', () {
    Names.setForTest(used: 10, grants: 5, now: DateTime.utc(2026, 9, 30));
    final next = Names.allowance(
      fieldGuide: false,
      now: DateTime.utc(2026, 10, 1),
    );
    expect(next.namesLeft, 5);
    expect(nameOffersAd(next), isFalse);
  });

  test('Field Guide does not spend the month', () {
    Names.setForTest(used: 5, now: DateTime.utc(2026, 10, 2));
    final guide = Names.allowance(
      fieldGuide: true,
      now: DateTime.utc(2026, 10, 2),
    );
    expect(guide.unlimited, isTrue);
    expect(guide.dotCount, 0);
    expect(nameOffersAd(guide), isFalse);
    expect(
      Names.allowance(fieldGuide: true, signedIn: false).unlimited,
      isTrue,
    );
  });

  test('a guest has one name and an ad is not offered', () async {
    Names.setForTest();
    final open = Names.allowance(fieldGuide: false, signedIn: false);
    expect(open.guest, isTrue);
    expect(open.namesLeft, 1);
    expect(open.dotCount, 1);
    expect(open.filledDots, 1);
    expect(nameOffersAd(open), isFalse);
    expect(nameNeedsSignIn(open), isFalse);

    await Names.spend(signedIn: false);
    final used = Names.allowance(fieldGuide: false, signedIn: false);
    expect(used.namesLeft, 0);
    expect(nameNeedsSignIn(used), isTrue);
    expect(Names.count.namesUsed, 0);

    await Names.spend(signedIn: false);
    expect(
      Names.allowance(fieldGuide: false, signedIn: false).namesLeft,
      0,
    );
  });

  test('a server count replaces the phone and is not spent twice', () {
    Names.setForTest();
    Names.applyServer(
      signedIn: true,
      charged: true,
      anonymousFreeUsed: false,
      namesUsed: 2,
      adGrants: 1,
    );
    expect(Names.takeServerApply(), isTrue);
    expect(Names.takeServerApply(), isFalse);
    expect(Names.count.namesUsed, 2);
    expect(Names.count.adGrants, 1);
    expect(Names.lastCharged, isTrue);
    expect(
      Names.allowance(fieldGuide: false, now: DateTime.now()).namesLeft,
      4,
    );

    Names.applyServer(
      signedIn: false,
      charged: false,
      anonymousFreeUsed: false,
    );
    expect(
      Names.allowance(fieldGuide: false, signedIn: false).namesLeft,
      1,
    );
    Names.applyServer(
      signedIn: false,
      charged: true,
      anonymousFreeUsed: true,
    );
    expect(
      Names.allowance(fieldGuide: false, signedIn: false).namesLeft,
      0,
    );
  });
}
