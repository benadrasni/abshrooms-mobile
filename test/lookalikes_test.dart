import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/species/lookalikes.dart';

void main() {
  test('a catalog name and a unique synonym link, and the rest stay text', () {
    final catalog = buildCatalog(
      language: 'en',
      speciesDocs: [
        Doc('Boletus edulis', {'name': 'Boletus edulis'}),
        Doc('Tylopilus felleus', {'name': 'Tylopilus felleus'}),
        Doc('Amanita citrina', {'name': 'Amanita citrina'}),
        Doc('Collybia personata', {'name': 'Collybia personata'}),
      ],
      local: const {},
      english: const {},
      synonyms: {
        'Collybia personata': {
          'heterotypic': [
            {'name': 'Lepista personata', 'author': '(Fr.) Cooke'},
          ],
        },
        'Boletus edulis': {
          'homotypic': [
            {'name': 'Boletus ambiguus', 'author': 'A'},
          ],
        },
        'Tylopilus felleus': {
          'heterotypic': [
            {'name': 'Boletus ambiguus', 'author': 'B'},
          ],
        },
      },
      taxa: const {},
    );
    final pieces = lookalikePieces(
      'Tylopilus felleus is bitter. Lepista personata is paler. '
          'Kept separate from Boletus edulis. Boletus betulicola is outside the book. '
          'Boletus ambiguus is shared. Amanita citrina var. alba keeps veil fragments. '
          'Agaricus species have no volva. R. rhodoxanthus stays plain.',
      catalog,
      'Boletus edulis',
    );

    expect(piece(pieces, 'Tylopilus felleus')!.latin, 'Tylopilus felleus');
    expect(piece(pieces, 'Lepista personata')!.latin, 'Collybia personata');
    expect(piece(pieces, 'Amanita citrina')!.latin, 'Amanita citrina');
    expect(piece(pieces, 'Boletus edulis')!.latin, isNull);
    expect(piece(pieces, 'Boletus betulicola')!.latin, isNull);
    expect(piece(pieces, 'Boletus ambiguus')!.latin, isNull);
    expect(piece(pieces, 'Agaricus species')!.latin, isNull);
    expect(piece(pieces, 'R. rhodoxanthus'), isNull);
    expect(pieces.map((item) => item.text).join(), contains(' var. alba'));
    expect(pieces.map((item) => item.text).join(), contains('R. rhodoxanthus'));
    expect(
      [
        for (final item in pieces)
          if (item.latin != null) item.text,
      ],
      ['Tylopilus felleus', 'Lepista personata', 'Amanita citrina'],
    );
  });
}

LookalikePiece? piece(List<LookalikePiece> pieces, String text) {
  for (final item in pieces) {
    if (item.text == text) return item;
  }
  return null;
}
