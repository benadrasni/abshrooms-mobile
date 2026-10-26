import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/camera/camera_page.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/field_guide/field_guide_page.dart';
import 'package:whats_that_mushroom/person/sign_in_page.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/seen/seen_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  setUp(Purchases.resetForTest);
  tearDown(Purchases.resetForTest);

  testWidgets('an empty notebook keeps the title, camera, and Field Guide', (
    tester,
  ) async {
    await _pump(tester, Notebook());

    expect(find.text('Seen'), findsOneWidget);
    expect(find.text('0 finds · on this phone'), findsOneWidget);
    expect(find.text('Finds you save will show up here.'), findsOneWidget);
    expect(find.byKey(const Key('guide-seen-camera')), findsOneWidget);
    expect(find.byKey(const Key('guide-seen-stats')), findsOneWidget);
    expect(find.byKey(const Key('guide-seen-upsell')), findsOneWidget);
    expect(
      find.text('Unlimited names from photos, no ads, and the book offline.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('guide-seen-upsell')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FieldGuidePage), findsOneWidget);
  });

  testWidgets('the chart opens statistics for the notebook', (tester) async {
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'a',
          millis: DateTime(2026, 5, 2).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
        ),
        FindRecord(
          id: 'b',
          millis: DateTime(2026, 6, 1).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
          share: FindShare.shared,
        ),
      ];
    await _pump(tester, notebook);
    await tester.tap(find.byKey(const Key('guide-seen-stats')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('STATISTICS'), findsOneWidget);
    expect(find.text('Your finds'), findsWidgets);
    expect(find.text('penny bun'), findsWidgets);
    expect(find.text('May 2, 2026'), findsOneWidget);
    expect(find.text('Jun 1, 2026'), findsOneWidget);
    expect(find.text('2 finds'), findsOneWidget);
    expect(
      find.text('Each mushroom once, so none is most seen.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('guide-stats-sightings')));
    await tester.pump();
    expect(
      find.text('No public sightings yet. Share one from Seen.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('guide-stats-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('0 finds · on this phone'), findsNothing);
    expect(find.text('2 finds · on this phone'), findsOneWidget);
  });

  testWidgets('Field Guide hides the card at the bottom', (tester) async {
    Purchases.replaceAccountProducts({fieldGuideMonthlyPlay});
    await _pump(tester, Notebook());
    expect(find.byKey(const Key('guide-seen-upsell')), findsNothing);
  });

  testWidgets('unconfirmed finds sit above the months', (tester) async {
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'old',
          millis: DateTime(2026, 9, 2).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
        ),
        FindRecord(
          id: 'new',
          millis: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          latin: 'Amanita muscaria',
          confirmed: true,
        ),
        FindRecord(
          id: 'wait',
          millis: DateTime(2026, 10, 25).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          probability: 0.8,
        ),
      ];
    await _pump(tester, notebook);

    expect(find.text('3 finds · on this phone'), findsOneWidget);
    expect(find.text('TO CONFIRM · 1'), findsOneWidget);
    expect(find.text('LIKELY'), findsOneWidget);
    expect(find.text('penny bun'), findsWidgets);
    expect(find.text('OCTOBER 2026'), findsOneWidget);
    expect(find.text('SEPTEMBER 2026'), findsOneWidget);
    expect(find.text('Oct 1'), findsOneWidget);
    expect(find.text('Sep 2'), findsOneWidget);

    final confirm = tester.getTopLeft(find.text('TO CONFIRM · 1'));
    final october = tester.getTopLeft(find.text('OCTOBER 2026'));
    final september = tester.getTopLeft(find.text('SEPTEMBER 2026'));
    expect(confirm.dy, lessThan(october.dy));
    expect(october.dy, lessThan(september.dy));

    await tester.tap(find.byKey(const Key('guide-seen-confirm-wait')));
    await tester.pump();
    expect(find.text('Confirmed.'), findsOneWidget);
    expect(find.text('TO CONFIRM · 1'), findsNothing);
    expect(
      notebook.finds.where((item) => item.id == 'wait').single.confirmed,
      isTrue,
    );
  });

  testWidgets('Another keeps a name from the book and confirms it', (
    tester,
  ) async {
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'wait',
          millis: DateTime(2026, 10, 25).millisecondsSinceEpoch,
          outsideName: 'Agaricus augustus',
          spoken: 'the prince',
          probability: 0.4,
          others: const [
            FindName(scientificName: 'Amanita muscaria', probability: 0.3),
          ],
        ),
      ];
    await _pump(tester, notebook);

    expect(find.text('the prince'), findsOneWidget);
    expect(find.text('POSSIBLE'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-seen-another-wait')));
    await tester.pumpAndSettle();
    expect(find.text('Which one is it?'), findsOneWidget);

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.text('Changed and confirmed.'), findsOneWidget);
    expect(find.text('TO CONFIRM · 1'), findsNothing);
    expect(find.text('fly agaric'), findsOneWidget);
    final kept = notebook.finds.single;
    expect(kept.latin, 'Amanita muscaria');
    expect(kept.confirmed, isTrue);
    expect(kept.outsideName, isNull);
  });

  testWidgets('a confirmed find asks before it leaves Seen', (tester) async {
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'kept',
          millis: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
        ),
      ];
    await _pump(tester, notebook);

    await tester.tap(find.byKey(const Key('guide-seen-row-delete-kept')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this find?'), findsOneWidget);
    expect(find.text('It leaves your Seen.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guide-seen-delete-confirm')));
    await tester.pump();
    expect(find.text('Deleted from Seen.'), findsOneWidget);
    expect(notebook.finds, isEmpty);
  });

  testWidgets('an unconfirmed find deletes without asking again', (
    tester,
  ) async {
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'wait',
          millis: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
        ),
      ];
    await _pump(tester, notebook);

    await tester.tap(find.byKey(const Key('guide-seen-delete-wait')));
    await tester.pump();
    expect(find.text('Delete this find?'), findsNothing);
    expect(find.text('Deleted from Seen.'), findsOneWidget);
    expect(notebook.finds, isEmpty);
  });

  testWidgets('a confirmed name outside the book opens its page', (
    tester,
  ) async {
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'out',
          millis: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          outsideName: 'Agaricus augustus',
          confirmed: true,
        ),
      ];
    await _pump(tester, notebook);

    expect(find.text('Not in the book'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-seen-outside-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide-outside-page')), findsOneWidget);
  });

  testWidgets('Slovak counts and months follow the plants page', (
    tester,
  ) async {
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'one',
          millis: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
        ),
        FindRecord(
          id: 'two',
          millis: DateTime(2026, 10, 4).millisecondsSinceEpoch,
          latin: 'Amanita muscaria',
          confirmed: true,
        ),
      ];
    await _pump(tester, notebook, language: 'sk');

    expect(find.text('Nálezy'), findsOneWidget);
    expect(find.text('2 nálezy · na tomto telefóne'), findsOneWidget);
    expect(find.text('OKTÓBER 2026'), findsOneWidget);
    expect(find.text('3. okt'), findsOneWidget);
    expect(find.text('4. okt'), findsOneWidget);
  });

  testWidgets('the camera button opens the viewfinder', (tester) async {
    await _pump(tester, Notebook());
    await tester.tap(find.byKey(const Key('guide-seen-camera')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CameraPage), findsOneWidget);
  });

  testWidgets('a find with no photo file has no Share', (tester) async {
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'kept',
          millis: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          photoPath: '/tmp/missing-mushroom-photo.jpg',
          confirmed: true,
        ),
      ];
    await _pump(tester, notebook, signedIn: true);
    expect(find.text('Share'), findsNothing);
    expect(find.text('penny bun'), findsOneWidget);
  });

  testWidgets('Share asks for consent, then marks the find in review', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('seen-page');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = File('${dir.path}/kept.jpg')..writeAsStringSync('photo');
    final shared = <String>[];
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'kept',
          millis: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          photoPath: photo.path,
          confirmed: true,
        ),
      ];
    await _pump(
      tester,
      notebook,
      signedIn: true,
      onShare: (find) async {
        shared.add(find.id);
        return true;
      },
    );

    expect(find.text('Share'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-seen-share-kept')));
    await tester.pumpAndSettle();
    expect(find.text('Share penny bun'), findsOneWidget);
    expect(find.text('Boletus edulis'), findsOneWidget);
    expect(find.text('Send for review'), findsOneWidget);
    final send = tester.widget<FilledButton>(
      find.byKey(const Key('guide-seen-send')),
    );
    expect(send.onPressed, isNull);

    await tester.tap(find.byKey(const Key('guide-seen-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('guide-seen-send')));
    await tester.pumpAndSettle();
    expect(shared, ['kept']);
    expect(find.text('Sent for review.'), findsOneWidget);
    expect(notebook.finds.single.share, FindShare.review);
    expect(find.text('In review'), findsOneWidget);
  });

  testWidgets('a guest is sent to sign in', (tester) async {
    final dir = Directory.systemTemp.createTempSync('seen-guest');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = File('${dir.path}/kept.jpg')..writeAsStringSync('photo');
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'kept',
          millis: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          photoPath: photo.path,
          confirmed: true,
        ),
      ];
    await _pump(tester, notebook, signedIn: false);
    await tester.tap(find.byKey(const Key('guide-seen-share-kept')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('Share penny bun'), findsNothing);
  });

  testWidgets('a shared find can be withdrawn and hidden', (tester) async {
    final withdrawn = <String>[];
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'kept',
          millis: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
          share: FindShare.shared,
        ),
        FindRecord(
          id: 'other',
          millis: DateTime(2026, 10, 4).millisecondsSinceEpoch,
          latin: 'Amanita muscaria',
          confirmed: true,
        ),
      ];
    await _pump(
      tester,
      notebook,
      signedIn: true,
      onWithdraw: (find) async {
        withdrawn.add(find.id);
        return true;
      },
    );

    expect(find.text('Hide shared · 1'), findsOneWidget);
    expect(find.text('2 finds · on this phone'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-seen-hide-shared')));
    await tester.pump();
    expect(find.text('Shared hidden · 1'), findsOneWidget);
    expect(
      find.text('1 find · 1 shared hidden · on this phone'),
      findsOneWidget,
    );
    expect(find.text('penny bun'), findsNothing);
    expect(find.text('fly agaric'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guide-seen-hide-shared')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('guide-seen-shared-kept')));
    await tester.pumpAndSettle();
    expect(find.text('penny bun is a Sighting'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-seen-withdraw')));
    await tester.pumpAndSettle();
    expect(withdrawn, ['kept']);
    expect(find.text('Withdrawn from Sightings.'), findsOneWidget);
    expect(
      notebook.finds.singleWhere((item) => item.id == 'kept').share,
      FindShare.none,
    );
  });

  testWidgets('deleting a sent find removes the copy that was sent', (
    tester,
  ) async {
    final removed = <String>[];
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'kept',
          millis: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
          share: FindShare.review,
        ),
      ];
    await _pump(
      tester,
      notebook,
      signedIn: true,
      onRemoveSent: (find) async {
        removed.add(find.id);
        return true;
      },
    );
    await tester.tap(find.byKey(const Key('guide-seen-row-delete-kept')));
    await tester.pumpAndSettle();
    expect(
      find.text('It leaves your Seen. The copy you sent goes too.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('guide-seen-delete-confirm')));
    await tester.pump();
    expect(removed, ['kept']);
    expect(notebook.finds, isEmpty);
  });
}

Catalog _catalog(String language) {
  return buildCatalog(
    language: language,
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
    local: {
      'Boletus edulis': {
        'label': language == 'sk' ? 'hríb smrekový' : 'penny bun',
      },
      'Amanita muscaria': {
        'label': language == 'sk' ? 'muchotrávka červená' : 'fly agaric',
      },
    },
    english: const {},
    synonyms: const {},
    taxa: const {},
    key: const {},
  );
}

Future<void> _pump(
  WidgetTester tester,
  Notebook notebook, {
  String language = 'en',
  bool? signedIn,
  Future<bool> Function(FindRecord find)? onShare,
  Future<bool> Function(FindRecord find)? onWithdraw,
  Future<bool> Function(FindRecord find)? onRemoveSent,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final settings = GuideSettings()..language = language;
  final repository = CatalogRepository()
    ..data = _catalog(language)
    ..loading = false;
  await tester.pumpWidget(
    GuideScope(
      catalog: repository,
      notebook: notebook,
      settings: settings,
      reload: () async {},
      selectTab: (_) {},
      child: MaterialApp(
        theme: guideTheme(Brightness.light),
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('sk')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SeenPage(
            signedIn: signedIn,
            onShare: onShare,
            onWithdraw: onWithdraw,
            onRemoveSent: onRemoveSent,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
