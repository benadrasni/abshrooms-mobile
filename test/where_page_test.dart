import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/key_filter.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/find/key_glyph.dart';
import 'package:whats_that_mushroom/key/key_pages.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

Catalog _catalog() {
  return buildCatalog(
    language: 'en',
    speciesDocs: [
      const Doc('Wood', {
        'name': 'Wood',
        'id': 1,
        'hymenium': 'gills',
        'where': ['wood'],
        'color': ['brown'],
      }),
      const Doc('Ground', {
        'name': 'Ground',
        'id': 2,
        'hymenium': 'tubes',
        'where': ['ground'],
        'color': ['brown'],
      }),
      const Doc('Grass', {
        'name': 'Grass',
        'id': 3,
        'hymenium': 'gills',
        'where': ['grass'],
        'color': ['white'],
      }),
    ],
    local: const {},
    english: const {},
    synonyms: const {},
    taxa: const {},
  );
}

void main() {
  testWidgets('Where offers Anywhere, then three glyph pills', (tester) async {
    final repository = CatalogRepository()
      ..data = _catalog()
      ..loading = false;
    tester.view.physicalSize = const Size(800, 1400);
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
          home: const WherePage(selection: KeySelection(under: 'gills')),
        ),
      ),
    );

    expect(find.text('Underneath'), findsOneWidget);
    expect(find.text('Gills'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Underneath')).dy,
      lessThan(tester.getTopLeft(find.text('Gills')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Gills')).dy,
      lessThan(tester.getTopLeft(find.text('Where is it growing?')).dy),
    );
    expect(find.text('KEY IT OUT · 2 OF 3'), findsOneWidget);
    expect(find.text('ALWAYS FREE'), findsOneWidget);
    expect(find.text('Where is it growing?'), findsOneWidget);
    expect(find.textContaining('Narrow the catalog'), findsNothing);
    expect(find.text('Anywhere'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    final anywhereFill = tester.widget<Material>(
      find
          .ancestor(of: find.text('Anywhere'), matching: find.byType(Material))
          .first,
    );
    expect(anywhereFill.color, GuideColors.light.cream);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.indicatorColor, Colors.transparent);
    expect(find.text('On wood'), findsOneWidget);
    expect(find.text('With trees'), findsOneWidget);
    expect(find.text('In grass'), findsOneWidget);
    expect(find.text('stumps, trunks, logs'), findsOneWidget);
    expect(find.byType(KeyGlyph), findsNWidgets(3));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is KeyStepper && widget.filled == 2 && widget.steps == 3,
      ),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('mushroom'), findsNothing);

    final anywhere = tester.getTopLeft(find.text('Anywhere'));
    final wood = tester.getTopLeft(find.text('On wood'));
    expect(anywhere.dy, lessThan(wood.dy));

    await tester.tap(find.text('With trees'));
    await tester.pumpAndSettle();
    expect(find.text('What colour is the cap?'), findsNothing);

    await tester.tap(find.text('On wood'));
    await tester.pumpAndSettle();
    expect(find.text('What colour is the cap?'), findsOneWidget);

    Navigator.of(tester.element(find.text('What colour is the cap?'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anywhere'));
    await tester.pumpAndSettle();
    expect(find.text('What colour is the cap?'), findsOneWidget);
  });
}
