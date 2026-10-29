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
}
