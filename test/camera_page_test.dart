import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/camera/camera_page.dart';
import 'package:whats_that_mushroom/camera/plant_id.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/purchase/names.dart';
import 'package:whats_that_mushroom/seen/seen_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  tearDown(Names.resetForTest);

  test('an outside find keeps the other names', () {
    const record = FindRecord(
      id: 'a',
      millis: 1,
      outsideName: 'Agaricus augustus',
      spoken: 'the prince',
      probability: 0.7,
      others: [FindName(scientificName: 'Boletus edulis', probability: 0.2)],
    );
    final again = FindRecord.fromJson(
      json.decode(json.encode(record.toJson())) as Map<String, dynamic>,
    );
    expect(again.outsideName, 'Agaricus augustus');
    expect(again.spoken, 'the prince');
    expect(again.others.single.scientificName, 'Boletus edulis');
    expect(again.confirmed, isFalse);
  });

  testWidgets('the camera is the plants viewfinder', (tester) async {
    await _open(tester);
    expect(find.byKey(const Key('guide-camera-close')), findsOneWidget);
    expect(find.byKey(const Key('guide-camera-shutter')), findsOneWidget);
    expect(find.byKey(const Key('guide-camera-roll')), findsOneWidget);
    expect(find.byKey(const Key('guide-camera-key')), findsOneWidget);
    expect(find.text('1 name left'), findsOneWidget);
    expect(find.text('Fruit body, in focus'), findsOneWidget);
    expect(find.text('Field Guide · unlimited'), findsNothing);
    expect(find.byKey(const Key('guide-camera-ask')), findsNothing);
    expect(find.text('Watch a short ad'), findsNothing);
    expect(find.text('Take a photo'), findsNothing);
  });

  testWidgets('Field Guide shows unlimited on the meter', (tester) async {
    await _open(tester, fieldGuide: true);
    expect(find.text('Field Guide · unlimited'), findsOneWidget);
    expect(find.text('5 names left'), findsNothing);
  });

  testWidgets('Slovak uses the fruit-body tip', (tester) async {
    await _open(tester, settings: GuideSettings()..language = 'sk');
    expect(find.text('Plodnica, zaostrená'), findsOneWidget);
    expect(find.text('1 určenie zostáva'), findsOneWidget);
    expect(find.text('Terénny sprievodca · neobmedzene'), findsNothing);
  });

  testWidgets('a name in the book opens that species', (tester) async {
    final notebook = Notebook();
    String? opened;
    await _open(
      tester,
      notebook: notebook,
      signedIn: true,
      onOpenSpecies: (latin) => opened = latin,
      identify: (_, _) async => const [
        NameGuess(
          scientificName: 'Boletus edulis',
          probability: 0.82,
          commonNames: ['penny bun'],
        ),
        NameGuess(
          scientificName: 'Amanita muscaria',
          probability: 0.1,
          commonNames: [],
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(opened, 'Boletus edulis');
    expect(notebook.finds, hasLength(1));
    expect(notebook.finds.single.latin, 'Boletus edulis');
    expect(notebook.finds.single.outsideName, isNull);
    expect(
      notebook.finds.single.others.single.scientificName,
      'Amanita muscaria',
    );
    expect(Names.count.namesUsed, 1);
  });

  testWidgets('a name outside the book opens its page', (tester) async {
    final notebook = Notebook();
    var tab = -1;
    await _open(
      tester,
      notebook: notebook,
      onTab: (index) => tab = index,
      identify: (_, _) async => const [
        NameGuess(
          scientificName: 'Agaricus augustus',
          probability: 0.7,
          commonNames: ['the prince'],
        ),
        NameGuess(
          scientificName: 'Boletus edulis',
          probability: 0.2,
          commonNames: ['penny bun'],
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide-outside-page')), findsOneWidget);
    expect(find.text('Agaricus augustus'), findsOneWidget);
    expect(find.text('the prince'), findsOneWidget);
    expect(find.text('In the book, and close'), findsOneWidget);
    expect(find.text('Boletus edulis'), findsOneWidget);
    expect(find.text('Saved to Seen · unconfirmed'), findsOneWidget);
    expect(notebook.finds.single.outsideName, 'Agaricus augustus');
    expect(notebook.finds.single.confirmed, isFalse);

    await tester.ensureVisible(find.byKey(const Key('guide-outside-keep')));
    await tester.tap(find.byKey(const Key('guide-outside-keep')));
    await tester.pumpAndSettle();
    expect(notebook.finds.single.confirmed, isTrue);
    expect(tab, 2);
    expect(find.text('open'), findsOneWidget);
    expect(find.textContaining('Confirmed. In Seen for'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('another name in the book replaces the outside find', (
    tester,
  ) async {
    final notebook = Notebook();
    String? opened;
    await _open(
      tester,
      notebook: notebook,
      onOpenSpecies: (latin) => opened = latin,
      identify: (_, _) async => const [
        NameGuess(
          scientificName: 'Agaricus augustus',
          probability: 0.4,
          commonNames: [],
        ),
        NameGuess(
          scientificName: 'Boletus edulis',
          probability: 0.3,
          commonNames: [],
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('guide-outside-another')));
    await tester.tap(find.byKey(const Key('guide-outside-another')));
    await tester.pumpAndSettle();
    expect(find.text('Which one is it?'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(opened, 'Boletus edulis');
    expect(notebook.finds.single.latin, 'Boletus edulis');
    expect(notebook.finds.single.outsideName, isNull);
    expect(notebook.finds.single.confirmed, isTrue);
    expect(find.text('Changed and confirmed.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an empty name shows the not-a-mushroom sheet', (tester) async {
    final notebook = Notebook();
    await _open(
      tester,
      notebook: notebook,
      signedIn: true,
      identify: (_, _) async => const [],
    );
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(find.text("That doesn't look like a mushroom"), findsOneWidget);
    expect(find.textContaining('fruit body'), findsOneWidget);
    expect(notebook.finds, isEmpty);
    expect(find.text("This photo didn't count. 5 names left."), findsOneWidget);
    expect(Names.count.namesUsed, 0);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text("That doesn't look like a mushroom"), findsNothing);
    expect(find.text('Fruit body, in focus'), findsOneWidget);
  });

  testWidgets('a failed name stays on the camera', (tester) async {
    await _open(tester, identify: (_, _) async => throw Exception('no'));
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(find.text('The photo could not be named.'), findsOneWidget);
    expect(find.byKey(const Key('guide-camera-shutter')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('no names left offers a short ad', (tester) async {
    Names.setForTest(used: 5);
    var named = 0;
    await _open(
      tester,
      signedIn: true,
      identify: (_, _) async {
        named += 1;
        return const [
          NameGuess(
            scientificName: 'Boletus edulis',
            probability: 0.8,
            commonNames: [],
          ),
        ];
      },
      onWatchAd: () async {
        await Names.grant();
      },
      onOpenSpecies: (_) {},
    );
    expect(find.text('0 names left'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(named, 0);
    expect(find.text('No names left'), findsOneWidget);
    expect(find.text('You can still get a name today.'), findsOneWidget);
    expect(find.text('Watch a short ad'), findsOneWidget);
    expect(find.text('Field Guide · 7 days free'), findsOneWidget);
    expect(find.text('Key it out'), findsOneWidget);
    await tester.tap(find.text('Watch a short ad'));
    await tester.pumpAndSettle();
    expect(find.text('No names left'), findsNothing);
    expect(find.text('1 name left'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(named, 1);
  });

  testWidgets('ten names hides the ad', (tester) async {
    Names.setForTest(used: 10, grants: 5);
    await _open(tester, signedIn: true, onWatchAd: () async {});
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(find.text('All ten names are used this month'), findsOneWidget);
    expect(find.text('Watch a short ad'), findsNothing);
    expect(
      find.text('Names come back next month. The key and the book stay open.'),
      findsOneWidget,
    );
  });

  testWidgets('Field Guide still names when the month is used', (tester) async {
    Names.setForTest(used: 5);
    var named = 0;
    await _open(
      tester,
      fieldGuide: true,
      identify: (_, _) async {
        named += 1;
        return const [
          NameGuess(
            scientificName: 'Boletus edulis',
            probability: 0.8,
            commonNames: [],
          ),
        ];
      },
      onOpenSpecies: (_) {},
    );
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(named, 1);
    expect(Names.count.namesUsed, 5);
    expect(find.text('Watch a short ad'), findsNothing);
  });

  testWidgets('a guest name is one, then the shutter asks for an account', (
    tester,
  ) async {
    var named = 0;
    await _open(
      tester,
      onOpenSpecies: (_) {},
      identify: (_, _) async {
        named += 1;
        return const [
          NameGuess(
            scientificName: 'Boletus edulis',
            probability: 0.8,
            commonNames: [],
          ),
        ];
      },
    );
    expect(find.text('1 name left'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(named, 1);
    expect(Names.count.namesUsed, 0);
    expect(find.text('0 names left'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(named, 1);
    expect(find.text('Sign in for another name'), findsOneWidget);
    expect(
      find.text(
        'A guest has one name. An account has five a month, and five more from an ad.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Watch a short ad'), findsNothing);
    expect(find.text('Field Guide · 7 days free'), findsOneWidget);
    expect(find.text('Key it out'), findsOneWidget);
  });

  testWidgets('an empty reply does not use the guest name', (tester) async {
    await _open(tester, identify: (_, _) async => const []);
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(
      find.text("This photo didn't count. 1 name left."),
      findsOneWidget,
    );
    expect(find.text('1 name left'), findsWidgets);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('1 name left'), findsOneWidget);
  });

  testWidgets('the server count is not added again on the phone', (
    tester,
  ) async {
    await _open(
      tester,
      signedIn: true,
      onOpenSpecies: (_) {},
      identify: (_, _) async {
        Names.applyServer(
          signedIn: true,
          charged: true,
          anonymousFreeUsed: false,
          namesUsed: 1,
          adGrants: 0,
        );
        return const [
          NameGuess(
            scientificName: 'Boletus edulis',
            probability: 0.8,
            commonNames: [],
          ),
        ];
      },
    );
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(Names.count.namesUsed, 1);
  });

  testWidgets('a counted empty reply says the name was kept', (tester) async {
    await _open(
      tester,
      signedIn: true,
      identify: (_, _) async {
        Names.applyServer(
          signedIn: true,
          charged: true,
          anonymousFreeUsed: false,
          namesUsed: 4,
          adGrants: 0,
        );
        return const [];
      },
    );
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(find.textContaining("this one counted"), findsOneWidget);
    expect(find.textContaining('1 name left'), findsWidgets);
    expect(Names.count.namesUsed, 4);
  });

  testWidgets('a refused name opens the limit sheet', (tester) async {
    await _open(
      tester,
      signedIn: true,
      onWatchAd: () async {},
      identify: (_, _) async {
        Names.setForTest(used: 5);
        throw const NameRefused('no-names');
      },
    );
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(find.text('No names left'), findsOneWidget);
    expect(find.text('Watch a short ad'), findsOneWidget);
    expect(find.text('The photo could not be named.'), findsNothing);
  });

  testWidgets('a photo that is too soon asks to wait', (tester) async {
    await _open(
      tester,
      signedIn: true,
      identify: (_, _) async => throw const NameRefused('cooldown'),
    );
    await tester.tap(find.byKey(const Key('guide-camera-shutter')));
    await tester.pumpAndSettle();
    expect(
      find.text('Wait a moment, then take the next photo.'),
      findsOneWidget,
    );
    expect(find.text('No names left'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the key leaves the camera for Find', (tester) async {
    var keyed = false;
    await _open(tester, onKey: () => keyed = true);
    await tester.tap(find.byKey(const Key('guide-camera-key')));
    expect(keyed, isTrue);
  });

  testWidgets('Seen opens an outside find', (tester) async {
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'out',
          millis: DateTime.now().millisecondsSinceEpoch,
          outsideName: 'Agaricus augustus',
          spoken: 'the prince',
        ),
      ];
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _scope(
        notebook: notebook,
        child: MaterialApp(
          theme: guideTheme(Brightness.light),
          home: const Scaffold(body: SeenPage()),
        ),
      ),
    );
    await tester.tap(find.text('Agaricus augustus'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide-outside-page')), findsOneWidget);
    expect(find.text('Keep this name'), findsOneWidget);
  });
}

Catalog _catalog() {
  return buildCatalog(
    language: 'en',
    speciesDocs: [
      Doc('Boletus edulis', {
        'name': 'Boletus edulis',
        'taxonomy': {'family': 'Boletaceae', 'genus': 'Boletus'},
      }),
      Doc('Amanita muscaria', {
        'name': 'Amanita muscaria',
        'taxonomy': {'family': 'Amanitaceae', 'genus': 'Amanita'},
      }),
    ],
    local: const {},
    english: const {},
    synonyms: const {},
    taxa: const {},
    key: const {},
  );
}

Widget _scope({
  required Notebook notebook,
  required Widget child,
  GuideSettings? settings,
  void Function(int index)? onTab,
}) {
  final repository = CatalogRepository()
    ..data = _catalog()
    ..loading = false;
  return GuideScope(
    catalog: repository,
    notebook: notebook,
    settings: settings ?? GuideSettings(),
    reload: () async {},
    selectTab: onTab ?? (_) {},
    child: child,
  );
}

Future<void> _open(
  WidgetTester tester, {
  Notebook? notebook,
  GuideSettings? settings,
  bool? fieldGuide,
  bool? signedIn,
  Future<List<NameGuess>> Function(Uint8List jpeg, String language)? identify,
  void Function(String latin)? onOpenSpecies,
  VoidCallback? onKey,
  VoidCallback? onClose,
  Future<void> Function()? onWatchAd,
  void Function(int index)? onTab,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final book = notebook ?? Notebook();
  await tester.pumpWidget(
    _scope(
      notebook: book,
      settings: settings,
      onTab: onTab,
      child: MaterialApp(
        theme: guideTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CameraPage(
                      livePreview: (_) =>
                          const ColoredBox(color: Color(0xFF224422)),
                      pickPhoto: (_) async => '/tmp/mushroom-shot.jpg',
                      readPhoto: (_) async => Uint8List.fromList(const [1]),
                      identify: identify,
                      fieldGuide: fieldGuide,
                      signedIn: signedIn,
                      onOpenSpecies: onOpenSpecies,
                      onKey: onKey,
                      onClose: onClose,
                      onWatchAd: onWatchAd,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
