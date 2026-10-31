import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/seen/publish.dart';
import 'package:whats_that_mushroom/seen/share.dart';

void main() {
  test('an unverified password account cannot publish a sighting', () {
    expect(
      sightingAccountSignedIn(
        firebaseReady: true,
        hasUser: true,
        anonymous: false,
        emailVerified: false,
        providerIds: const ['password'],
      ),
      isFalse,
    );
    expect(
      sightingAccountSignedIn(
        firebaseReady: true,
        hasUser: true,
        anonymous: false,
        emailVerified: true,
        providerIds: const ['password'],
      ),
      isTrue,
    );
    expect(
      sightingAccountSignedIn(
        firebaseReady: true,
        hasUser: true,
        anonymous: false,
        emailVerified: false,
        providerIds: const ['google.com'],
      ),
      isTrue,
    );
    expect(
      sightingAccountSignedIn(
        firebaseReady: true,
        hasUser: true,
        anonymous: true,
        emailVerified: false,
        providerIds: const [],
      ),
      isFalse,
    );
    expect(
      sightingAccountSignedIn(
        firebaseReady: false,
        hasUser: true,
        anonymous: false,
        emailVerified: true,
        providerIds: const ['password'],
      ),
      isFalse,
    );
  });

  test('share is only for a confirmed catalog species with a photo', () {
    final dir = Directory.systemTemp.createTempSync('seen-share');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = File('${dir.path}/a.jpg')..writeAsStringSync('photo');
    final ready = FindRecord(
      id: '1',
      millis: 1,
      latin: 'Boletus edulis',
      photoPath: photo.path,
      confirmed: true,
    );
    expect(seenChip(ready, inBook: true, catalogKnown: true), SeenChip.share);
    expect(
      seenChip(ready, inBook: false, catalogKnown: true),
      SeenChip.outside,
    );
    expect(
      seenChip(
        ready.copyWith(confirmed: false),
        inBook: true,
        catalogKnown: true,
      ),
      isNull,
    );
    expect(
      seenChip(
        FindRecord(
          id: '1',
          millis: 1,
          latin: 'Boletus edulis',
          photoPath: '${dir.path}/missing.jpg',
          confirmed: true,
        ),
        inBook: true,
        catalogKnown: true,
      ),
      isNull,
    );
    expect(seenChip(ready, inBook: true, catalogKnown: false), isNull);
    expect(
      seenChip(
        ready.copyWith(share: FindShare.review),
        inBook: true,
        catalogKnown: true,
      ),
      SeenChip.review,
    );
    expect(
      seenChip(
        ready.copyWith(share: FindShare.shared),
        inBook: false,
        catalogKnown: true,
      ),
      SeenChip.shared,
    );
    expect(
      seenChip(
        ready.copyWith(share: FindShare.rejected),
        inBook: true,
        catalogKnown: true,
      ),
      SeenChip.rejected,
    );
  });

  test('hiding shared skips only confirmed public finds', () {
    final shared = FindRecord(
      id: 's',
      millis: 3,
      confirmed: true,
      share: FindShare.shared,
    );
    final review = FindRecord(
      id: 'r',
      millis: 2,
      confirmed: true,
      share: FindShare.review,
    );
    final open = FindRecord(id: 'o', millis: 1);
    expect(seenSharedCount([shared, review, open]), 1);
    expect(seenHidingShared([shared, review, open]).map((find) => find.id), [
      'r',
      'o',
    ]);
  });

  test('a stored share name and a public status both read back', () {
    expect(findShareFrom('review'), FindShare.review);
    expect(findShareFrom('public'), FindShare.shared);
    expect(findShareFrom('shared'), FindShare.shared);
    expect(findShareFrom('rejected'), FindShare.rejected);
    expect(findShareFrom(null), FindShare.none);
    final record = FindRecord(
      id: 'a',
      millis: 1,
      latin: 'Boletus edulis',
      confirmed: true,
      share: FindShare.review,
    );
    final again = FindRecord.fromJson(record.toJson());
    expect(again.share, FindShare.review);
    expect(
      FindRecord.fromJson(record.copyWith(share: FindShare.none).toJson())
          .share,
      FindShare.none,
    );
  });
}
