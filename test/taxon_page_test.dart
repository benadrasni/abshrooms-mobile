import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/ads/app_banner_ad.dart';
import 'package:whats_that_mushroom/book/book_page.dart';
import 'package:whats_that_mushroom/book/list_chrome.dart';
import 'package:whats_that_mushroom/book/taxon_page.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/search/search_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

void main() {
  test('family and genus grids follow the plants results list', () {
    expect(taxonGridColumns(const Size(390, 844)), 2);
    expect(taxonGridColumns(const Size(800, 1200)), 3);
    expect(taxonGridColumns(const Size(1200, 800)), 4);
    expect(taxonGridColumns(const Size(951, 700)), 4);
  });

  testWidgets('a family opens as a photo grid split by month', (tester) async {
    final month = DateTime.now().month;
    final other = month == 12 ? 1 : month + 1;
    final catalog = _catalog(month: month, other: other);
    final notebook = Notebook()
      ..favorites = {'Amanita muscaria'}
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
      const TaxonPage(kind: 'family', name: 'Amanitaceae', backLabel: 'Book'),
    );

    expect(find.text('fly agaric family'), findsOneWidget);
    expect(find.text('Amanitaceae'), findsOneWidget);
    expect(find.text('Mushrooms in this family.'), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(SpeciesRow), findsNothing);
    expect(find.byType(AppBannerAd), findsNothing);
    expect(find.byType(SpeciesCell), findsNWidgets(2));
    expect(_plain('2 mushrooms · you\'ve seen 1'), findsOneWidget);
    expect(find.text('FRUITING NOW · 1'), findsOneWidget);
    expect(find.text('OTHER MONTHS · 1'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Plates'), findsOneWidget);
    expect(find.text('fly agaric'), findsOneWidget);
    expect(find.text('Amanita muscaria'), findsOneWidget);
    expect(find.text('Amanita phalloides'), findsOneWidget);
    expect(find.text('✓ Seen'), findsOneWidget);
    expect(_plain('Not here?'), findsOneWidget);
    expect(find.text('Try a photo'), findsOneWidget);
    expect(find.text('Book'), findsOneWidget);

    await tester.tap(find.text('Plates'));
    await tester.pump();
    expect(find.byType(SpeciesCell), findsNWidgets(2));

    await tester.tap(find.text('fly agaric'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
  });

  testWidgets('a genus with no vernacular shows the Latin name once', (
    tester,
  ) async {
    final month = DateTime.now().month;
    await _pump(
      tester,
      _catalog(month: month, other: month == 12 ? 1 : month + 1),
      Notebook(),
      const TaxonPage(kind: 'genus', name: 'Boletus'),
    );

    expect(find.text('Species in this genus.'), findsNothing);
    expect(find.text('Boletus'), findsOneWidget);
    expect(find.text('Boletus edulis'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.byType(AppBannerAd), findsNothing);
  });

  testWidgets('Book opens the same family grid', (tester) async {
    addTearDown(() => BookLists.request.value = 0);
    final month = DateTime.now().month;
    final catalog = _catalog(month: month, other: month == 12 ? 1 : month + 1);
    await _pump(tester, catalog, Notebook(), const Scaffold(body: BookPage()));

    await tester.tap(find.text('fly agaric family'));
    await tester.pumpAndSettle();

    final page = find.byType(TaxonPage);
    expect(page, findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.text('Book')),
      findsOneWidget,
    );
    expect(find.text('FRUITING NOW · 1'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Mushrooms in this family.'), findsNothing);
    expect(find.byType(SpeciesRow), findsNothing);
  });

  testWidgets('Search opens the same family grid', (tester) async {
    final month = DateTime.now().month;
    await _pump(
      tester,
      _catalog(month: month, other: 1),
      Notebook(),
      const SearchPage(),
    );

    await tester.enterText(find.byType(TextField), 'agaric');
    await tester.pump();
    await tester.tap(find.text('fly agaric family'));
    await tester.pumpAndSettle();

    final page = find.byType(TaxonPage);
    expect(page, findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.text('Search')),
      findsOneWidget,
    );
    expect(find.byType(SpeciesCell), findsNWidgets(2));
    expect(find.text('Mushrooms in this family.'), findsNothing);
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
        'taxonomy': {'family': 'Amanitaceae', 'genus': 'Amanita'},
        'fruitingFrom': month,
        'fruitingTo': month,
      }),
      Doc('Amanita phalloides', {
        'name': 'Amanita phalloides',
        'id': 2,
        'taxonomy': {'family': 'Amanitaceae', 'genus': 'Amanita'},
        'fruitingFrom': other,
        'fruitingTo': other,
      }),
      Doc('Boletus edulis', {
        'name': 'Boletus edulis',
        'id': 3,
        'taxonomy': {'family': 'Boletaceae', 'genus': 'Boletus'},
        'fruitingFrom': month,
        'fruitingTo': month,
      }),
    ],
    local: const {
      'Amanita muscaria': {'label': 'fly agaric'},
    },
    english: const {},
    synonyms: const {},
    taxa: const {'Amanitaceae': 'fly agaric family'},
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
