import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/book/book_page.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/find/find_page.dart';
import 'package:whats_that_mushroom/lists/curated_list_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

const _catalogIds = {
  'Boletus edulis': 0,
  'Amanita muscaria': 1,
  'Cantharellus cibarius': 2,
  'Macrolepiota procera': 4,
  'Amanita phalloides': 5,
  'Morchella esculenta': 7,
  'Laetiporus sulphureus': 9,
  'Coprinus comatus': 12,
  'Gyromitra esculenta': 13,
  'Agaricus campestris': 16,
  'Lactarius deliciosus': 19,
  'Amanita virosa': 20,
  'Rubroboletus satanas': 21,
  'Cortinarius rubellus': 22,
  'Craterellus cornucopioides': 23,
  'Fistulina hepatica': 24,
  'Inosperma erubescens': 27,
  'Sarcodon imbricatus': 29,
  'Russula cyanoxantha': 30,
  'Galerina marginata': 32,
  'Paxillus involutus': 34,
  'Artomyces pyxidatus': 36,
  'Phallus impudicus': 41,
  'Fomes fomentarius': 42,
  'Auricularia auricula-judae': 43,
  'Tricholoma equestre': 47,
  'Calvatia gigantea': 52,
  'Collybia personata': 79,
};

Catalog _catalog({String photoFor = ''}) {
  return buildCatalog(
    language: 'en',
    speciesDocs: [
      for (final entry in _catalogIds.entries)
        Doc(entry.key, {
          'name': entry.key,
          'id': entry.value,
          if (entry.key == photoFor) 'photoUrls': ['covers/${entry.key}.webp'],
        }),
    ],
    local: const {},
    english: const {},
    synonyms: const {},
    taxa: const {},
    key: const {},
  );
}

List<CuratedListDoc> _seed() {
  final raw = jsonDecode(
    File('firebase/seed/curated_lists.sample.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final documents = raw['documents'] as List;
  return [
    for (final item in documents)
      CuratedListDoc.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
}

CuratedListDoc _doc(String id) {
  return _seed().firstWhere((list) => list.id == id);
}

List<String> _rows(CuratedListView view) {
  return [
    for (final entry in view.entries)
      '${entry.year ?? ''}|${entry.region ?? ''}|${entry.species.name}',
  ];
}

void main() {
  final now = DateTime(2026, 10, 24);

  test(
    'each list is limited to its language, and deadly is on every language',
    () {
      final lists = _seed();
      expect(selectCuratedLists(lists, 'de').map((list) => list.id).toList(), [
        'mushroom-of-the-year-de',
        'mushroom-of-the-year-at',
        'deadly-poisonous',
      ]);
      expect(selectCuratedLists(lists, 'nl').map((list) => list.id).toList(), [
        'mushroom-of-the-year-nl',
        'deadly-poisonous',
      ]);
      expect(selectCuratedLists(lists, 'lv').map((list) => list.id).toList(), [
        'mushroom-of-the-year-lv',
        'deadly-poisonous',
      ]);
      expect(selectCuratedLists(lists, 'hu').map((list) => list.id).toList(), [
        'mushroom-of-the-year-hu',
        'deadly-poisonous',
      ]);
      expect(selectCuratedLists(lists, 'en').map((list) => list.id).toList(), [
        'us-state-mushrooms',
        'deadly-poisonous',
      ]);
      expect(selectCuratedLists(lists, 'sk').map((list) => list.id).toList(), [
        'deadly-poisonous',
      ]);
      expect(
        localizedListText(_doc('mushroom-of-the-year-de').titles, 'de'),
        'Pilz des Jahres',
      );
      expect(
        localizedListText(_doc('mushroom-of-the-year-de').titles, 'sk'),
        'Mushroom of the Year — Germany',
      );
    },
  );

  test(
    'the seed resolves in year, region, and stored order and skips the rest',
    () {
      final catalog = _catalog(photoFor: 'Amanita muscaria');
      final germany = presentCuratedList(
        _doc('mushroom-of-the-year-de'),
        catalog,
        'en',
        now: now,
      );
      expect(_rows(germany), [
        '2024||Coprinus comatus',
        '2022||Amanita muscaria',
        '2021||Tricholoma equestre',
        '2020||Phallus impudicus',
        '2019||Amanita phalloides',
        '2018||Agaricus campestris',
        '2017||Auricularia auricula-judae',
        '2016||Collybia personata',
        '2015||Artomyces pyxidatus',
        '1999||Rubroboletus satanas',
        '1997||Russula cyanoxantha',
        '1996||Sarcodon imbricatus',
        '1995||Fomes fomentarius',
      ]);
      expect(germany.coverPhotoUrl, mediaUrl('covers/Amanita muscaria.webp'));
      expect(germany.parameter, 'Germany');
      expect(sourceHost(germany.sourceUrl), 'dgfm-ev.de');

      final austria = presentCuratedList(
        _doc('mushroom-of-the-year-at'),
        catalog,
        'de',
        now: now,
      );
      expect(austria.entries, isEmpty);
      expect(austria.title, isNotEmpty);

      expect(
        _rows(
          presentCuratedList(
            _doc('us-state-mushrooms'),
            catalog,
            'en',
            now: now,
          ),
        ),
        ['|Minnesota|Morchella esculenta', '|Utah|Boletus edulis'],
      );
      expect(
        _rows(
          presentCuratedList(_doc('deadly-poisonous'), catalog, 'sk', now: now),
        ),
        [
          '||Amanita phalloides',
          '||Amanita virosa',
          '||Galerina marginata',
          '||Cortinarius rubellus',
          '||Gyromitra esculenta',
          '||Inosperma erubescens',
          '||Paxillus involutus',
        ],
      );
      expect(
        _rows(
          presentCuratedList(
            _doc('mushroom-of-the-year-nl'),
            catalog,
            'en',
            now: now,
          ),
        ),
        [
          '2022||Amanita muscaria',
          '2017||Fistulina hepatica',
          '2015||Boletus edulis',
          '2013||Cantharellus cibarius',
        ],
      );
    },
  );

  test('a Latin name wins, a bare id still resolves, and both years stay', () {
    final catalog = _catalog();
    final doc = CuratedListDoc.fromJson({
      'id': 'mixed',
      'type': 'year',
      'locales': ['en'],
      'titles': {'en': 'Mixed'},
      'entries': [
        {'name': 'boletus edulis', 'speciesId': 5, 'year': 2001},
        {'speciesId': 5, 'year': 2001},
        {'name': 'Boletus edulis', 'year': 2010},
        {'name': 'Not in the guide', 'year': 2011},
        {'name': 'Amanita muscaria', 'state': 'Oregon'},
        {'year': 1990},
      ],
    });
    final view = presentCuratedList(doc, catalog, 'en', now: now);
    expect(_rows(view), [
      '2010||Boletus edulis',
      '2001||Boletus edulis',
      '2001||Amanita phalloides',
      '|Oregon|Amanita muscaria',
    ]);
    expect(view.entries[3].region, 'Oregon');
  });

  test('the cover resolves through the same name-then-id path as an entry', () {
    final catalog = _catalog(photoFor: 'Amanita phalloides');
    final view = presentCuratedList(
      CuratedListDoc.fromJson({
        'titles': {'en': 'Cover'},
        'coverSpeciesId': 5,
        'entries': [
          {'name': 'Boletus edulis'},
        ],
      }),
      catalog,
      'en',
    );
    expect(view.coverPhotoUrl, mediaUrl('covers/Amanita phalloides.webp'));
  });

  test('region names sort A–Z and a species list keeps stored order', () {
    final catalog = _catalog();
    final regions = presentCuratedList(
      CuratedListDoc.fromJson({
        'type': 'region',
        'titles': {'en': 'States'},
        'entries': [
          {'name': 'Boletus edulis', 'region': 'Utah'},
          {'name': 'Amanita muscaria'},
          {'name': 'Morchella esculenta', 'region': 'Minnesota'},
        ],
      }),
      catalog,
      'en',
    );
    expect(_rows(regions), [
      '|Minnesota|Morchella esculenta',
      '|Utah|Boletus edulis',
      '||Amanita muscaria',
    ]);
    final species = presentCuratedList(
      CuratedListDoc.fromJson({
        'type': 'other',
        'entries': [
          {'name': 'Fomes fomentarius'},
          {'name': 'Boletus edulis'},
          {'name': 'Missing'},
        ],
      }),
      catalog,
      'en',
    );
    expect(species.type, CuratedListType.species);
    expect(_rows(species), ['||Fomes fomentarius', '||Boletus edulis']);
  });

  test('permission denied is a failed read', () async {
    final denied = await fetchCuratedLists(
      read: () async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      },
    );
    expect(denied.documents, isEmpty);
    expect(denied.failed, isTrue);
  });

  test('a missing Firebase app is an empty read, not a failure', () async {
    expect(Firebase.apps, isEmpty);
    final snapshot = await fetchCuratedLists();
    expect(snapshot.documents, isEmpty);
    expect(snapshot.failed, isFalse);
  });

  testWidgets('the list screen shows years and the empty state', (
    tester,
  ) async {
    final catalog = _catalog();
    final germany = presentCuratedList(
      _doc('mushroom-of-the-year-de'),
      catalog,
      'en',
      now: now,
    );
    final opened = <String>[];
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: guideTheme(Brightness.light),
        home: CuratedListPage(
          list: germany,
          backLabel: 'Find',
          onOpenSpecies: (_, latin) => opened.add(latin),
        ),
      ),
    );
    expect(find.text('Mushroom of the Year — Germany'), findsOneWidget);
    expect(find.textContaining('13 mushrooms'), findsOneWidget);
    expect(find.text('2016'), findsOneWidget);
    expect(find.text('Collybia personata'), findsOneWidget);
    expect(find.text('dgfm-ev.de ↗'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('Coprinus comatus'), findsOneWidget);
    expect(find.text('2027'), findsNothing);
    expect(find.text('Lactarius lignyotus'), findsNothing);

    await tester.tap(find.text('Coprinus comatus'));
    expect(opened, ['Coprinus comatus']);

    final austria = presentCuratedList(
      _doc('mushroom-of-the-year-at'),
      catalog,
      'en',
      now: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: guideTheme(Brightness.light),
        home: CuratedListPage(list: austria, backLabel: 'Find'),
      ),
    );
    expect(
      find.text('None of these species are in the guide yet.'),
      findsOneWidget,
    );
  });

  testWidgets('Find and Book share one lists snapshot', (tester) async {
    final catalog = _catalog();
    final repository = CatalogRepository()
      ..data = catalog
      ..loading = false;
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _ListsHost(repository: repository, child: const FindPage()),
    );
    expect(
      find.byKey(const Key('curated-card-deadly-poisonous')),
      findsNothing,
    );
    expect(find.text("Couldn't load lists."), findsNothing);
    expect(find.text('Lists'), findsNothing);

    repository.curatedLists = const CuratedListsSnapshot([], failed: true);
    await tester.pumpWidget(
      _ListsHost(repository: repository, child: const FindPage()),
    );
    expect(find.text("Couldn't load lists."), findsOneWidget);
    expect(find.text('Lists'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('List of mushrooms'), findsOneWidget);
    expect(find.text('Lists'), findsNothing);
    expect(
      find.byKey(const Key('curated-card-us-state-mushrooms')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('curated-card-deadly-poisonous')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('curated-card-mushroom-of-the-year-de')),
      findsNothing,
    );

    await tester.pumpWidget(
      _ListsHost(repository: repository, child: const BookPage()),
    );
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('curated-card-us-state-mushrooms')),
      findsOneWidget,
    );
    expect(find.textContaining('Austria'), findsNothing);
    await tester.tap(find.byKey(const Key('curated-card-deadly-poisonous')));
    await tester.pumpAndSettle();
    expect(find.text('Amanita phalloides'), findsWidgets);
    expect(find.text('Book'), findsWidgets);
  });
}

class _ListsHost extends StatefulWidget {
  final CatalogRepository repository;
  final Widget child;

  const _ListsHost({required this.repository, required this.child});

  @override
  State<_ListsHost> createState() => _ListsHostState();
}

class _ListsHostState extends State<_ListsHost> {
  @override
  Widget build(BuildContext context) {
    return GuideScope(
      catalog: widget.repository,
      notebook: Notebook(),
      settings: GuideSettings(),
      reload: () async {},
      reloadLists: () async {
        widget.repository.curatedLists = CuratedListsSnapshot(_seed());
        setState(() {});
      },
      selectTab: (_) {},
      child: MaterialApp(
        theme: guideTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: widget.child),
      ),
    );
  }
}
