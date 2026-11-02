import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/seen/publish.dart';
import 'package:whats_that_mushroom/seen/share.dart';

void main() {
  test('an account sighting is added when the phone has no copy', () {
    const photo = 'sightings/uid/1792940884503884.jpg';
    final next = mergeAccountSightings(const [], [
      (
        id: '1792940884503884',
        data: {
          'latin': 'Boletus reticulatus',
          'millis': 1687699986000,
          'status': 'public',
          'photo': photo,
        },
      ),
    ]);
    expect(next, hasLength(1));
    expect(next.single.latin, 'Boletus reticulatus');
    expect(next.single.millis, 1687699986000);
    expect(next.single.confirmed, isTrue);
    expect(next.single.share, FindShare.shared);
    expect(next.single.photoPath, contains('1792940884503884.jpg'));
    expect(seenPhotoOnPhone(next.single.photoPath), isFalse);
  });

  test('a sighting already on the phone keeps its file', () {
    final dir = Directory.systemTemp.createTempSync('sighting-sync');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/local.jpg')..writeAsStringSync('photo');
    final local = FindRecord(
      id: '1',
      millis: 5,
      latin: 'Boletus edulis',
      photoPath: file.path,
      confirmed: true,
    );
    final next = mergeAccountSightings(
      [local],
      [
        (
          id: '1',
          data: {
            'latin': 'Boletus edulis',
            'millis': 5,
            'status': 'public',
            'photo': 'sightings/uid/1.jpg',
          },
        ),
      ],
    );
    expect(next.single.photoPath, file.path);
    expect(next.single.share, FindShare.shared);
  });

  test('the same sightings are not written again', () {
    final local = FindRecord(
      id: '1',
      millis: 5,
      latin: 'Boletus edulis',
      confirmed: true,
      share: FindShare.shared,
      photoPath: 'https://firebasestorage.googleapis.com/v0/b/abshrooms-a9d4c.firebasestorage.app/o/sightings%2Fuid%2F1.jpg?alt=media',
    );
    final finds = [local];
    final next = mergeAccountSightings(finds, [
      (
        id: '1',
        data: {
          'latin': 'Boletus edulis',
          'millis': 5,
          'status': 'public',
          'photo': 'sightings/uid/1.jpg',
        },
      ),
    ]);
    expect(identical(next, finds), isTrue);
  });

  test('an in-review photo uses the download URL cached on the device', () {
    const cached =
        'https://firebasestorage.googleapis.com/v0/b/abshrooms-a9d4c.firebasestorage.app/o/sightings%2Fuid%2F1.jpg?alt=media&token=device-only';
    final next = mergeAccountSightings(const [], [
      (
        id: '1',
        data: {
          'latin': 'Boletus edulis',
          'millis': 5,
          'status': 'review',
          'photo': 'sightings/uid/1.jpg',
          'downloadUrl': cached,
        },
      ),
    ]);
    expect(next.single.share, FindShare.review);
    expect(next.single.photoPath, cached);
    expect(seenPhotoOnPhone(next.single.photoPath), isFalse);
  });

  test('a cached in-review URL stays when this sync has no new one', () {
    const cached =
        'https://firebasestorage.googleapis.com/v0/b/abshrooms-a9d4c.firebasestorage.app/o/sightings%2Fuid%2F1.jpg?alt=media&token=device-only';
    final local = FindRecord(
      id: '1',
      millis: 5,
      latin: 'Boletus edulis',
      confirmed: true,
      share: FindShare.review,
      photoPath: cached,
    );
    final finds = [local];
    final next = mergeAccountSightings(finds, [
      (
        id: '1',
        data: {
          'latin': 'Boletus edulis',
          'millis': 5,
          'status': 'review',
          'photo': 'sightings/uid/1.jpg',
        },
      ),
    ]);
    expect(identical(next, finds), isTrue);
  });

  test(
    'a public sighting does not keep a download token from the document',
    () {
      final next = mergeAccountSightings(const [], [
        (
          id: '1',
          data: {
            'latin': 'Boletus edulis',
            'millis': 5,
            'status': 'public',
            'photo': 'sightings/uid/1.jpg',
            'downloadUrl': 'https://example.com/secret?alt=media&token=leak',
          },
        ),
      ]);
      expect(next.single.photoPath, isNot(contains('token=')));
      expect(next.single.photoPath, contains('alt=media'));
    },
  );

  test('a remapped sighting takes the published name', () {
    final dir = Directory.systemTemp.createTempSync('sighting-remap');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/local.jpg')..writeAsStringSync('photo');
    final local = FindRecord(
      id: '1793571594516036',
      millis: 5,
      latin: 'Coprinellus disseminatus',
      photoPath: file.path,
      confirmed: true,
      share: FindShare.review,
    );
    final next = mergeAccountSightings(
      [local],
      [
        (
          id: '1793571594516036',
          data: {
            'latin': 'Leucocoprinus birnbaumii',
            'millis': 5,
            'status': 'public',
            'photo': 'sightings/uid/1793571594516036.jpg',
          },
        ),
      ],
    );
    expect(next.single.latin, 'Leucocoprinus birnbaumii');
    expect(next.single.share, FindShare.shared);
    expect(next.single.photoPath, file.path);
  });

  test('a sighting document with no name keeps the notebook name', () {
    final local = FindRecord(
      id: '1',
      millis: 5,
      latin: 'Boletus edulis',
      confirmed: true,
      share: FindShare.shared,
      photoPath: 'https://firebasestorage.googleapis.com/v0/b/abshrooms-a9d4c.firebasestorage.app/o/sightings%2Fuid%2F1.jpg?alt=media',
    );
    final finds = [local];
    final next = mergeAccountSightings(finds, [
      (
        id: '1',
        data: {
          'latin': ' ',
          'millis': 5,
          'status': 'public',
          'photo': 'sightings/uid/1.jpg',
        },
      ),
    ]);
    expect(identical(next, finds), isTrue);
    expect(next.single.latin, 'Boletus edulis');
  });

  test('an accepted sighting leaves in review', () {
    final dir = Directory.systemTemp.createTempSync('sighting-accepted');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/local.jpg')..writeAsStringSync('photo');
    final local = FindRecord(
      id: '1793233925274975',
      millis: 1793233925358,
      latin: 'Leucocoprinus birnbaumii',
      photoPath: file.path,
      confirmed: true,
      share: FindShare.review,
    );
    final next = mergeAccountSightings(
      [local],
      [
        (
          id: '1793233925274975',
          data: {
            'latin': 'Leucocoprinus birnbaumii',
            'millis': 1793233925358,
            'status': 'public',
            'photo': 'sightings/uid/1793233925274975.jpg',
          },
        ),
      ],
    );
    expect(next.single.share, FindShare.shared);
    expect(next.single.photoPath, file.path);
  });

  test('a sighting country is kept and a new one is copied onto the phone', () {
    final local = FindRecord(
      id: '1',
      millis: 5,
      latin: 'Boletus edulis',
      confirmed: true,
      share: FindShare.shared,
      country: 'sk',
      photoPath: 'https://firebasestorage.googleapis.com/v0/b/abshrooms-a9d4c.firebasestorage.app/o/sightings%2Fuid%2F1.jpg?alt=media',
    );
    final finds = [local];
    final same = mergeAccountSightings(finds, [
      (
        id: '1',
        data: {
          'latin': 'Boletus edulis',
          'millis': 5,
          'status': 'public',
          'photo': 'sightings/uid/1.jpg',
        },
      ),
    ]);
    expect(identical(same, finds), isTrue);
    expect(same.single.country, 'sk');

    final imported = mergeAccountSightings(const [], [
      (
        id: '2',
        data: {
          'latin': 'Amanita muscaria',
          'millis': 6,
          'status': 'public',
          'photo': 'sightings/uid/2.jpg',
          'country': 'AT',
        },
      ),
    ]);
    expect(imported.single.country, 'at');
  });

  test('a new sighting stores a country and coordinates', () {
    final fields = sightingCreateFields(
      uid: 'uid',
      id: '1',
      latin: 'Boletus edulis',
      millis: 5,
      country: ' SK ',
      latitude: 48.15,
      longitude: 17.11,
    );
    expect(fields['country'], 'sk');
    expect(fields['latitude'], 48.15);
    expect(fields['longitude'], 17.11);
    expect(fields['status'], 'review');
    expect(fields['photo'], 'sightings/uid/1.jpg');

    final bare = sightingCreateFields(
      uid: 'uid',
      id: '1',
      latin: 'Boletus edulis',
      millis: 5,
      country: 'Middle Europe',
      latitude: 0,
      longitude: 0,
    );
    expect(bare.containsKey('country'), isFalse);
    expect(bare.containsKey('latitude'), isFalse);
    expect(bare.containsKey('longitude'), isFalse);
  });

  test('a stored place is kept and a gap is filled', () {
    expect(
      sightingPlacePatch(
        country: 'us',
        latitude: 30.2,
        longitude: -95.6,
        remote: {'country': 'sk', 'latitude': 1, 'longitude': 2},
      ),
      isEmpty,
    );
    expect(
      sightingPlacePatch(
        country: 'US',
        latitude: 30.2,
        longitude: -95.6,
        remote: const {},
      ),
      {'country': 'us', 'latitude': 30.2, 'longitude': -95.6},
    );
    expect(sightingStoredPlace(0, 0), isNull);
    expect(sightingStoredPlace(91, 10), isNull);
    expect(sightingStoredPlace(48.1, 17.1)?.latitude, 48.1);
  });

  test('a sighting place is copied onto the phone and a local place stays', () {
    final finds = [
      FindRecord(
        id: '1',
        millis: 5,
        latin: 'Boletus edulis',
        confirmed: true,
        share: FindShare.shared,
        country: 'sk',
        latitude: 48.1,
        longitude: 17.1,
        photoPath: 'https://firebasestorage.googleapis.com/v0/b/abshrooms-a9d4c.firebasestorage.app/o/sightings%2Fuid%2F1.jpg?alt=media',
      ),
    ];
    final same = mergeAccountSightings(finds, [
      (
        id: '1',
        data: {
          'latin': 'Boletus edulis',
          'millis': 5,
          'status': 'public',
          'photo': 'sightings/uid/1.jpg',
          'country': 'sk',
          'latitude': 48.1,
          'longitude': 17.1,
        },
      ),
    ]);
    expect(identical(same, finds), isTrue);
    expect(finds.single.copyWith(share: FindShare.review).latitude, 48.1);

    final imported = mergeAccountSightings(const [], [
      (
        id: '2',
        data: {
          'latin': 'Amanita muscaria',
          'millis': 6,
          'status': 'public',
          'photo': 'sightings/uid/2.jpg',
          'country': 'US',
          'latitude': 30.2,
          'longitude': -95.6,
        },
      ),
    ]);
    expect(imported.single.country, 'us');
    expect(imported.single.latitude, 30.2);
    expect(imported.single.longitude, -95.6);

    final local = FindRecord(
      id: '3',
      millis: 7,
      latin: 'Boletus edulis',
      confirmed: true,
      share: FindShare.shared,
      country: 'sk',
      latitude: 48.2,
      longitude: 17.2,
    );
    final kept = mergeAccountSightings(
      [local],
      [
        (
          id: '3',
          data: {
            'latin': 'Boletus edulis',
            'millis': 7,
            'status': 'public',
            'photo': 'sightings/uid/3.jpg',
            'latitude': 0,
            'longitude': 0,
          },
        ),
      ],
    );
    expect(kept.single.latitude, 48.2);
    expect(kept.single.longitude, 17.2);
    expect(kept.single.country, 'sk');
  });

  test('a sighting refresh does not trust the cached review', () {
    expect(sightingGetOptions.source.name, 'server');
  });

  test('a missing document clears the shared mark', () {
    final local = FindRecord(
      id: '1',
      millis: 5,
      latin: 'Boletus edulis',
      confirmed: true,
      share: FindShare.shared,
    );
    final next = mergeAccountSightings([local], const []);
    expect(next.single.share, FindShare.none);
  });

  test('a deleted sighting leaves when its photo was only the cloud copy', () {
    const photo =
        'https://firebasestorage.googleapis.com/v0/b/abshrooms-a9d4c.firebasestorage.app/o/sightings%2Fuid%2F1.jpg?alt=media';
    final kept = FindRecord(
      id: 'local',
      millis: 4,
      latin: 'Amanita muscaria',
      confirmed: true,
    );
    final gone = FindRecord(
      id: '1',
      millis: 5,
      latin: 'Boletus edulis',
      confirmed: true,
      share: FindShare.none,
      photoPath: photo,
    );
    final next = mergeAccountSightings([kept, gone], const []);
    expect(next, hasLength(1));
    expect(next.single.id, 'local');
  });

  test('public sighting lists read the server', () {
    final species = File('lib/seen/species_sightings.dart').readAsStringSync();
    final stats = File('lib/seen/stats_page.dart').readAsStringSync();
    expect(species, contains('.get(sightingGetOptions)'));
    expect(stats, contains('.get(sightingGetOptions)'));
  });
}
