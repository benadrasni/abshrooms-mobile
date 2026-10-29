import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/key_filter.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/key/key_pages.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

Catalog _catalog() {
  return buildCatalog(
    language: 'en',
    speciesDocs: [
      Doc('Wood', {
        'name': 'Wood',
        'id': 1,
        'fruitingFrom': DateTime.now().month,
        'fruitingTo': DateTime.now().month,
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

Future<void> _pump(WidgetTester tester, KeySelection selection) async {
  final repository = CatalogRepository()
    ..data = _catalog()
    ..loading = false;
  tester.view.physicalSize = const Size(400, 1400);
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
        home: ColorPage(selection: selection),
      ),
    ),
  );
}

String _seasonNow() {
  final month = DateTime.now().month;
  if (month >= 3 && month <= 5) return 'Spring';
  if (month >= 6 && month <= 8) return 'Summer';
  if (month >= 9 && month <= 11) return 'Autumn';
  return 'Winter';
}

Rect _pill(WidgetTester tester, String label) {
  final material = find
      .ancestor(of: find.text(label), matching: find.byType(Material))
      .first;
  return tester.getRect(material);
}

void main() {
  testWidgets('Color page uses habitat back, filters, and a 4 then 3 grid', (
    tester,
  ) async {
    await _pump(tester, const KeySelection(under: 'gills', where: 'wood'));

    expect(find.text('Habitat'), findsOneWidget);
    expect(find.text('Gills'), findsOneWidget);
    expect(find.text('On wood'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Habitat')).dy,
      lessThan(tester.getTopLeft(find.text('Gills')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Gills')).dx,
      lessThan(tester.getTopLeft(find.text('On wood')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Gills')).dy,
      lessThan(tester.getTopLeft(find.text('What colour is the cap?')).dy),
    );
    expect(find.text('KEY IT OUT · 3 OF 3'), findsOneWidget);
    expect(find.text('ALWAYS FREE'), findsOneWidget);
    expect(find.text('What colour is the cap?'), findsOneWidget);
    expect(
      find.text(
        'Yellow includes orange. Red includes pink. Dark is grey or black. '
        'A cap can match more than one colour.',
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('What colour is the cap?')).dy,
      lessThan(
        tester.getTopLeft(find.textContaining('Yellow includes orange')).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.textContaining('Yellow includes orange')).dy,
      lessThan(tester.getTopLeft(find.text('Any colour')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Any colour')).dy,
      lessThan(tester.getTopLeft(find.text('White')).dy),
    );
    final anyFill = tester.widget<Material>(
      find
          .ancestor(
            of: find.text('Any colour'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(anyFill.color, GuideColors.light.cream);
    expect(
      find.descendant(of: find.byWidget(anyFill), matching: find.text('1')),
      findsOneWidget,
    );
    expect(tester.getSize(find.byWidget(anyFill)).width, greaterThan(300));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is KeyStepper && widget.filled == 3 && widget.steps == 3,
      ),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.indicatorColor, Colors.transparent);

    final white = _pill(tester, 'White');
    final yellow = _pill(tester, 'Yellow');
    final red = _pill(tester, 'Red');
    final brown = _pill(tester, 'Brown');
    final green = _pill(tester, 'Green');
    final purple = _pill(tester, 'Purple');
    final dark = _pill(tester, 'Dark');
    for (final pill in [yellow, red, brown]) {
      expect(pill.top, white.top);
      expect(pill.width, white.width);
    }
    for (final pill in [purple, dark]) {
      expect(pill.top, green.top);
      expect(pill.width, white.width);
    }
    expect(green.top, greaterThan(white.bottom));
    expect(green.left, white.left);
    expect(purple.left, yellow.left);
    expect(dark.left, red.left);
    expect(brown.left, greaterThan(dark.left));
    expect(white.width, greaterThan(white.height * 0.7));
    expect(white.width, lessThan(white.height * 1.3));

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return colorChoices.any((id) => decoration.color == colorSwatch(id));
      }),
      findsNWidgets(7),
    );

    await tester.tap(find.text('White'));
    await tester.pumpAndSettle();
    expect(find.text('What colour is the cap?'), findsOneWidget);
    expect(find.text('1 mushroom'), findsNothing);

    await tester.tap(find.text('Brown'));
    await tester.pumpAndSettle();
    expect(find.text('Colour'), findsOneWidget);
    expect(find.text('Any season'), findsOneWidget);
    expect(find.text('1 mushroom', findRichText: true), findsOneWidget);
    expect(find.text('FRUITING NOW · 1'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Plates'), findsOneWidget);
    expect(find.text('Wood'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
    final anySeason = tester.widget<Material>(
      find
          .ancestor(
            of: find.text('Any season'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(anySeason.color, GuideColors.light.cream);

    await tester.tap(find.text('Any season'));
    await tester.pumpAndSettle();
    expect(find.text('When did you find it?'), findsOneWidget);
    expect(find.text(_seasonNow()), findsOneWidget);
    for (final name in ['Spring', 'Summer', 'Autumn', 'Winter']) {
      if (name == _seasonNow()) continue;
      expect(find.text(name), findsNothing);
    }

    await tester.tap(find.text(_seasonNow()));
    await tester.pumpAndSettle();
    expect(find.text('When did you find it?'), findsNothing);
    final chosen = tester.widget<Material>(
      find
          .ancestor(
            of: find.text(_seasonNow()),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(chosen.color, GuideColors.light.mossFill);

    await tester.tap(find.text('Brown'));
    await tester.pumpAndSettle();
    expect(find.text('What colour is the cap?'), findsOneWidget);

    await tester.tap(find.text('Any colour'));
    await tester.pumpAndSettle();
    expect(find.text('1 mushroom', findRichText: true), findsOneWidget);
    expect(find.text('Brown'), findsNothing);
    expect(find.text('Gills'), findsOneWidget);
    expect(find.text('On wood'), findsOneWidget);
  });

  testWidgets('Anywhere keeps only the underside filter pill', (tester) async {
    await _pump(tester, const KeySelection(under: 'gills'));

    expect(find.text('Habitat'), findsOneWidget);
    expect(find.text('Gills'), findsOneWidget);
    expect(find.text('On wood'), findsNothing);
    expect(find.text('With trees'), findsNothing);
    expect(find.text('In grass'), findsNothing);
  });

  testWidgets('Filter pills return to the step that chose them', (
    tester,
  ) async {
    final repository = CatalogRepository()
      ..data = _catalog()
      ..loading = false;
    tester.view.physicalSize = const Size(400, 1400);
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
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WherePage(
                      selection: KeySelection(under: 'gills'),
                    ),
                  ),
                );
              },
              child: const Text('Find'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On wood'));
    await tester.pumpAndSettle();
    expect(find.text('Habitat'), findsOneWidget);

    await tester.tap(find.text('On wood'));
    await tester.pumpAndSettle();
    expect(find.text('Where is it growing?'), findsOneWidget);
    expect(find.text('Habitat'), findsNothing);

    await tester.tap(find.text('On wood'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gills'));
    await tester.pumpAndSettle();
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('What colour is the cap?'), findsNothing);
    expect(find.text('Where is it growing?'), findsNothing);
  });
}
