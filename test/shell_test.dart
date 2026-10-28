import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/shell/app_version.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/shell.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  testWidgets('the bottom bar uses the plant tab icons', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
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

    expect(find.byIcon(Icons.center_focus_weak), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.photo_outlined), findsNothing);
    expect(find.byKey(const Key('version-banner')), findsNothing);
  });

  testWidgets('a newer store build shows the update banner', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var updates = 0;
    var dismisses = 0;
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
          home: GuideShell(
            index: 0,
            onSelect: (_) {},
            versionPrompt: VersionPrompt.banner,
            onVersionUpdate: () => updates++,
            onVersionDismiss: () => dismisses++,
          ),
        ),
      ),
    );

    expect(
      find.text('New version is available, please update.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('version-banner-update')));
    await tester.tap(find.byKey(const Key('version-banner-dismiss')));
    await tester.pump();
    expect(updates, 1);
    expect(dismisses, 1);
  });
}
