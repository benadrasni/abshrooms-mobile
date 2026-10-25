import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/species/seen_photo.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

void main() {
  testWidgets('cancelling the photo picker saves nothing', (tester) async {
    final notebook = _notebook();
    await _pump(tester, notebook, pick: () async => null);

    await tester.tap(find.text('+ Add to Seen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(notebook.finds, isEmpty);
    expect(find.text('Added to Seen.'), findsNothing);
    expect(
      find.text('Added to Seen. Date and place from the photo.'),
      findsNothing,
    );
    expect(find.text('Couldn’t save this find.'), findsNothing);
    expect(find.textContaining('Seen by you'), findsNothing);
  });

  testWidgets('a photo supplies the date and place', (tester) async {
    final notebook = _notebook();
    await _pump(
      tester,
      notebook,
      pick: () async => SeenPhoto(
        bytes: _jpeg,
        when: DateTime(2026, 7, 4, 15, 4),
        latitude: 48.1,
        longitude: 17.1,
        fromPhoto: true,
      ),
    );

    await _save(tester);

    expect(notebook.finds, hasLength(1));
    final findRecord = notebook.finds.single;
    expect(findRecord.latin, 'Boletus edulis');
    expect(findRecord.confirmed, isTrue);
    expect(
      findRecord.millis,
      DateTime(2026, 7, 4, 15, 4).millisecondsSinceEpoch,
    );
    expect(findRecord.latitude, 48.1);
    expect(findRecord.longitude, 17.1);
    expect(findRecord.photoPath, isNotNull);
    expect(File(findRecord.photoPath!).existsSync(), isTrue);
    expect(
      find.text('Added to Seen. Date and place from the photo.'),
      findsOneWidget,
    );
    expect(find.textContaining('Seen by you'), findsOneWidget);
    expect(find.textContaining('once, last Jul 4'), findsOneWidget);
    await _clearSnack(tester);
  });

  testWidgets('a photo without a date says it was added', (tester) async {
    final notebook = _notebook();
    await _pump(
      tester,
      notebook,
      pick: () async => SeenPhoto(
        bytes: _jpeg,
        when: DateTime(2026, 10, 25, 9),
        latitude: 0,
        longitude: 0,
        fromPhoto: false,
      ),
    );

    await _save(tester);

    expect(notebook.finds.single.latitude, isNull);
    expect(find.text('Added to Seen.'), findsOneWidget);
    expect(
      find.text('Added to Seen. Date and place from the photo.'),
      findsNothing,
    );
    await _clearSnack(tester);
  });

  testWidgets('a failed save shows the failure and keeps the notebook', (
    tester,
  ) async {
    final notebook = _notebook();
    await _pump(tester, notebook, pick: () async => throw StateError('disk'));

    await tester.tap(find.text('+ Add to Seen'));
    await tester.pump();
    await tester.pump();

    expect(notebook.finds, isEmpty);
    expect(find.text('Couldn’t save this find.'), findsOneWidget);
    await _clearSnack(tester);
  });

  testWidgets('an earlier find is on the page, and the card opens Seen', (
    tester,
  ) async {
    final notebook = _notebook();
    notebook.finds = [
      FindRecord(
        id: 'earlier',
        millis: DateTime(2026, 6, 2).millisecondsSinceEpoch,
        latin: 'Boletus edulis',
        confirmed: true,
      ),
      FindRecord(
        id: 'other',
        millis: DateTime(2026, 8, 1).millisecondsSinceEpoch,
        latin: 'Amanita muscaria',
        confirmed: true,
      ),
    ];
    var tab = 0;
    await _pump(tester, notebook, onTab: (index) => tab = index, pushed: true);

    expect(find.textContaining('Seen by you'), findsOneWidget);
    expect(find.textContaining('once, last Jun 2'), findsOneWidget);
    expect(find.text('+ Add to Seen'), findsOneWidget);

    await tester.tap(find.text('Seen by you'));
    await tester.pumpAndSettle();

    expect(tab, 2);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('+ Add to Seen'), findsNothing);
  });

  testWidgets('Slovak uses the nálezy wording', (tester) async {
    final notebook = _notebook();
    await _pump(tester, notebook, language: 'sk', pick: () async => null);

    expect(find.text('+ Pridať do nálezov'), findsOneWidget);
    expect(find.text('Z tvojich fotografií. Zadarmo.'), findsOneWidget);
  });
}

final _jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 2, height: 2)));

Notebook _notebook() {
  final dir = Directory.systemTemp.createTempSync('mushroom-seen');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return Notebook()..useStorage(dir);
}

Future<void> _pump(
  WidgetTester tester,
  Notebook notebook, {
  Future<SeenPhoto?> Function()? pick,
  void Function(int index)? onTab,
  String language = 'en',
  bool pushed = false,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = CatalogRepository()
    ..data = buildCatalog(
      language: language,
      speciesDocs: [
        Doc('Boletus edulis', {
          'name': 'Boletus edulis',
          'taxonomy': {'family': 'Boletaceae', 'genus': 'Boletus'},
        }),
      ],
      local: const {},
      english: const {},
      synonyms: const {},
      taxa: const {},
      key: const {},
    )
    ..loading = false;
  final page = SpeciesPage(latin: 'Boletus edulis', pickSeen: pick);
  await tester.pumpWidget(
    GuideScope(
      catalog: repository,
      notebook: notebook,
      settings: GuideSettings()..language = language,
      reload: () async {},
      selectTab: onTab ?? (_) {},
      child: MaterialApp(
        theme: guideTheme(Brightness.light),
        locale: Locale(language),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: pushed
            ? Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => page));
                    },
                    child: const Text('open'),
                  );
                },
              )
            : page,
      ),
    ),
  );
  if (pushed) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('+ Add to Seen'));
  await tester.pump();
  await tester.pump();
}

Future<void> _clearSnack(WidgetTester tester) async {
  final context = tester.element(find.byType(SpeciesPage));
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
