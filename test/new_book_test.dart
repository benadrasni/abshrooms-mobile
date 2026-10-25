import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/book/book_page.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/new_book.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/find/find_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

Species _species(int id, String added) {
  return Species(
    id: id,
    name: 'Species $id',
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
    synonyms: const [],
    added: added,
  );
}

void main() {
  test('new in the book keeps newest days and higher ids first', () {
    final days = newInBook(
      [
        _species(1, '2026-10-22'),
        _species(4, '2026-10-24'),
        _species(2, '2026-10-24'),
        _species(3, ''),
        _species(9, 'not-a-date'),
      ],
      minCount: 1,
      maxCount: 25,
    );
    expect(days.map((day) => day.dateKey), ['2026-10-24', '2026-10-22']);
    expect(days.first.species.map((item) => item.id), [4, 2]);
    expect(newBookCount(days), 3);
  });

  test('a day is shortened only to stay inside the band', () {
    final newest = [
      for (var id = 1; id <= 30; id++) _species(id, '2026-10-24'),
    ];
    final days = newInBook(newest, minCount: 15, maxCount: 25);
    expect(days, hasLength(1));
    expect(days.single.species, hasLength(25));
    expect(days.single.species.first.id, 30);
    expect(days.single.species.last.id, 6);
  });

  test('later days stop once the minimum is already met', () {
    final species = [
      for (var id = 1; id <= 20; id++) _species(id, '2026-10-24'),
      for (var id = 21; id <= 30; id++) _species(id, '2026-10-23'),
    ];
    final days = newInBook(species, minCount: 15, maxCount: 25);
    expect(days.map((day) => day.dateKey), ['2026-10-24']);
    expect(newBookCount(days), 20);
  });

  test('today and yesterday use the calendar day', () {
    final now = DateTime(2026, 10, 24, 15);
    expect(
      newDayWord(
        DateTime.utc(2026, 10, 24),
        now,
        today: 'Today',
        yesterday: 'Yesterday',
      ),
      'Today',
    );
    expect(
      newDayWord(
        DateTime.utc(2026, 10, 23),
        now,
        today: 'Today',
        yesterday: 'Yesterday',
      ),
      'Yesterday',
    );
    expect(
      newDayWord(
        DateTime.utc(2026, 10, 22),
        now,
        today: 'Today',
        yesterday: 'Yesterday',
      ),
      isNull,
    );
  });

  testWidgets('Find hides Seen until a sighting exists', (tester) async {
    addTearDown(() => BookLists.request.value = 0);
    final catalog = buildCatalog(
      language: 'en',
      speciesDocs: [
        Doc('Boletus edulis', {'name': 'Boletus edulis', 'id': 4}),
      ],
      local: const {},
      english: const {
        'Boletus edulis': {'label': 'penny bun'},
      },
      synonyms: const {},
      taxa: const {},
      key: const {
        'Boletus edulis': KeyFacts(
          hymenium: 'tubes',
          where: ['ground'],
          color: ['brown'],
          added: '2026-10-24',
        ),
      },
    );
    final repository = CatalogRepository()
      ..data = catalog
      ..loading = false;
    final notebook = Notebook();
    Future<void> reload() async {}
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_harness(repository, notebook, reload, (_) {}));
    expect(find.text('Seen lately'), findsNothing);
    expect(find.text('List of mushrooms'), findsOneWidget);
    expect(find.text('New in the book'), findsOneWidget);
    expect(find.text('Favorite mushrooms'), findsNothing);

    notebook.finds = [
      FindRecord(
        id: 'one',
        millis: DateTime(2026, 10, 24, 9).millisecondsSinceEpoch,
        latin: 'Boletus edulis',
        confirmed: true,
      ),
    ];
    notebook.favorites = {'Boletus edulis'};
    notebook.notifyListeners();
    var tab = -1;
    await tester.pumpWidget(
      _harness(repository, notebook, reload, (index) => tab = index),
    );
    await tester.pump();
    expect(find.text('Seen lately'), findsOneWidget);
    expect(find.text('All finds'), findsOneWidget);
    expect(find.text('All lists'), findsOneWidget);
    expect(find.text('Boletus edulis'), findsWidgets);
    expect(find.text('Favorite mushrooms'), findsOneWidget);
    await tester.tap(find.text('All finds'));
    expect(tab, 2);
    await tester.tap(find.text('All lists'));
    expect(tab, 1);

    await tester.ensureVisible(find.text('New in the book'));
    await tester.tap(find.text('New in the book'));
    await tester.pumpAndSettle();
    expect(find.text('LIST OF MUSHROOMS'), findsOneWidget);
    expect(find.text('Boletus edulis'), findsWidgets);
    expect(
      find.textContaining('The last 1 mushroom added to the book'),
      findsOneWidget,
    );
    expect(find.textContaining("you've seen 1"), findsOneWidget);
  });
}

Widget _harness(
  CatalogRepository repository,
  Notebook notebook,
  Future<void> Function() reload,
  void Function(int index) selectTab,
) {
  return GuideScope(
    catalog: repository,
    notebook: notebook,
    settings: GuideSettings(),
    reload: reload,
    selectTab: selectTab,
    child: MaterialApp(
      theme: guideTheme(Brightness.light),
      locale: const Locale('en'),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: const Scaffold(body: FindPage()),
    ),
  );
}
