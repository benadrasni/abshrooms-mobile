import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a torn notebook is set aside and the next write replaces it whole',
    () async {
      final dir = await Directory.systemTemp.createTemp('notebook');
      addTearDown(() async {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/notebook.json');
      file.writeAsStringSync('{"torn"');
      final notebook = Notebook()..useStorage(dir);
      addTearDown(notebook.stopFavorites);
      await notebook.load();
      expect(notebook.finds, isEmpty);
      expect(file.existsSync(), isFalse);
      final kept = dir.listSync().whereType<File>().where(
        (item) => item.path.contains('notebook.json.corrupt'),
      );
      expect(kept, hasLength(1));
      expect(kept.single.readAsStringSync(), '{"torn"');

      await notebook.addFind(
        const FindRecord(id: 'one', millis: 5, latin: 'Boletus edulis'),
      );
      expect(File('${dir.path}/notebook.json.tmp').existsSync(), isFalse);
      final stored = json.decode(file.readAsStringSync());
      expect(stored, isA<List>());
      expect((stored as List).single['id'], 'one');

      final again = Notebook()..useStorage(dir);
      addTearDown(again.stopFavorites);
      await again.load();
      expect(again.finds.single.latin, 'Boletus edulis');
    },
  );

  test('a notebook that is not a list is set aside', () async {
    final dir = await Directory.systemTemp.createTemp('notebook-object');
    addTearDown(() async {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    File('${dir.path}/notebook.json').writeAsStringSync('{"finds": []}');
    final notebook = Notebook()..useStorage(dir);
    addTearDown(notebook.stopFavorites);
    await notebook.load();
    expect(notebook.finds, isEmpty);
    expect(File('${dir.path}/notebook.json').existsSync(), isFalse);
    expect(
      dir.listSync().where(
        (item) => item.path.contains('notebook.json.corrupt'),
      ),
      isNotEmpty,
    );
  });

  test('valid zero latitude or longitude stays, and 0, 0 is dropped', () {
    final greenwich = FindRecord.fromJson({
      'id': 'g',
      'millis': 1,
      'latitude': 51.4779,
      'longitude': 0.0,
    });
    expect(greenwich.latitude, 51.4779);
    expect(greenwich.longitude, 0.0);

    final equator = FindRecord.fromJson({
      'id': 'e',
      'millis': 2,
      'latitude': 0.0,
      'longitude': -78.4678,
    });
    expect(equator.latitude, 0.0);
    expect(equator.longitude, -78.4678);

    final nowhere = FindRecord.fromJson({
      'id': 'n',
      'millis': 3,
      'latitude': 0.0,
      'longitude': 0.0,
    });
    expect(nowhere.latitude, isNull);
    expect(nowhere.longitude, isNull);
  });
}
