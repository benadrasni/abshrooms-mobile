import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/adopt.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';

Species _species(String name, {List<Synonym> synonyms = const []}) {
  return Species(
    id: 1,
    name: name,
    author: '',
    family: '',
    genus: '',
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
    illustrationUrl: '',
    photoUrls: const [],
    synonyms: synonyms,
  );
}

Catalog _catalog(List<Species> species) {
  return Catalog(
    language: 'en',
    species: species,
    local: const {},
    english: const {},
    taxa: const {},
  );
}

void main() {
  test('an outside find takes the catalog name', () {
    final catalog = _catalog([
      _species(
        'Agaricus augustus',
        synonyms: const [Synonym(name: 'Psalliota augusta', author: 'Gillet')],
      ),
    ]);
    const outside = FindRecord(
      id: 'out',
      millis: 5,
      outsideName: 'Psalliota augusta',
      spoken: 'the prince',
      photoPath: '/tmp/out.jpg',
      confirmed: true,
      probability: 0.8,
    );
    const other = FindRecord(
      id: 'stay',
      millis: 4,
      outsideName: 'Agaricus campestris',
      confirmed: true,
    );
    const booked = FindRecord(
      id: 'book',
      millis: 3,
      latin: 'Agaricus augustus',
      spoken: 'kept',
      confirmed: true,
    );

    final next = adoptBookFinds([outside, other, booked], catalog);

    expect(next[0].latin, 'Agaricus augustus');
    expect(next[0].outsideName, isNull);
    expect(next[0].spoken, isNull);
    expect(next[0].confirmed, isTrue);
    expect(next[0].photoPath, '/tmp/out.jpg');
    expect(next[0].probability, 0.8);
    expect(identical(next[1], other), isTrue);
    expect(identical(next[2], booked), isTrue);
  });

  test('an accepted name wins over another species synonym', () {
    final catalog = _catalog([
      _species('Boletus edulis'),
      _species(
        'Boletus pinophilus',
        synonyms: const [Synonym(name: 'Boletus edulis', author: '')],
      ),
    ]);
    const find = FindRecord(
      id: '1',
      millis: 1,
      outsideName: 'Boletus edulis',
      confirmed: true,
    );
    final next = adoptBookFinds(const [find], catalog);
    expect(next.single.latin, 'Boletus edulis');
  });

  test('a synonym shared by two species stays outside the book', () {
    final catalog = _catalog([
      _species(
        'Collybia personata',
        synonyms: const [Synonym(name: 'Lepista saeva', author: '')],
      ),
      _species(
        'Lepista nuda',
        synonyms: const [Synonym(name: 'Lepista saeva', author: '')],
      ),
    ]);
    const find = FindRecord(id: '1', millis: 1, outsideName: 'Lepista saeva');
    expect(
      identical(adoptBookFinds(const [find], catalog), const [find]),
      isTrue,
    );
  });

  test('an unconfirmed find keeps that state', () {
    final catalog = _catalog([_species('Agaricus augustus')]);
    const find = FindRecord(
      id: '1',
      millis: 1,
      outsideName: 'agaricus augustus',
      share: FindShare.none,
    );
    final next = adoptBookFinds(const [find], catalog).single;
    expect(next.latin, 'Agaricus augustus');
    expect(next.confirmed, isFalse);
    expect(next.share, FindShare.none);
  });
}
