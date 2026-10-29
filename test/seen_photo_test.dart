import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:whats_that_mushroom/species/seen_photo.dart';

void main() {
  test('a photo keeps its date and place, and the file drops them', () {
    final shot = img.Image(width: 4, height: 4);
    shot.exif.exifIfd['DateTimeOriginal'] = '2026:07:04 15:04:05';
    shot.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
    shot.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(481, 10);
    shot.exif.gpsIfd['GPSLongitudeRef'] = img.IfdValueAscii('W');
    shot.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational(171, 10);
    final bytes = Uint8List.fromList(img.encodeJpg(shot));

    final photo = seenPhotoFromBytes(bytes, now: DateTime(2026, 10, 25));

    expect(photo, isNotNull);
    expect(photo!.fromPhoto, isTrue);
    expect(photo.when, DateTime(2026, 7, 4, 15, 4, 5));
    expect(photo.latitude, closeTo(48.1, 0.0001));
    expect(photo.longitude, closeTo(-17.1, 0.0001));
    final place = photoPositionFromBytes(bytes);
    expect(place, isNotNull);
    expect(place!.latitude, closeTo(48.1, 0.0001));
    expect(place.longitude, closeTo(-17.1, 0.0001));
    final stored = img.decodeImage(photo.bytes);
    expect(stored, isNotNull);
    expect(stored!.exif.gpsIfd['GPSLatitude'], isNull);
    expect(stored.exif.exifIfd['DateTimeOriginal'], isNull);
  });

  test('a photo date keeps the clock and ignores a fraction', () {
    final shot = img.Image(width: 2, height: 2);
    shot.exif.exifIfd['DateTimeOriginal'] = '2023:06:25 15:33:04.12+02:00';
    final bytes = Uint8List.fromList(img.encodeJpg(shot));
    expect(photoDateFromBytes(bytes), DateTime(2023, 6, 25, 15, 33, 4));
  });

  test('a photo file reports its date', () async {
    final shot = img.Image(width: 2, height: 2);
    shot.exif.exifIfd['DateTimeDigitized'] = '2024:01:02 03:04:05';
    final root = await Directory.systemTemp.createTemp('photo-date');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final file = File('${root.path}/shot.jpg');
    await file.writeAsBytes(img.encodeJpg(shot));
    expect(await photoTakenAt(file.path), DateTime(2024, 1, 2, 3, 4, 5));
    expect(await photoTakenAt('${root.path}/missing.jpg'), isNull);
  });

  test('no GPS and a point off the globe are no place', () {
    expect(photoPlace(0, 0), isNull);
    expect(photoPlace(91, 10), isNull);
    expect(photoPlace(48.1, -17.1), isNotNull);
    final shot = img.Image(width: 2, height: 2);
    final bytes = Uint8List.fromList(img.encodeJpg(shot));
    expect(photoPositionFromBytes(bytes), isNull);
  });

  test('a photo without a date uses now', () {
    final shot = img.Image(width: 2, height: 2);
    final bytes = Uint8List.fromList(img.encodeJpg(shot));
    final now = DateTime(2026, 10, 25, 8, 0);
    final photo = seenPhotoFromBytes(bytes, now: now);
    expect(photo!.fromPhoto, isFalse);
    expect(photo.when, now);
    expect(photo.latitude, 0);
    expect(photo.longitude, 0);
  });

  test('a cancelled Android pick does not open the other picker', () async {
    final photo = await pickDevicePhoto(
      android: true,
      androidPicker: (_) async => null,
      imagePicker: (_) async => fail('image picker opened'),
    );
    expect(photo, isNull);
  });

  test('a missing Android picker uses the image picker', () async {
    final photo = await pickDevicePhoto(
      android: true,
      androidPicker: (_) async => throw PlatformException(code: 'unavailable'),
      imagePicker: (_) async => '/tmp/mushroom.jpg',
    );
    expect(photo, '/tmp/mushroom.jpg');
  });

  test('the picker cache file is the only one removed', () async {
    final root = await Directory.systemTemp.createTemp('seen-cache');
    final dir = Directory('${root.path}/guide-pick');
    await dir.create();
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final cache = File('${dir.path}/shot.jpg');
    await cache.writeAsBytes([1, 2, 3]);
    expect(seenPickCachePath(cache.path), isTrue);
    await deleteSeenPickCache(cache.path);
    expect(await cache.exists(), isFalse);

    final kept = File('${Directory.systemTemp.path}/kept-mushroom.jpg');
    await kept.writeAsBytes([1]);
    addTearDown(kept.delete);
    expect(seenPickCachePath(kept.path), isFalse);
    await deleteSeenPickCache(kept.path);
    expect(await kept.exists(), isTrue);
  });
}
