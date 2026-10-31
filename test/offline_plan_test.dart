import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/offline/offline_plan.dart';

Species _species({
  String family = '',
  String illustrationUrl = '',
  List<String> photoUrls = const [],
}) {
  return Species(
    id: 1,
    name: 'Boletus edulis',
    author: '',
    family: family,
    genus: 'Boletus',
    order: '',
    taxonomy: const {},
    edibility: '',
    hymenium: '',
    where: const [],
    colors: const [],
    fruitingFrom: null,
    fruitingTo: null,
    capFrom: null,
    capTo: null,
    stipeHeightFrom: null,
    stipeHeightTo: null,
    stipeThickFrom: null,
    stipeThickTo: null,
    illustrationUrl: illustrationUrl,
    photoUrls: photoUrls,
    synonyms: const [],
  );
}

void main() {
  test('the book keeps both plate sizes, photos, and one family icon', () {
    final species = _species(
      family: 'Boletaceae',
      illustrationUrl: 'plates/Boletus edulis@1600.webp',
      photoUrls: [
        'photos/a.webp',
        'photos/a.webp',
        '${storageRoot}photos/b.webp',
      ],
    );
    expect(speciesMedia(species), [
      'photos/a.webp',
      'photos/b.webp',
      'plates/Boletus edulis@1600.webp',
      'plates/Boletus edulis@400.webp',
    ]);
    expect(bookMedia([species]), [
      'families/Boletaceae.webp',
      'photos/a.webp',
      'photos/b.webp',
      'plates/Boletus edulis@1600.webp',
      'plates/Boletus edulis@400.webp',
    ]);
    expect(offlineOptional('families/Boletaceae.webp'), isTrue);
    expect(offlineOptional('photos/a.webp'), isFalse);
  });

  test('storage paths stay inside this bucket', () {
    expect(offlineRelative('${storageRoot}photos/a.webp'), 'photos/a.webp');
    expect(offlineRelative('https://evil.example/photos/a.webp'), isNull);
    expect(offlineRelative('../secret'), isNull);
    expect(offlineRelative('photos/../../secret'), isNull);
    expect(offlineRelative(''), isNull);
  });

  test('a saved book still notices a new picture', () {
    final species = _species(
      family: 'Boletaceae',
      illustrationUrl: 'plates/Boletus edulis@1600.webp',
      photoUrls: const ['photos/a.webp'],
    );
    final saved = speciesMedia(species).toSet();
    final gap = offlineViewOf(
      species: [species],
      canDownload: true,
      stored: true,
      saved: saved,
      skipped: const {},
    );
    expect(gap.pending, ['families/Boletaceae.webp']);
    expect(gap.missingSpecies, 1);
    expect(gap.hasUpdate, isTrue);

    final done = offlineViewOf(
      species: [species],
      canDownload: true,
      stored: true,
      saved: bookMedia([species]).toSet(),
      skipped: const {},
    );
    expect(done.pending, isEmpty);
    expect(done.hasUpdate, isFalse);

    final words = offlineViewOf(
      species: [species],
      canDownload: true,
      stored: true,
      saved: bookMedia([species]).toSet(),
      skipped: const {},
      catalogStale: true,
      catalogBytes: 8000000,
    );
    expect(words.pending, isEmpty);
    expect(words.hasUpdate, isTrue);
    expect(offlinePackUpdateBytes(words), 8000000);
  });

  test('sizes follow the plants rounding', () {
    expect(OfflineAmount.ofSpecies(0).amount, '0');
    expect(OfflineAmount.ofSpecies(2).amount, '1.4');
    expect(OfflineAmount.ofSpecies(62).amount, '40');
    expect(OfflineAmount.ofSpecies(62).gigabytes, isFalse);
    expect(OfflineAmount.ofSpecies(62).barMb, 40);
    expect(OfflineAmount.ofSpecies(2000).gigabytes, isTrue);
    expect(OfflineAmount.ofSpecies(2000).amount, '1.4');
    expect(OfflineAmount.ofBytes(400000).amount, '0.4');
    expect(OfflineAmount.ofBytes(2300000).amount, '2');
    expect(offlineUpdateBytes(1), 700000);
  });

  test('the person row names the whole book and drops regions', () {
    const english = Copy('en');
    const slovak = Copy('sk');
    expect(english.fieldGuideAddOffline, 'The book offline');
    expect(slovak.fieldGuideAddOffline, 'Atlas offline');
    expect(english.offlineIntro.contains('region'), isFalse);
    expect(english.offlineIntro.contains('map'), isFalse);
    expect(slovak.offlineIntro.contains('oblast'), isFalse);
    expect(slovak.offlineIntro.contains('map'), isFalse);
    expect(
      offlineMenuLine(
        english,
        canDownload: false,
        stored: false,
        species: null,
        updateSpecies: 0,
      ),
      'With Field Guide',
    );
    expect(
      offlineMenuLine(
        english,
        canDownload: true,
        stored: false,
        species: 62,
        updateSpecies: 0,
      ),
      'The whole book · about 40 MB',
    );
    expect(
      offlineMenuLine(
        english,
        canDownload: true,
        stored: true,
        species: 62,
        updateSpecies: 0,
      ),
      'On this phone · about 40 MB',
    );
    expect(
      offlineMenuLine(
        english,
        canDownload: true,
        stored: true,
        species: 62,
        updateSpecies: 1,
      ),
      'On this phone · about 40 MB · Update about 0.7 MB',
    );
    expect(
      offlineMenuLine(
        english,
        canDownload: true,
        stored: true,
        species: 62,
        updateSpecies: 0,
        updateBytes: 8000000,
      ),
      'On this phone · about 40 MB · Update about 8 MB',
    );
    expect(slovak.offlineTitle, 'Režim offline');
    expect(
      offlineMenuLine(
        slovak,
        canDownload: false,
        stored: false,
        species: 62,
        updateSpecies: 0,
      ),
      'S Terénnym sprievodcom · asi 40 MB',
    );
  });
}
