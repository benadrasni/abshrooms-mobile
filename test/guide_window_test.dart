import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/shell/guide_window.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/shell.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  test('a phone stays on the phone layout', () {
    final phone = GuideWindow.fromSize(const Size(390, 844));
    expect(phone.tablet, isFalse);
    expect(phone.wide, isFalse);
    expect(phone.columns(phone: 2, tablet: 3, wide: 4), 2);

    final landscape = GuideWindow.fromSize(const Size(844, 390));
    expect(landscape.tablet, isFalse);
    expect(landscape.wide, isFalse);

    final tests = GuideWindow.fromSize(const Size(800, 600));
    expect(tests.tablet, isFalse);
    expect(tests.wide, isFalse);
  });

  test('iPad portrait is a tablet and landscape is wide', () {
    final portrait = GuideWindow.fromSize(const Size(834, 1194));
    expect(portrait.tablet, isTrue);
    expect(portrait.wide, isFalse);
    expect(portrait.columns(phone: 2, tablet: 3, wide: 4), 3);

    final landscape = GuideWindow.fromSize(const Size(1194, 834));
    expect(landscape.tablet, isTrue);
    expect(landscape.wide, isTrue);
    expect(landscape.columns(phone: 2, tablet: 3, wide: 4), 4);

    final miniPortrait = GuideWindow.fromSize(const Size(744, 1133));
    expect(miniPortrait.tablet, isTrue);
    expect(miniPortrait.wide, isFalse);

    final miniLandscape = GuideWindow.fromSize(const Size(1133, 744));
    expect(miniLandscape.wide, isTrue);

    // 12.9-inch and 13-inch portrait are past 1000 points and still stay
    // on the tablet layout, so rotation can reach the sidebar.
    final proPortrait = GuideWindow.fromSize(const Size(1024, 1366));
    expect(proPortrait.tablet, isTrue);
    expect(proPortrait.wide, isFalse);

    final pro13Portrait = GuideWindow.fromSize(const Size(1032, 1376));
    expect(pro13Portrait.wide, isFalse);
    expect(pro13Portrait.columns(phone: 1, tablet: 2, wide: 3), 2);

    final pro13Landscape = GuideWindow.fromSize(const Size(1376, 1032));
    expect(pro13Landscape.wide, isTrue);
    expect(GuideWindow.photoColumns(const Size(1376, 1032)), 4);
  });

  test('a landscape tablet uses four photo columns before the wide bar', () {
    expect(GuideWindow.photoColumns(const Size(951, 700)), 4);
    expect(GuideWindow.photoColumns(const Size(800, 1200)), 3);
    expect(GuideWindow.photoColumns(const Size(390, 844)), 2);
  });

  test('a side status column is the vertical tab edge', () {
    expect(
      GuideChrome.fromPadding(const EdgeInsets.only(top: 59)).vertical,
      isFalse,
    );

    final right = GuideChrome.fromPadding(
      const EdgeInsets.only(right: 84, bottom: 34),
    );
    expect(right.vertical, isTrue);
    expect(right.onRight, isTrue);
    expect(right.side, 84);

    final left = GuideChrome.fromPadding(const EdgeInsets.only(left: 84));
    expect(left.vertical, isTrue);
    expect(left.onRight, isFalse);

    expect(
      GuideChrome.fromPadding(const EdgeInsets.only(top: 90, right: 84))
          .vertical,
      isFalse,
    );
  });

  testWidgets('a wide iPad uses the side rail instead of the bottom bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GuideScope(
        catalog: CatalogRepository(),
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
          home: GuideShell(index: 0, onSelect: (_) {}),
        ),
      ),
    );

    expect(find.byKey(const Key('guide-side-rail')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byIcon(Icons.center_focus_weak), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('iPad portrait keeps the bottom bar', (tester) async {
    tester.view.physicalSize = const Size(834, 1194);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GuideScope(
        catalog: CatalogRepository(),
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
          home: GuideShell(index: 1, onSelect: (_) {}),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('guide-side-rail')), findsNothing);
  });
}
