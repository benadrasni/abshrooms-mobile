import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/favorites.dart';
import 'package:whats_that_mushroom/data/notebook.dart';

void main() {
  test('a favorites snapshot is the Latin names whose value is 1', () {
    expect(
      favoriteNamesFrom([
        (id: 'Amanita muscaria', value: 1),
        (id: ' Boletus edulis ', value: 1),
        (id: 'Gone', value: 0),
        (id: 'Also gone', value: null),
        (id: '', value: 1),
        (id: 'Bad/name', value: 1),
      ]),
      {'Amanita muscaria', 'Boletus edulis'},
    );
    expect(favoriteNamesFrom(const []), isEmpty);
  });

  test('phone favorites join the account and are not shown twice', () {
    expect(
      favoriteNamesToMove(
        {'Amanita muscaria', 'Boletus edulis', ' Bad/name '},
        {'Amanita muscaria'},
      ),
      {'Boletus edulis'},
    );
    expect(favoriteNamesShown({'Amanita muscaria'}, {'Boletus edulis'}), {
      'Amanita muscaria',
      'Boletus edulis',
    });
  });

  test('a signed-in favorite is written for that account', () async {
    final notebook = Notebook()..favoriteAccount = 'ada';
    final writes = <String>[];
    notebook.favoriteWrite = (uid, latin, on) async {
      writes.add('$uid|$latin|$on');
    };

    await notebook.setFavorite(' Amanita muscaria ', true);
    expect(notebook.favorites, {'Amanita muscaria'});
    expect(notebook.isFavorite('Amanita muscaria'), isTrue);
    expect(notebook.isFavorite(' Amanita muscaria '), isTrue);

    await notebook.setFavorite('Amanita muscaria', false);
    expect(notebook.favorites, isEmpty);
    expect(writes, ['ada|Amanita muscaria|true', 'ada|Amanita muscaria|false']);

    // A later remote snapshot is not shadowed by completed local writes.
    notebook.applyFavoriteSnapshot({'Amanita muscaria'});
    expect(notebook.favorites, {'Amanita muscaria'});
    await notebook.setFavorite('Amanita muscaria', true);
    notebook.applyFavoriteSnapshot(const {});
    expect(notebook.favorites, isEmpty);
  });

  test('a failed write puts the list back', () async {
    final notebook = Notebook()..favoriteAccount = 'ada';
    notebook.favoriteWrite = (uid, latin, on) async {
      throw StateError('denied');
    };
    await expectLater(
      notebook.setFavorite('Amanita muscaria', true),
      throwsStateError,
    );
    expect(notebook.favorites, isEmpty);
  });

  test('a guest favorite is not stored', () async {
    final notebook = Notebook();
    await expectLater(
      notebook.setFavorite('Amanita muscaria', true),
      throwsStateError,
    );
    expect(notebook.favorites, isEmpty);
  });

  test('signing out clears the list and leaves the phone rows to move', () {
    final notebook = Notebook()
      ..favoriteAccount = 'ada'
      ..phoneFavorites = {'Boletus edulis'}
      ..favorites = {'Amanita muscaria'};
    notebook.favoriteAccount = null;
    notebook.debugFavoriteAccount();
    expect(notebook.favorites, isEmpty);
    expect(notebook.phoneFavorites, {'Boletus edulis'});
  });

  test('a phone list is written onto the account', () async {
    final notebook = Notebook()..favoriteAccount = 'ada';
    final writes = <String>[];
    notebook.favoriteWrite = (uid, latin, on) async {
      writes.add('$uid|$latin|$on');
    };
    notebook.phoneFavorites = {'Boletus edulis', 'Amanita muscaria'};
    notebook.applyFavoriteSnapshot({'Amanita muscaria'});
    await Future<void>.value();
    expect(notebook.favorites, {'Amanita muscaria', 'Boletus edulis'});
    expect(writes, ['ada|Boletus edulis|true']);

    notebook.applyFavoriteSnapshot({'Amanita muscaria', 'Boletus edulis'});
    expect(notebook.phoneFavorites, isEmpty);
    expect(notebook.favorites, {'Amanita muscaria', 'Boletus edulis'});
  });
}
