import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/seen/publish.dart';
import 'package:whats_that_mushroom/seen/share.dart';
import 'package:whats_that_mushroom/seen/sighting_storage.dart';

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

  test('an in-review sighting on another phone uses the download token', () {
    const token = '11111111-2222-4333-8444-555555555555';
    final next = mergeAccountSightings(const [], [
      (
        id: '1',
        data: {
          'latin': 'Boletus edulis',
          'millis': 5,
          'status': 'review',
          'photo': 'sightings/uid/1.jpg',
          'photoToken': token,
        },
      ),
    ]);
    expect(next.single.share, FindShare.review);
    expect(next.single.photoPath, contains('token=$token'));
    expect(seenPhotoOnPhone(next.single.photoPath), isFalse);
  });

  test('a token already on this phone is kept when the document has none', () {
    const token = '11111111-2222-4333-8444-555555555555';
    final local = FindRecord(
      id: '1',
      millis: 5,
      latin: 'Boletus edulis',
      confirmed: true,
      share: FindShare.review,
      photoPath: sightingPhotoUrl('sightings/uid/1.jpg', token: token),
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
