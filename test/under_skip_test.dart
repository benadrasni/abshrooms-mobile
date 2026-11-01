import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/key_filter.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/find/find_page.dart';
import 'package:whats_that_mushroom/find/key_glyph.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

Catalog _catalog() {
  return buildCatalog(
    language: 'en',
    speciesDocs: [
      const Doc('Gilled', {
        'name': 'Gilled',
        'id': 1,
        'hymenium': 'gills',
        'where': ['wood'],
        'color': ['brown'],
      }),
    ],
    local: const {},
    english: const {},
    synonyms: const {},
    taxa: const {},
  );
}

void main() {
  test('the underside skip is not a hymenium code', () {
    expect(underChoices, isNot(contains(underSkip)));
    expect(catalogHymenium(underSkip), isNull);
    expect(catalogHymenium('gills'), 'gills');
  });

  testWidgets('Not clear opens where it grows without an underside filter', (
    tester,
  ) async {
    final repository = CatalogRepository()
      ..data = _catalog()
      ..loading = false;
    tester.view.physicalSize = const Size(800, 2000);
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
          home: const Scaffold(body: FindPage()),
        ),
      ),
    );

    expect(find.text('What is underneath?'), findsOneWidget);
    expect(find.text('Not clear'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.byType(KeyGlyph), findsNWidgets(8));
    final enclosed = tester.getTopLeft(find.text('Enclosed'));
    final unclear = tester.getTopLeft(find.text('Not clear'));
    expect(unclear.dx, greaterThan(enclosed.dx));
    expect((unclear.dy - enclosed.dy).abs(), lessThan(8));

    final skipOpacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('Not clear'), matching: find.byType(Opacity))
          .first,
    );
    expect(skipOpacity.opacity, 1);
    final teethOpacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('Teeth'), matching: find.byType(Opacity))
          .first,
    );
    expect(teethOpacity.opacity, lessThan(1));

    await tester.tap(find.text('Not clear'));
    await tester.pumpAndSettle();
    expect(find.text('Where is it growing?'), findsOneWidget);
    expect(find.text('Gills'), findsNothing);
    expect(find.text('Not clear'), findsNothing);
    expect(find.text('Anywhere'), findsOneWidget);
  });
}
