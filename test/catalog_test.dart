import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:whats_that_mushroom/camera/plant_id.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/key_filter.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/new_book.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/data/search.dart';
import 'package:whats_that_mushroom/data/text.dart';

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
    key: {
      'Boletus edulis': const KeyFacts(
        hymenium: 'tubes',
        where: ['ground'],
        color: ['brown'],
      ),
      'Amanita muscaria': const KeyFacts(
        hymenium: 'gills',
        where: ['ground'],
        color: ['red', 'yellow'],
      ),
    },
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

  test('the bundled key has 59 species and Boletus edulis has tubes', () async {
    final key = await loadKeyAsset();
    expect(key.length, 59);
    expect(key['Boletus edulis']?.hymenium, 'tubes');
    expect(key['Boletus edulis']?.where, ['ground']);
    expect(key['Boletus edulis']?.added, '2026-10-22');
    expect(key['Amanita muscaria']?.color, ['red', 'yellow']);
    expect(key.values.where((row) => row.hymenium.isEmpty), isEmpty);
    expect(key.values.where((row) => addedDate(row.added) == null), isEmpty);
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
    final resized = img.decodeJpg(jpegMaxEdge(bytes, edge: 1280))!;
    expect(resized.width, 1280);
    expect(resized.height, 640);
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

class _FunctionsException extends FirebaseFunctionsException {
  _FunctionsException(String code) : super(message: code, code: code);
}
