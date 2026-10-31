import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/offline/offline_book.dart';
import 'package:whats_that_mushroom/offline/offline_page.dart';
import 'package:whats_that_mushroom/offline/offline_plan.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  const book = OfflineView(
    species: 62,
    canDownload: true,
    stored: false,
    pending: ['photos/a.webp'],
    alreadyDone: 0,
    totalFiles: 1,
    missingSpecies: 62,
  );

  Future<void> pump(WidgetTester tester, OfflinePage page) async {
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
        child: MaterialApp(theme: guideTheme(Brightness.light), home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the page offers the whole book and no region', (tester) async {
    OfflineRequest? request;
    await pump(
      tester,
      OfflinePage(
        view: book,
        onDownload: (value) async {
          request = value;
        },
      ),
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Everything'), findsOneWidget);
    expect(find.text('62 mushrooms'), findsOneWidget);
    expect(find.text('about 40 MB'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Or a part of the world'), findsNothing);
    expect(find.text('Where this phone is'), findsNothing);
    expect(find.text('This phone'), findsNothing);
    expect(find.textContaining('region'), findsNothing);

    await tester.tap(find.byKey(offlineEverythingKey));
    await tester.pump();
    await tester.tap(find.byKey(offlineDownloadKey));
    await tester.pump();
    expect(request?.pending, ['photos/a.webp']);
    expect(request?.markStored, isTrue);
    expect(request?.update, isFalse);
  });

  testWidgets('without Field Guide the download opens the offer', (
    tester,
  ) async {
    var opened = false;
    await pump(
      tester,
      OfflinePage(
        view: const OfflineView(
          species: 62,
          canDownload: false,
          stored: false,
          pending: ['photos/a.webp'],
          alreadyDone: 0,
          totalFiles: 1,
          missingSpecies: 62,
        ),
        onFieldGuide: () async {
          opened = true;
        },
      ),
    );

    expect(find.text('Field Guide keeps the book offline'), findsOneWidget);
    expect(find.text('See Field Guide'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    expect(find.text('Field Guide'), findsOneWidget);

    await tester.tap(find.byKey(offlineEverythingKey));
    await tester.pump();
    await tester.tap(find.byKey(offlineDownloadKey));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('Wi-Fi refusal explains itself', (tester) async {
    await pump(
      tester,
      OfflinePage(
        view: book,
        start:
            ({
              required request,
              required onProgress,
              required onFinished,
              required onFailed,
            }) async {
              return OfflineStart.needsWifi;
            },
      ),
    );
    await tester.tap(find.byKey(offlineEverythingKey));
    await tester.pump();
    await tester.tap(find.byKey(offlineDownloadKey));
    await tester.pump();
    expect(find.text('Connect to Wi-Fi to download.'), findsOneWidget);
  });

  testWidgets('a stored book can be removed or updated', (tester) async {
    var removed = false;
    await pump(
      tester,
      OfflinePage(
        view: const OfflineView(
          species: 62,
          canDownload: true,
          stored: true,
          pending: [],
          alreadyDone: 1,
          totalFiles: 1,
          missingSpecies: 0,
        ),
        onRemove: () async {
          removed = true;
        },
      ),
    );
    expect(find.text('On this phone'), findsWidgets);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Update'), findsNothing);
    await tester.tap(find.byKey(offlineRemoveKey));
    await tester.pump();
    expect(removed, isTrue);

    var updated = false;
    await pump(
      tester,
      OfflinePage(
        view: const OfflineView(
          species: 62,
          canDownload: true,
          stored: true,
          pending: ['photos/new.webp'],
          alreadyDone: 7,
          totalFiles: 8,
          missingSpecies: 1,
        ),
        onUpdate: () async {
          updated = true;
        },
      ),
    );
    expect(find.text('Update'), findsWidgets);
    expect(find.text('1 mushroom · about 0.7 MB'), findsOneWidget);
    await tester.tap(find.byKey(offlineUpdateKey));
    await tester.pump();
    expect(updated, isTrue);

    await pump(
      tester,
      const OfflinePage(
        view: OfflineView(
          species: 62,
          canDownload: true,
          stored: true,
          pending: [],
          alreadyDone: 8,
          totalFiles: 8,
          missingSpecies: 0,
          catalogStale: true,
          catalogBytes: 2000000,
        ),
      ),
    );
    expect(find.text('Update'), findsWidgets);
    expect(find.text('62 mushrooms · about 2 MB'), findsOneWidget);
  });

  testWidgets('a running download can pause', (tester) async {
    var paused = false;
    await pump(
      tester,
      OfflinePage(
        view: book,
        job: const OfflineJob(
          title: 'Everything',
          species: 62,
          doneMb: 10,
          totalMb: 40,
        ),
        onPause: () async {
          paused = true;
        },
      ),
    );
    expect(find.text('Downloading Everything'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    await tester.tap(find.byKey(offlinePauseKey));
    await tester.pump();
    expect(paused, isTrue);
  });
}
