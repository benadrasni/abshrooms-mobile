import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/catalog_pack.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/offline/offline_book.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('mushroom-catalog');
    OfflineBook.resetForTest();
    OfflineBook.rootOverride = directory.path;
  });

  tearDown(() {
    OfflineBook.resetForTest();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('a bad manifest path is refused', () {
    expect(
      () => parseCatalogManifest({
        'revision': 'abc',
        'speciesCount': 1,
        'bytes': 1,
        'languages': ['en'],
        'files': [
          'catalog/manifest.json',
          'catalog/species.json',
          'catalog/synonyms.json',
          'catalog/lists.json',
          'catalog/translations/en.json',
          'catalog/taxonomy/en.json',
          'catalog/../../secret',
        ],
      }),
      throwsFormatException,
    );
  });

  test('a stored pack is the book, in every language', () async {
    await _install(directory, description: 'A bolete.', slovak: 'Hríb.');
    OfflineBook.stored = true;

    final repo = CatalogRepository();
    await repo.load('en');
    expect(repo.error, isNull);
    expect(repo.data!.species.single.name, 'Boletus edulis');
    expect(repo.data!.species.single.hymenium, 'tubes');
    expect(repo.data!.species.single.synonymLines, ['Boletus solidus Sacc.']);
    expect(repo.data!.local['Boletus edulis']!.description, 'A bolete.');
    expect(repo.data!.taxonVernacular('Boletaceae'), 'boletes');
    expect(await repo.refresh(), isTrue);
    expect(repo.data!.local['Boletus edulis']!.description, 'A bolete.');

    await repo.load('sk');
    expect(repo.data!.local['Boletus edulis']!.description, 'Hríb.');
    expect(repo.data!.english['Boletus edulis']!.description, 'A bolete.');

    await repo.load('de');
    expect(
      repo.data!.textFor(repo.data!.species.single).description,
      'A bolete.',
    );

    await repo.loadCuratedLists();
    expect(repo.curatedLists.documents.single.id, 'year');
    expect(repo.curatedLists.failed, isFalse);
  });

  test(
    'the download writes the snapshot and a later revision replaces it',
    () async {
      var finished = false;
      await startOfflineDownload(
        request: const OfflineRequest(
          title: 'Everything',
          species: 1,
          pending: ['photos/a.webp'],
          alreadyDone: 0,
          totalFiles: 1,
          markStored: true,
          update: false,
          includeCatalog: true,
        ),
        wifi: () async => true,
        fetch: _fetch(description: 'A bolete.'),
        onProgress: (_, _) {},
        onFinished: () => finished = true,
        onFailed: () => fail('download failed'),
      );
      await OfflineBook.idle;

      expect(finished, isTrue);
      expect(OfflineBook.stored, isTrue);
      expect(OfflineBook.catalogRevision, 'rev-a');
      expect(OfflineBook.saved, {'photos/a.webp'});
      final catalog = readPackedCatalog(
        directory.path,
        'en',
        revision: 'rev-a',
      );
      expect(catalog!.local['Boletus edulis']!.description, 'A bolete.');

      await startOfflineDownload(
        request: const OfflineRequest(
          title: 'Update',
          species: 1,
          pending: [],
          alreadyDone: 1,
          totalFiles: 1,
          markStored: true,
          update: true,
          includeCatalog: true,
          catalogBytes: 20,
        ),
        wifi: () async => true,
        fetch: _fetch(description: 'A newer bolete.', revision: 'rev-b'),
        onProgress: (_, _) {},
        onFinished: () {},
        onFailed: () => fail('update failed'),
      );
      await OfflineBook.idle;
      expect(OfflineBook.catalogRevision, 'rev-b');
      expect(
        readPackedCatalog(
          directory.path,
          'en',
          revision: 'rev-b',
        )!.local['Boletus edulis']!.description,
        'A newer bolete.',
      );
      expect(
        readPackedCatalog(directory.path, 'en', revision: 'rev-a'),
        isNull,
      );
    },
  );

  test('a missing manifest still keeps the pictures', () async {
    var finished = false;
    await startOfflineDownload(
      request: const OfflineRequest(
        title: 'Everything',
        species: 1,
        pending: ['photos/a.webp'],
        alreadyDone: 0,
        totalFiles: 1,
        markStored: true,
        update: false,
        includeCatalog: true,
      ),
      wifi: () async => true,
      fetch: (path) async => path == catalogManifestPath ? null : [1],
      onProgress: (_, _) {},
      onFinished: () => finished = true,
      onFailed: () => fail('download failed'),
    );
    await OfflineBook.idle;
    expect(finished, isTrue);
    expect(OfflineBook.stored, isTrue);
    expect(OfflineBook.catalogRevision, isEmpty);
    expect(OfflineBook.saved, {'photos/a.webp'});
  });

  test('a broken snapshot does not replace the book already stored', () async {
    await _install(directory, description: 'A bolete.');
    OfflineBook.stored = true;
    var failed = false;
    await startOfflineDownload(
      request: const OfflineRequest(
        title: 'Update',
        species: 0,
        pending: [],
        alreadyDone: 1,
        totalFiles: 1,
        markStored: true,
        update: true,
        includeCatalog: true,
      ),
      wifi: () async => true,
      fetch: (path) async {
        if (path == 'catalog/species.json') return utf8.encode('{}');
        return _fetch(description: 'Broken.', revision: 'rev-b')(path);
      },
      onProgress: (_, _) {},
      onFinished: () => fail('finished'),
      onFailed: () => failed = true,
    );
    await OfflineBook.idle;
    expect(failed, isTrue);
    expect(OfflineBook.catalogRevision, 'rev-a');
    expect(
      readPackedCatalog(
        directory.path,
        'en',
        revision: 'rev-a',
      )!.local['Boletus edulis']!.description,
      'A bolete.',
    );
  });

  test('a newer remote revision marks the stored book stale', () async {
    await _install(directory, description: 'A bolete.');
    OfflineBook.stored = true;
    OfflineBook.readManifest = () async => parseCatalogManifest({
      'revision': 'rev-b',
      'speciesCount': 1,
      'bytes': 40,
      'languages': ['en'],
      'files': _files,
    });
    expect(OfflineBook.catalogStale, isFalse);
    await OfflineBook.watchRemoteCatalog();
    expect(OfflineBook.catalogStale, isTrue);
    expect(OfflineBook.remoteBytes, 40);
    await OfflineBook.watchRemoteCatalog();
    expect(OfflineBook.remoteRevision, 'rev-b');
  });
}

const _files = [
  'catalog/manifest.json',
  'catalog/species.json',
  'catalog/synonyms.json',
  'catalog/lists.json',
  'catalog/translations/en.json',
  'catalog/translations/sk.json',
  'catalog/taxonomy/en.json',
];

Future<List<int>?> Function(String path) _fetch({
  required String description,
  String revision = 'rev-a',
  String slovak = '',
}) {
  final files = _bodies(
    description: description,
    revision: revision,
    slovak: slovak,
  );
  return (path) async => files[path] ?? [1];
}

Map<String, List<int>> _bodies({
  required String description,
  required String revision,
  required String slovak,
}) {
  final species = {
    'Boletus edulis': {
      'id': 1,
      'name': 'Boletus edulis',
      'hymenium': 'tubes',
      'taxonomy': {
        'family': 'Boletaceae',
        'genus': 'Boletus',
        'order': 'Boletales',
      },
    },
  };
  return {
    catalogManifestPath: utf8.encode(
      jsonEncode({
        'revision': revision,
        'speciesCount': 1,
        'bytes': 20,
        'languages': ['en', 'sk'],
        'files': _files,
      }),
    ),
    'catalog/species.json': utf8.encode(jsonEncode(species)),
    'catalog/synonyms.json': utf8.encode(
      jsonEncode({
        'Boletus edulis': {
          'homotypic': [
            {'name': 'Boletus solidus', 'author': 'Sacc.'},
          ],
        },
      }),
    ),
    'catalog/lists.json': utf8.encode(
      jsonEncode([
        {
          'id': 'year',
          'type': 'year',
          'titles': {'en': 'Year'},
        },
      ]),
    ),
    'catalog/translations/en.json': utf8.encode(
      jsonEncode({
        'Boletus edulis': {'description': description},
      }),
    ),
    'catalog/translations/sk.json': utf8.encode(
      jsonEncode({
        'Boletus edulis': {'description': slovak},
      }),
    ),
    'catalog/taxonomy/en.json': utf8.encode(
      jsonEncode({
        'Boletaceae': {'vernacular': 'boletes'},
      }),
    ),
  };
}

Future<void> _install(
  Directory directory, {
  required String description,
  String slovak = '',
}) async {
  final files = _bodies(
    description: description,
    revision: 'rev-a',
    slovak: slovak,
  );
  for (final entry in files.entries) {
    final file = File('${directory.path}/offline/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(entry.value);
  }
  await OfflineBook.rememberCatalog('rev-a', 20);
}
