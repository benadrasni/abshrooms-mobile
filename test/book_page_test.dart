import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/book/book_page.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  testWidgets('Book matches the plant segments', (tester) async {
    addTearDown(() => BookLists.request.value = 0);
    final catalog = buildCatalog(
      language: 'en',
      speciesDocs: [
        Doc('Boletus edulis', {
          'name': 'Boletus edulis',
          'id': 4,
          'taxonomy': {'family': 'Boletaceae', 'genus': 'Boletus'},
          'fruitingFrom': 1,
          'fruitingTo': 12,
        }),
        Doc('Amanita muscaria', {
          'name': 'Amanita muscaria',
          'id': 2,
          'taxonomy': {'family': 'Amanitaceae', 'genus': 'Amanita'},
          'fruitingFrom': 1,
          'fruitingTo': 12,
        }),
      ],
      local: const {},
      english: const {},
      synonyms: const {},
      taxa: const {'Boletaceae': 'bolete family'},
      key: const {
        'Boletus edulis': KeyFacts(
          hymenium: 'tubes',
          where: ['ground'],
          color: ['brown'],
          added: '2026-10-24',
        ),
        'Amanita muscaria': KeyFacts(
          hymenium: 'gills',
          where: ['ground'],
          color: ['red'],
          added: '2026-10-23',
        ),
      },
    );
    final repository = CatalogRepository()
      ..data = catalog
      ..loading = false;
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'one',
          millis: 0,
          latin: 'Boletus edulis',
          confirmed: true,
        ),
      ]
      ..favorites = {'Amanita muscaria'};
    notebook.notifyListeners();
    tester.view.physicalSize = const Size(800, 1600);
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
          home: const Scaffold(body: BookPage()),
        ),
      ),
    );
    expect(find.text('Book'), findsOneWidget);
    expect(find.text('2 mushrooms · 2 families'), findsOneWidget);
    expect(find.text('bolete family'), findsOneWidget);
    expect(find.text('Boletus'), findsNothing);

    await tester.tap(find.text('Genera'));
    await tester.pump();
    expect(find.text('Boletus'), findsOneWidget);
    expect(find.textContaining('Fruiting now · 1'), findsWidgets);
    expect(find.textContaining("you've seen 1"), findsOneWidget);
    expect(find.text('bolete family'), findsNothing);

    await tester.tap(find.text('Lists'));
    await tester.pump();
    expect(find.textContaining('Favorite mushrooms'), findsOneWidget);
    expect(find.textContaining('New in the book'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.text('Families'));
    await tester.pump();
    expect(find.text('bolete family'), findsOneWidget);
    BookLists.open();
    await tester.pump();
    expect(find.textContaining('Favorite mushrooms'), findsOneWidget);
    expect(find.text('bolete family'), findsNothing);
  });
}
