import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/book/book_page.dart';
import 'package:whats_that_mushroom/book/favorites_page.dart';
import 'package:whats_that_mushroom/book/list_chrome.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/find/strips.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

void main() {
  test('favorites grid columns follow the plants results list', () {
    expect(favoritesGridColumns(const Size(390, 844)), 2);
    expect(favoritesGridColumns(const Size(800, 1200)), 3);
    expect(favoritesGridColumns(const Size(1200, 800)), 4);
    expect(favoritesGridColumns(const Size(951, 700)), 4);
  });

  testWidgets('favorites open as a photo grid split by month', (tester) async {
    final month = DateTime.now().month;
    final other = month == 12 ? 1 : month + 1;
    final catalog = _catalog(month: month, other: other);
    final notebook = Notebook()
      ..favorites = {'Amanita muscaria', 'Boletus edulis', 'Missing name'}
      ..finds = [
        FindRecord(
          id: 'one',
          millis: 0,
          latin: 'Amanita muscaria',
          confirmed: true,
        ),
      ];
    await _pump(
      tester,
      catalog,
      notebook,
      const FavoritesPage(backLabel: 'Find'),
    );

    expect(find.text('Favorite mushrooms'), findsOneWidget);
    expect(find.text('Favorites'), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(SpeciesRow), findsNothing);
    expect(find.byType(SpeciesCell), findsNWidgets(2));
    expect(_plain('2 mushrooms · you\'ve seen 1'), findsOneWidget);
    expect(find.text('FRUITING NOW · 1'), findsOneWidget);
    expect(find.text('OTHER MONTHS · 1'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Plates'), findsOneWidget);
    expect(find.text('fly agaric'), findsOneWidget);
    expect(find.text('Amanita muscaria'), findsOneWidget);
    expect(find.text('Boletus edulis'), findsOneWidget);
    expect(find.text('✓ Seen'), findsOneWidget);
    expect(_plain('Not here?'), findsOneWidget);
    expect(find.text('Try a photo'), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);

    await tester.tap(find.text('Plates'));
    await tester.pump();
    expect(find.byType(SpeciesCell), findsNWidgets(2));

    await tester.tap(find.text('fly agaric'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
  });

  testWidgets('an empty favorites list keeps the plants empty line', (
    tester,
  ) async {
    await _pump(
      tester,
      _catalog(month: 6, other: 1),
      Notebook(),
      const FavoritesPage(backLabel: 'Book'),
    );
    expect(
      find.text('There are no favorite mushrooms yet.'),
      findsOneWidget,
    );
    expect(find.text('Photos'), findsNothing);
    expect(find.byType(SpeciesCell), findsNothing);
    expect(_plain('0 mushrooms'), findsOneWidget);
    expect(find.text('Try a photo'), findsOneWidget);
  });

  testWidgets('Book and Find open the same favorites grid', (tester) async {
    addTearDown(() => BookLists.request.value = 0);
    final catalog = _catalog(month: DateTime.now().month, other: 1);
    final notebook = Notebook()..favorites = {'Amanita muscaria'};
    await _pump(tester, catalog, notebook, const Scaffold(body: BookPage()));
    await tester.tap(find.text('Lists'));
    await tester.pump();
    await tester.tap(find.textContaining('Favorite mushrooms'));
    await tester.pumpAndSettle();
    expect(find.text('FRUITING NOW · 1'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Book'), findsOneWidget);
  });

  testWidgets('Find opens the same favorites grid', (tester) async {
    final catalog = _catalog(month: DateTime.now().month, other: 1);
    final notebook = Notebook()..favorites = {'Amanita muscaria'};
    await _pump(
      tester,
      catalog,
      notebook,
      Scaffold(
        body: ListStrip(
          copy: const Copy('en'),
          catalog: catalog,
          favorites: [catalog.byName('Amanita muscaria')!],
          fresh: const [],
        ),
      ),
    );
    await tester.tap(find.text('Favorite mushrooms'));
    await tester.pumpAndSettle();
    expect(find.text('FRUITING NOW · 1'), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
  });
}

Finder _plain(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final span = widget.textSpan;
    final value = widget.data ?? span?.toPlainText() ?? '';
    return value.contains(text);
  });
}

Catalog _catalog({required int month, required int other}) {
  return buildCatalog(
    language: 'en',
    speciesDocs: [
      Doc('Amanita muscaria', {
        'name': 'Amanita muscaria',
        'id': 1,
        'fruitingFrom': month,
        'fruitingTo': month,
      }),
      Doc('Boletus edulis', {
        'name': 'Boletus edulis',
        'id': 2,
        'fruitingFrom': other,
        'fruitingTo': other,
      }),
    ],
    local: const {
      'Amanita muscaria': {'label': 'fly agaric'},
    },
    english: const {},
    synonyms: const {},
    taxa: const {},
  );
}

Future<void> _pump(
  WidgetTester tester,
  Catalog catalog,
  Notebook notebook,
  Widget home,
) async {
  final repository = CatalogRepository()
    ..data = catalog
    ..loading = false;
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    GuideScope(
      catalog: repository,
      notebook: notebook,
      settings: GuideSettings(),
      reload: () async {},
      selectTab: (_) {},
      child: MaterialApp(
        theme: guideTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
}
