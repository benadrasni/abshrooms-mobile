import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/search/search_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  testWidgets('Search matches the plant sections', (tester) async {
    final catalog = buildCatalog(
      language: 'en',
      speciesDocs: [
        Doc('Boletus edulis', {
          'name': 'Boletus edulis',
          'id': 4,
          'taxonomy': {'family': 'Boletaceae', 'genus': 'Boletus'},
        }),
        Doc('Amanita muscaria', {
          'name': 'Amanita muscaria',
          'id': 2,
          'taxonomy': {'family': 'Amanitaceae', 'genus': 'Amanita'},
        }),
      ],
      local: const {
        'Boletus edulis': {'label': 'penny bun'},
      },
      english: const {},
      synonyms: const {},
      taxa: const {'Boletaceae': 'bolete family'},
    );
    final repository = CatalogRepository()
      ..data = catalog
      ..loading = false;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GuideScope(
        catalog: repository,
        notebook: Notebook(),
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
          home: const SearchPage(),
        ),
      ),
    );
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('Name, Latin, family, genus'), findsOneWidget);
    expect(find.textContaining('Nothing in the book'), findsNothing);

    await tester.enterText(find.byType(TextField), 'boletus');
    await tester.pump();
    expect(find.text('MUSHROOMS'), findsOneWidget);
    expect(find.text('penny bun'), findsOneWidget);
    expect(find.text('Boletus edulis'), findsOneWidget);
    expect(find.text('GENERA'), findsOneWidget);
    expect(find.text('Boletus'), findsOneWidget);
    expect(find.text('FAMILIES'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.textContaining('Nothing in the book'), findsOneWidget);
    expect(find.text('Try a photo'), findsOneWidget);
    expect(find.text('key it out'), findsOneWidget);
    expect(find.text('MUSHROOMS'), findsNothing);
  });
}
