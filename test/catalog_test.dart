import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:whats_that_mushroom/camera/plant_id.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/key_filter.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/data/search.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/species/seen_photo.dart';

Catalog _catalog() {
  return buildCatalog(
    language: 'sk',
    speciesDocs: [
      Doc('Boletus edulis', {
        'name': 'Boletus edulis',
        'author': 'Bull.',
        'taxonomy': {
          'order': 'Boletales',
          'family': 'Boletaceae',
          'genus': 'Boletus',
        },
        'edibility': 'choice',
        'fruitingFrom': 6,
        'fruitingTo': 2,
        'capWidthFromCm': 8,
        'capWidthToCm': 25,
        'stipeThicknessFromCm': 1.5,
        'stipeThicknessToCm': 4,
        'hymenium': 'tubes',
        'where': ['ground'],
        'color': ['brown'],
      }),
      Doc('Amanita muscaria', {
        'name': 'Amanita muscaria',
        'taxonomy': {
          'order': 'Agaricales',
          'family': 'Amanitaceae',
          'genus': 'Amanita',
        },
        'fruitingFrom': 7,
        'fruitingTo': 11,
        'hymenium': 'gills',
        'where': ['ground'],
        'color': ['red', 'yellow'],
      }),
      Doc('NoKey species', {
        'name': 'NoKey species',
        'taxonomy': {'family': 'Boletaceae', 'genus': 'Boletus'},
        'fruitingFrom': 9,
        'fruitingTo': 10,
      }),
    ],
    local: {
      'Boletus edulis': {
        'label': 'Hríb smrekový',
        'sourceUrls': ['https://sk.example/hrib'],
      },
      'Amanita muscaria': {'label': 'Muchotrávka červená'},
    },
    english: {
      'Boletus edulis': {
        'label': 'penny bun',
        'description': 'A bolete.',
        'notes': 'English note.',
        'names': ['cep'],
        'sourceUrls': ['https://en.example/boletus'],
      },
      'NoKey species': {
        'label': 'invented name',
        'description': 'English body.',
        'names': ['cep'],
        'sourceUrls': ['https://en.example/nokey'],
      },
    },
    synonyms: {
      'Boletus edulis': {
        'homotypic': [
          {'name': 'Leccinum edule', 'author': 'Gray'},
        ],
        'heterotypic': [
          {'name': 'Boletus solidus', 'author': 'Sowerby'},
        ],
      },
    },
    taxa: {'Boletus': 'Hríb', 'Boletaceae': 'Hríbovité'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Slovak display keeps a bare Latin name', () {
    final catalog = _catalog();
    final bolete = catalog.byName('Boletus edulis')!;
    final missing = catalog.byName('NoKey species')!;
    expect(displayName('Hríb smrekový', 'sk'), 'hríb smrekový');
    expect(displayName('Penny bun', 'en'), 'Penny bun');
    expect(titleFor(null, 'Boletus edulis', 'sk'), 'Boletus edulis');
    expect(catalog.heading(bolete), 'hríb smrekový');
    expect(catalog.taxonTitle('Boletus'), 'hríb');
    expect(catalog.taxonTitle('Amanita'), 'Amanita');
    expect(catalog.textFor(missing).label, isNull);
    expect(catalog.textFor(missing).names, isEmpty);
    expect(catalog.textFor(missing).description, 'English body.');
    expect(catalog.heading(missing), 'NoKey species');
    expect(catalog.textFor(bolete).description, 'A bolete.');
    expect(catalog.textFor(bolete).notes, isNull);
    expect(catalog.textFor(bolete).names, isEmpty);
    expect(catalog.textFor(bolete).sourceUrls, ['https://sk.example/hrib']);
    expect(catalog.textFor(missing).sourceUrls, ['https://en.example/nokey']);
  });

  test('thickness stays a double and whole centimetres drop the decimal', () {
    final bolete = _catalog().byName('Boletus edulis')!;
    expect(bolete.stipeThickFrom, 1.5);
    expect(bolete.capFrom, 8);
    expect(cm(1.5), '1.5');
    expect(cm(8), '8');
    expect(bolete.synonymLines, [
      'Leccinum edule Gray',
      'Boletus solidus Sowerby',
    ]);
  });

  test('a fruiting window can wrap past December', () {
    final catalog = _catalog();
    final bolete = catalog.byName('Boletus edulis')!;
    expect(fruitingMonths(6, 2), [6, 7, 8, 9, 10, 11, 12, 1, 2]);
    expect(bolete.fruitsIn(1), isTrue);
    expect(matchesAxis(bolete, 'season', 'winter'), isTrue);
    expect(matchesAxis(bolete, 'season', 'spring'), isFalse);
    expect(matchesAxis(bolete, 'season', 'summer'), isTrue);
  });

  test('a species with no key row is hidden by where and colour', () {
    final catalog = _catalog();
    final missing = catalog.byName('NoKey species')!;
    expect(matchesSelection(missing, const KeySelection()), isTrue);
    expect(matchesAxis(missing, 'where', 'ground'), isFalse);
    expect(matchesAxis(missing, 'color', 'brown'), isFalse);
    expect(
      matchesSelection(missing, const KeySelection(where: 'ground')),
      isFalse,
    );
    final colors = optionCounts(
      catalog.species,
      const KeySelection(under: 'tubes'),
      'color',
    );
    expect(colors['brown'], 1);
    expect(colors['red'], 0);
    final where = optionCounts(catalog.species, const KeySelection(), 'where');
    expect(where['ground'], 2);
  });

  test('re-tapping a key choice clears it', () {
    const tubes = KeySelection(under: 'tubes', where: 'ground');
    expect(tubes.toggle('under', 'tubes').under, isEmpty);
    expect(tubes.toggle('under', 'tubes').where, 'ground');
    expect(tubes.toggle('color', 'brown').color, 'brown');
  });

  test('January puts the wrapped bolete ahead of the others', () {
    final catalog = _catalog();
    final rows = orderedResults(
      catalog,
      catalog.species,
      const KeySelection(),
      1,
    );
    expect(rows.first.name, 'Boletus edulis');
    expect(rows.map((item) => item.name), isNot(contains('missing')));
  });

  test('search ranks a genus ahead of a species', () {
    final catalog = _catalog();
    expect(searchHits(catalog, 'a'), isEmpty);
    final hits = searchHits(catalog, 'boletus');
    expect(hits.map((hit) => '${hit.kind}:${hit.name}:${hit.score}').toList(), [
      'genus:Boletus:0',
      'mushroom:Boletus edulis:4',
    ]);
    final spoken = searchHits(catalog, 'hríb');
    expect(spoken.first.kind, 'genus');
    expect(spoken.first.name, 'Boletus');
    expect(spoken.first.score, 0);
    expect(
      spoken.any((hit) => hit.kind == 'mushroom' && hit.score == 4),
      isTrue,
    );
  });

  test('an invalid catalog day stays empty', () {
    Catalog day(Object? added) {
      return buildCatalog(
        language: 'en',
        speciesDocs: [
          Doc('Serpula lacrymans', {
            'name': 'Serpula lacrymans',
            'id': 80,
            if (added != null) 'added': added,
          }),
        ],
        local: const {},
        english: const {},
        synonyms: const {},
        taxa: const {},
      );
    }

    expect(day('2026-10-28').species.single.added, '2026-10-28');
    expect(day('not-a-date').species.single.added, '');
    expect(day(null).species.single.added, '');
  });

  test('a species document keeps only allowed key codes', () {
    Catalog keyed({
      Object? hymenium = 'smooth',
      Object? where = const ['ground', 'petal'],
      Object? color = const ['white'],
    }) {
      return buildCatalog(
        language: 'en',
        speciesDocs: [
          Doc('Serpula lacrymans', {
            'name': 'Serpula lacrymans',
            if (hymenium != null) 'hymenium': hymenium,
            if (where != null) 'where': where,
            if (color != null) 'color': color,
          }),
        ],
        local: const {},
        english: const {},
        synonyms: const {},
        taxa: const {},
      );
    }

    final kept = keyed().species.single;
    expect(kept.hymenium, 'smooth');
    expect(kept.where, ['ground']);
    expect(kept.colors, ['white']);

    final rejected = keyed(hymenium: 'pores', where: const [], color: 'brown');
    expect(rejected.species.single.hymenium, '');
    expect(rejected.species.single.where, isEmpty);
    expect(rejected.species.single.colors, isEmpty);

    final missing = keyed(
      hymenium: null,
      where: null,
      color: null,
    ).species.single;
    expect(missing.hymenium, '');
    expect(missing.where, isEmpty);
    expect(missing.colors, isEmpty);
  });

  test('closed Firestore rules are named as permission-denied', () {
    expect(
      catalogDenied(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      isTrue,
    );
    expect(catalogDenied(Exception('offline')), isFalse);
  });

  test('photo names keep confidence bands and parse only fungi cards', () {
    const copy = Copy('en');
    expect(confidenceLabel(0.5, copy), 'Likely');
    expect(confidenceLabel(0.2, copy), 'Possible');
    expect(confidenceLabel(0.19, copy), 'Uncertain');
    expect(cameraFailure(Exception('x'), copy), copy.cameraFailed);
    expect(
      cameraFailure(_FunctionsException('unauthenticated'), copy),
      copy.cameraNeedsAccount,
    );
    expect(
      cameraFailure(
        _FunctionsException('unauthenticated'),
        copy,
        signedIn: true,
      ),
      copy.cameraAuthExpired,
    );
    expect(
      cameraFailure(_FunctionsException('not-found'), copy),
      copy.cameraUnavailable,
    );
    expect(
      guessesFrom({
        'suggestions': [
          {
            'scientificName': 'Amanita muscaria',
            'probability': 0.8,
            'commonNames': ['fly agaric', ''],
          },
          {'scientificName': '  ', 'probability': 0.1},
        ],
      }).map((guess) => guess.scientificName),
      ['Amanita muscaria'],
    );
  });

  test('a wide photo is resized so the long edge is 1280', () {
    final source = img.Image(width: 2000, height: 1000);
    final bytes = img.encodeJpg(source);
    final resized = img.decodeJpg(jpegMaxEdge(bytes, edge: 1280)!)!;
    expect(resized.width, 1280);
    expect(resized.height, 640);
  });

  test('a photo sent for a name drops the date and the place', () {
    for (final size in const [(8, 4), (2000, 1000)]) {
      final shot = img.Image(width: size.$1, height: size.$2);
      shot.exif.exifIfd['DateTimeOriginal'] = '2023:06:25 15:33:04';
      shot.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
      shot.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(481, 10);
      shot.exif.gpsIfd['GPSLongitudeRef'] = img.IfdValueAscii('W');
      shot.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational(171, 10);
      final bytes = Uint8List.fromList(img.encodeJpg(shot));
      final place = photoPositionFromBytes(bytes);
      expect(place, isNotNull);
      expect(place!.latitude, closeTo(48.1, 0.0001));
      expect(place.longitude, closeTo(-17.1, 0.0001));
      expect(photoDateFromBytes(bytes), DateTime(2023, 6, 25, 15, 33, 4));

      final named = jpegMaxEdge(bytes, edge: 1280)!;
      expect(photoPositionFromBytes(named), isNull);
      expect(photoDateFromBytes(named), isNull);
      expect(String.fromCharCodes(named).contains('2023:06:25'), isFalse);
      final stored = img.decodeJpg(named)!;
      expect(stored.exif.gpsIfd['GPSLatitude'], isNull);
      expect(stored.exif.exifIfd['DateTimeOriginal'], isNull);
      if (size.$1 == 2000) {
        expect(stored.width, 1280);
        expect(stored.height, 640);
      }
    }
  });

  test('a turned photo stays turned after the place is dropped', () {
    final shot = img.Image(width: 4, height: 2);
    shot.setPixelRgb(0, 0, 255, 0, 0);
    shot.exif.imageIfd.orientation = 6;
    shot.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
    shot.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(10, 1);
    shot.exif.gpsIfd['GPSLongitudeRef'] = img.IfdValueAscii('E');
    shot.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational(10, 1);
    final bytes = Uint8List.fromList(img.encodeJpg(shot));
    final decoded = img.decodeJpg(bytes)!;
    final named = jpegMaxEdge(bytes)!;
    final stored = img.decodeJpg(named)!;
    expect(stored.width, decoded.width);
    expect(stored.height, decoded.height);
    expect(photoPositionFromBytes(named), isNull);
    expect(stored.exif.imageIfd.orientation, isNull);
  });

  test('a photo that cannot be read still drops its place', () {
    final bytes = Uint8List.fromList([
      0xff, 0xd8, //
      0xff, 0xe1, 0x00, 0x0e, //
      0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // Exif
      0x47, 0x50, 0x53, 0x4c, 0x41, 0x54, // GPSLAT
      0xff, 0xda, 0x00, 0x02, 0x01, 0x02, 0x03, //
      0xff, 0xd9,
    ]);
    expect(img.decodeImage(bytes), isNull);
    final named = jpegMaxEdge(bytes)!;
    expect(named, [
      0xff, 0xd8, //
      0xff, 0xda, 0x00, 0x02, 0x01, 0x02, 0x03, //
      0xff, 0xd9,
    ]);

    final xmp = [
      ...'http://ns.adobe.com/xap/1.0/\x00'.codeUnits,
      ...'GPSLAT'.codeUnits,
    ];
    final xmpLength = xmp.length + 2;
    final withXmp = Uint8List.fromList([
      0xff, 0xd8, //
      0xff, 0xe1, xmpLength >> 8, xmpLength & 0xff, //
      ...xmp,
      0xff, 0xd9,
    ]);
    expect(img.decodeImage(withXmp), isNull);
    expect(
      String.fromCharCodes(jpegMaxEdge(withXmp)!).contains('GPSLAT'),
      isFalse,
    );
    expect(jpegMaxEdge(Uint8List.fromList(const [1, 2, 3])), isNull);
  });

  test('a photo that cannot be read drops APP2, APP13, and comments', () {
    final cases = <int, List<int>>{
      0xe2: [...'MPF\x00'.codeUnits, ...'GPSLAT'.codeUnits],
      0xed: [...'Photoshop 3.0\x00'.codeUnits, ...'GPSLAT'.codeUnits],
      0xfe: [...'GPSLAT'.codeUnits],
    };
    for (final entry in cases.entries) {
      final payload = entry.value;
      final length = payload.length + 2;
      final bytes = Uint8List.fromList([
        0xff, 0xd8, //
        0xff, entry.key, length >> 8, length & 0xff, //
        ...payload,
        0xff, 0xda, 0x00, 0x02, 0x01, //
        0xff, 0xd9,
      ]);
      expect(img.decodeImage(bytes), isNull, reason: 'marker ${entry.key}');
      expect(jpegMaxEdge(bytes), [
        0xff, 0xd8, //
        0xff, 0xda, 0x00, 0x02, 0x01, //
        0xff, 0xd9,
      ]);
      expect(
        String.fromCharCodes(jpegMaxEdge(bytes)!).contains('GPSLAT'),
        isFalse,
      );
    }
  });

  test('a broken marker is not sent', () {
    final gps = [...'GPSLAT'.codeUnits];
    final truncated = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe1, 0x00]);
    expect(img.decodeImage(truncated), isNull);
    expect(jpegMaxEdge(truncated), isNull);

    final cases = <Uint8List>[
      // Length shorter than a segment header, with the place still in the file.
      Uint8List.fromList([0xff, 0xd8, 0xff, 0xe1, 0x00, 0x01, ...gps]),
      // APP2 length runs past the end of the file.
      Uint8List.fromList([
        0xff, 0xd8, //
        0xff, 0xe2, 0x00, 0x20, //
        ...gps,
      ]),
      // A stray byte before the next marker.
      Uint8List.fromList([
        0xff, 0xd8, //
        0x00, //
        0xff, 0xe1, 0x00, 0x08, //
        ...gps,
        0xff, 0xd9,
      ]),
    ];
    for (final bytes in cases) {
      expect(img.decodeImage(bytes), isNull);
      expect(jpegMaxEdge(bytes), isNull);
      expect(String.fromCharCodes(bytes).contains('GPSLAT'), isTrue);
    }
  });

  test('a photo that cannot be read stops at the first end of image', () {
    final app0 = _jpegSegment(0xe0, [...'JFIF\x00'.codeUnits, 1, 1]);
    final dqt = _jpegSegment(0xdb, [0]);
    final dht = _jpegSegment(0xc4, [0]);
    final dri = _jpegSegment(0xdd, [0, 1]);
    final sof = _jpegSegment(0xc0, [8, 0, 1, 0, 1, 1, 0]);
    final sos = _jpegSegment(0xda, const []);
    final app1 = _jpegSegment(0xe1, [...'Exif\x00\x00GPSLAT'.codeUnits]);
    final app2 = _jpegSegment(0xe2, [...'MPF\x00GPSLAT'.codeUnits]);
    final app13 = _jpegSegment(0xed, [...'Photoshop 3.0\x00GPSLAT'.codeUnits]);
    final comment = _jpegSegment(0xfe, [...'GPSLAT'.codeUnits]);
    // No baseline frame before the first scan, so the decoder leaves the
    // bytes alone and the fallback has to strip them.
    final bytes = Uint8List.fromList([
      0xff, 0xd8, //
      ...app0,
      ...app2,
      ...dqt,
      ...dht,
      ...dri,
      ...sos,
      0x11, 0xff, 0x00, 0x22, //
      ...app1,
      ...app13,
      ...comment,
      0xff, 0xd9, //
      0x00, //
      0xff, 0xd8, //
      ...app2,
      ...app1,
      ...sof,
      ...sos,
      0x44, //
      0xff, 0xd9,
    ]);
    expect(img.decodeImage(bytes), isNull);
    final named = jpegMaxEdge(bytes)!;
    expect(named, [
      0xff, 0xd8, //
      ...app0,
      ...dqt,
      ...dht,
      ...dri,
      ...sos,
      0x11, 0xff, 0x00, 0x22, //
      0xff, 0xd9,
    ]);
    expect(named[named.length - 2], 0xff);
    expect(named.last, 0xd9);
    expect(String.fromCharCodes(named).contains('GPSLAT'), isFalse);
    expect(String.fromCharCodes(named).contains('JFIF'), isTrue);
    expect(named.contains(0x44), isFalse);
  });

  test('Slovak book order keeps č and ch in place', () {
    expect(compareTitle('cibula', 'červená', 'sk'), lessThan(0));
    expect(compareTitle('huba', 'chránená', 'sk'), lessThan(0));
    expect(compareTitle('chránená', 'iba', 'sk'), lessThan(0));
    expect(compareTitle('hríb', 'muchotrávka', 'sk'), lessThan(0));
  });

  test('Slovak counts use huba, huby, and húb', () {
    const copy = Copy('sk');
    expect(copy.count(1), '1 huba');
    expect(copy.count(3), '3 huby');
    expect(copy.count(5), '5 húb');
  });
}

List<int> _jpegSegment(int marker, List<int> payload) {
  final length = payload.length + 2;
  return [0xff, marker, length >> 8, length & 0xff, ...payload];
}

class _FunctionsException extends FirebaseFunctionsException {
  _FunctionsException(String code) : super(message: code, code: code);
}
