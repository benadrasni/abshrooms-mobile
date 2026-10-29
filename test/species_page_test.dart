import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/seen/species_sightings.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
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

  testWidgets('the gallery shows photos, then the plate', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _notebook(),
      illustration: 'plates/Boletus edulis@1600.webp',
      photos: const ['photos/one.webp', 'photos/two.webp'],
    );

    expect(find.text('2 photos'), findsOneWidget);
    expect(find.text('Plate'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('2 photos')).dx,
      lessThan(tester.getTopLeft(find.text('Plate')).dx),
    );
    expect(find.byKey(const Key('gallery-photo-0')), findsOneWidget);
    expect(find.byKey(const Key('gallery-plate')), findsNothing);
    expect(
      tester.widget<GuidePhoto>(find.byKey(const Key('gallery-photo-0'))).fit,
      BoxFit.cover,
    );
    expect(find.bySemanticsLabel('Boletus edulis, Tab 1 of 2'), findsOneWidget);
    expect(tester.getSize(find.byTooltip('Back')), const Size(48, 48));
    expect(
      tester.getSize(find.byTooltip('Mark as favorite')),
      const Size(48, 48),
    );
    expect(tester.getSize(find.byTooltip('Share')), const Size(48, 48));

    await tester.tap(find.text('Plate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('gallery-plate')), findsOneWidget);
    expect(find.byKey(const Key('gallery-photo-0')), findsNothing);
    final plate = tester.widget<GuidePhoto>(
      find.byKey(const Key('gallery-plate')),
    );
    expect(plate.fit, BoxFit.contain);
    expect(plate.background, GuideColors.light.plateWell);
    expect(find.bySemanticsLabel('Boletus edulis, Plate'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the name, facts, season, and jumps follow the plants page', (
    tester,
  ) async {
    await _pump(
      tester,
      _notebook(),
      extra: const {
        'author': 'Bull.',
        'edibility': 'choice',
        'fruitingFrom': 6,
        'fruitingTo': 10,
        'capWidthFromCm': 8,
        'capWidthToCm': 25,
        'stipeHeightFromCm': 8,
        'stipeHeightToCm': 20,
        'stipeThicknessFromCm': 2,
        'stipeThicknessToCm': 4,
      },
      text: const {
        'label': 'penny bun',
        'names': ['cep', 'king bolete'],
        'cap': 'A bun-shaped cap.',
      },
      size: const Size(390, 800),
    );

    expect(find.text('penny bun'), findsOneWidget);
    final binomial = find.text('Boletus edulis Bull.', findRichText: true);
    expect(binomial, findsOneWidget);
    expect(
      tester.widget<RichText>(binomial).text.toPlainText(),
      'Boletus edulis Bull.',
    );
    final also = find.text('Also called cep, king bolete');
    expect(also, findsOneWidget);
    expect(
      tester.getTopLeft(also).dy,
      greaterThan(tester.getTopLeft(binomial).dy),
    );

    expect(find.text('Cap'), findsWidgets);
    expect(find.text('Stipe'), findsOneWidget);
    expect(find.text('Edibility'), findsOneWidget);
    expect(find.text('8–25 cm'), findsOneWidget);
    expect(find.text('8–20 × 2–4 cm'), findsOneWidget);
    final choice = tester.widget<Text>(find.text('Choice'));
    expect(choice.style?.color, GuideColors.light.moss);
    expect(find.text('Season June–October'), findsOneWidget);

    BoxDecoration month(int index) {
      final box = tester.widget<Container>(
        find.byKey(ValueKey('guide-month-$index')),
      );
      return box.decoration! as BoxDecoration;
    }

    expect(month(1).color, GuideColors.light.paper2);
    expect(month(6).color, GuideColors.light.mossFill);
    expect(month(10).color, GuideColors.light.mossFill);
    expect(month(11).color, GuideColors.light.paper2);
    final now = DateTime.now().month;
    expect(
      month(now).border,
      Border.all(color: GuideColors.light.madder, width: 1.5),
    );

    final jump = find.byKey(const Key('guide-jump-cap'), skipOffstage: false);
    expect(jump, findsOneWidget);
    await tester.ensureVisible(jump);
    await tester.pumpAndSettle();
    await tester.tap(jump);
    await tester.pumpAndSettle();
    final body = find.text('A bun-shaped cap.');
    expect(body, findsOneWidget);
    expect(tester.getTopLeft(body).dy, lessThan(800));
  });

  testWidgets('the author sits beside the Latin title', (tester) async {
    await _pump(tester, _notebook(), extra: const {'author': 'Bull.'});

    final title = find.text('Boletus edulis Bull.', findRichText: true);
    expect(title, findsOneWidget);
    final line =
        (tester.widget<RichText>(title).text as TextSpan).children!.single
            as TextSpan;
    final author = line.children!.last as TextSpan;
    expect(author.text, ' Bull.');
    expect(author.style?.fontStyle, FontStyle.normal);
    expect(author.style?.fontFamily, GuideType.sans);
    expect(author.style?.fontSize, 14);
    expect(line.children!.first.toPlainText(), 'Boletus edulis');
    expect(find.text('Also called'), findsNothing);
  });

  testWidgets('Slovak facts use the season line and edibility label', (
    tester,
  ) async {
    await _pump(
      tester,
      _notebook(),
      language: 'sk',
      extra: const {
        'author': 'Bull.',
        'edibility': 'poisonous',
        'fruitingFrom': 6,
        'fruitingTo': 10,
      },
      text: const {
        'label': 'hríb smrekový',
        'names': ['hríb pravý'],
      },
    );

    expect(
      find.text('Boletus edulis Bull.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Aj hríb pravý'), findsOneWidget);
    expect(find.text('Jedlosť'), findsOneWidget);
    expect(find.text('Jedovatá'), findsOneWidget);
    expect(find.text('Obdobie jún–október'), findsOneWidget);
  });

  testWidgets('sources show four icons until the rest expand', (tester) async {
    await _pump(
      tester,
      _notebook(),
      text: const {
        'sourceUrls': [
          'https://t.co/daisy',
          'https://en.wikipedia.org/wiki/Bellis_perennis',
          'https://www.rhs.org.uk/plants/bellis',
          'https://pfaf.org/user/Plant.aspx?LatinName=Bellis+perennis',
          'https://www.gbif.org/species/3117424',
          'https://luontoportti.com/en/bellis',
          'https://www.wikidata.org/wiki/Q1',
          'https://commons.wikimedia.org/wiki/Bellis_perennis',
        ],
      },
      size: const Size(390, 4200),
    );

    expect(find.text('t.co'), findsOneWidget);
    expect(find.text('wikipedia'), findsOneWidget);
    expect(find.text('rhs.org.uk'), findsOneWidget);
    expect(find.text('pfaf.org'), findsOneWidget);
    expect(find.text('gbif.org'), findsNothing);
    expect(find.text('luontoportti.com'), findsNothing);
    expect(find.text('wikidata'), findsNothing);
    expect(find.text('commons'), findsNothing);
    expect(find.text('+4'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(
      find.text('Name records and the pages used for the text.'),
      findsNothing,
    );

    final title = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == 'Sources' &&
          widget.style?.fontSize == 19,
    );
    final short = tester.getRect(
      find.byKey(const ValueKey('https://t.co/daisy')),
    );
    final last = tester.getRect(
      find.byKey(
        const ValueKey(
          'https://pfaf.org/user/Plant.aspx?LatinName=Bellis+perennis',
        ),
      ),
    );
    expect(short.top - tester.getRect(title).bottom, closeTo(8, 1));
    expect(last.top, closeTo(short.top, 1));
    expect(short.width, greaterThanOrEqualTo(48));
    expect(short.height, greaterThanOrEqualTo(48));
    final more = tester.getRect(find.byKey(const Key('guide-sources-more')));
    expect(more.top - last.bottom, closeTo(8, 1));
    expect(more.width, greaterThanOrEqualTo(48));
    expect(more.height, greaterThanOrEqualTo(48));

    final globe = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('https://t.co/daisy')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (globe.image as AssetImage).assetName,
      'assets/sources/internet.png',
    );
    expect(globe.color, GuideColors.light.ink);
    expect(globe.colorBlendMode, BlendMode.srcIn);

    await tester.ensureVisible(find.byKey(const Key('guide-sources-more')));
    await tester.tap(find.byKey(const Key('guide-sources-more')));
    await tester.pump();

    expect(find.text('gbif.org'), findsOneWidget);
    expect(find.text('luontoportti.com'), findsOneWidget);
    expect(find.text('wikidata'), findsOneWidget);
    expect(find.text('commons'), findsOneWidget);
    expect(find.text('+4'), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    final plate = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('https://luontoportti.com/en/bellis')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (plate.image as AssetImage).assetName,
      'assets/sources/luontoportti.png',
    );

    await tester.tap(find.byKey(const Key('guide-sources-more')));
    await tester.pump();

    expect(find.text('wikidata'), findsNothing);
    expect(find.text('+4'), findsOneWidget);
  });

  testWidgets('taxonomy lists the seven nearest ranks and hides synonyms', (
    tester,
  ) async {
    await _pump(
      tester,
      _notebook(),
      extra: const {
        'taxonomy': {
          'kingdom': 'Fungi',
          'subkingdom': 'Dikarya',
          'phylum': 'Basidiomycota',
          'subphylum': 'Agaricomycotina',
          'class': 'Agaricomycetes',
          'subclass': 'Agaricomycetidae',
          'order': 'Boletales',
          'family': 'Boletaceae',
          'genus': 'Boletus',
        },
      },
      taxa: const {'Boletaceae': 'bolete family'},
      synonyms: const {
        'Boletus edulis': {
          'homotypic': [
            {'name': 'Agaricus bulbosus', 'author': 'Bull.'},
          ],
        },
      },
      size: const Size(390, 4200),
    );

    expect(
      find.text('Taxonomy  Index Fungorum', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Genus Boletus', findRichText: true), findsOneWidget);
    expect(
      find.text('Family Boletaceae · bolete family', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Phylum Basidiomycota', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Kingdom', findRichText: true), findsNothing);
    expect(find.textContaining('Fungi', findRichText: true), findsNothing);
    expect(find.textContaining('Dikarya', findRichText: true), findsNothing);
    expect(find.text('Show all ranks'), findsNothing);
    expect(find.text('Synonyms'), findsNothing);
    expect(find.text('Agaricus bulbosus'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Genus Boletus', findRichText: true)).dy,
      lessThan(
        tester
            .getTopLeft(
              find.text(
                'Family Boletaceae · bolete family',
                findRichText: true,
              ),
            )
            .dy,
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('guide-taxon-family')),
    );
    await tester.tap(find.byKey(const ValueKey('guide-taxon-family')));
    await tester.pumpAndSettle();
    expect(find.text('Mushrooms in this family.'), findsOneWidget);
  });

  testWidgets('Slovak taxonomy uses the rank labels', (tester) async {
    await _pump(
      tester,
      _notebook(),
      language: 'sk',
      extra: const {
        'taxonomy': {'family': 'Boletaceae', 'genus': 'Boletus'},
      },
      taxa: const {'Boletaceae': 'Hríbovité'},
      size: const Size(390, 4200),
    );

    expect(
      find.text('Taxonómia  Index Fungorum', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('čeľaď Boletaceae · hríbovité', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('rod Boletus', findRichText: true), findsOneWidget);
    expect(find.text('Synonymá'), findsNothing);
  });

  test('public sightings keep a country and the newest photo first', () {
    final rows = speciesSightingsFromDocs([
      (
        id: 'old',
        data: {
          'status': 'public',
          'photo': 'sightings/u/old.jpg',
          'millis': 1000,
          'country': 'SK',
        },
      ),
      (
        id: 'new',
        data: {
          'status': 'public',
          'photo': 'sightings/u/new.jpg',
          'millis': 2000,
        },
      ),
      (
        id: 'review',
        data: {
          'status': 'review',
          'photo': 'sightings/u/review.jpg',
          'millis': 3000,
        },
      ),
    ]);

    expect(rows.map((row) => row.id), ['new', 'old']);
    expect(rows.last.country, 'sk');
    final url = Uri.parse(rows.first.url);
    expect(url.host, 'firebasestorage.googleapis.com');
    expect(url.path, contains('abshrooms-a9d4c.firebasestorage.app'));
    expect(rows.first.url, contains('sightings%2Fu%2Fnew.jpg'));
    expect(url.queryParameters.containsKey('token'), isFalse);
  });

  testWidgets('sightings sit above sources', (tester) async {
    final when = DateTime(2021, 4, 3).millisecondsSinceEpoch;
    await _pump(
      tester,
      _notebook(),
      text: const {
        'sourceUrls': ['https://example.com/a'],
      },
      sightings: (_) async => [
        SpeciesSighting(
          id: 'a',
          url: 'https://example.com/sighting.jpg',
          when: DateTime.fromMillisecondsSinceEpoch(when),
          country: 'sk',
        ),
        const SpeciesSighting(id: 'b', url: 'https://example.com/other.jpg'),
      ],
      size: const Size(390, 4200),
    );
    await tester.pump();

    expect(
      find.text('Sightings  2 shared by app users', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('April 2021'), findsOneWidget);
    expect(find.text('Slovakia'), findsOneWidget);
    expect(
      find.text(
        'Country and month only. Photos under CC0, reviewed before they appear.',
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('guide-species-sightings'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('https://example.com/a')))
            .dy,
      ),
    );

    await tester.ensureVisible(find.byKey(const ValueKey('guide-sighting-a')));
    await tester.tap(find.byKey(const ValueKey('guide-sighting-a')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('an empty sightings list says to share one from Seen', (
    tester,
  ) async {
    await _pump(
      tester,
      _notebook(),
      sightings: (_) async => const [],
      size: const Size(390, 2400),
    );
    await tester.pump();

    expect(
      find.text('No public sightings yet. Share one from Seen.'),
      findsOneWidget,
    );
    expect(find.text('2 shared by app users'), findsNothing);
  });

  testWidgets('Slovak gallery pills use the plants wording', (tester) async {
    await _pump(
      tester,
      _notebook(),
      language: 'sk',
      illustration: 'plates/Boletus edulis@1600.webp',
      photos: const ['photos/one.webp'],
    );

    expect(find.text('1 fotografia'), findsOneWidget);
    expect(find.text('Ilustrácia'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('1 fotografia')).dx,
      lessThan(tester.getTopLeft(find.text('Ilustrácia')).dx),
    );
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
  String illustration = '',
  List<String> photos = const [],
  Map<String, dynamic> extra = const {},
  Map<String, dynamic>? text,
  Map<String, String> taxa = const {},
  Map<String, Map<String, dynamic>> synonyms = const {},
  Future<List<SpeciesSighting>> Function(String latin)? sightings,
  Size size = const Size(800, 1600),
}) async {
  tester.view.physicalSize = size;
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
          'illustrationUrl': illustration,
          'photoUrls': photos,
          ...extra,
        }),
      ],
      local: text == null ? const {} : {'Boletus edulis': text},
      english: const {},
      synonyms: synonyms,
      taxa: taxa,
      key: const {},
    )
    ..loading = false;
  final page = SpeciesPage(
    latin: 'Boletus edulis',
    pickSeen: pick,
    loadSightings: sightings,
  );
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
