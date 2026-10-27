import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/seen/stats.dart';
import 'package:whats_that_mushroom/seen/stats_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

void main() {
  test('notebook counts skip a nameless row and a find still in review', () {
    final stats = notebookStats(
      [
        FindRecord(
          id: 'b',
          millis: DateTime(2026, 6, 1).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
        ),
        FindRecord(
          id: 'a',
          millis: DateTime(2026, 6, 1).millisecondsSinceEpoch,
          latin: 'Amanita muscaria',
          confirmed: true,
          share: FindShare.shared,
        ),
        FindRecord(
          id: 'c',
          millis: DateTime(2021, 3, 2).millisecondsSinceEpoch,
          outsideName: 'Agaricus augustus',
          spoken: 'the prince',
        ),
        FindRecord(
          id: 'd',
          millis: DateTime(2026, 8, 1).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
          share: FindShare.review,
        ),
        FindRecord(
          id: 'e',
          millis: DateTime(2020, 4, 1).millisecondsSinceEpoch,
          confirmed: true,
        ),
      ],
      countryOf: (find) => find.id == 'a'
          ? ' SK '
          : find.id == 'b'
          ? 'nope'
          : null,
    );

    expect(stats.finds, 4);
    expect(stats.mushrooms, 3);
    expect(stats.shared, 1);
    expect(stats.unconfirmed, 1);
    expect(stats.unplaced, 3);
    expect(stats.first!.name, 'Agaricus augustus');
    expect(stats.first!.spoken, 'the prince');
    expect(stats.last!.name, 'Boletus edulis');
    expect(stats.years.map((year) => year.year), [2021, 2026]);
    expect(stats.years.last.count, 3);
    expect(stats.countries.single.code, 'sk');
    expect(stats.most.map((mushroom) => mushroom.name), ['Boletus edulis']);
    expect(stats.most.single.count, 2);
  });

  test('each mushroom once means there is no most seen', () {
    final stats = notebookStats([
      FindRecord(
        id: 'a',
        millis: DateTime(2021, 3, 2).millisecondsSinceEpoch,
        latin: 'Boletus edulis',
        confirmed: true,
      ),
      FindRecord(
        id: 'b',
        millis: DateTime(2026, 5, 1).millisecondsSinceEpoch,
        latin: 'Amanita muscaria',
        confirmed: true,
      ),
    ]);
    expect(stats.most, isEmpty);
    expect(stats.mushrooms, 2);
    expect(stats.countries, isEmpty);
    expect(stats.unplaced, 2);
  });

  test('a tie above one lists every most-seen mushroom', () {
    final stats = notebookStats([
      FindRecord(
        id: 'a',
        millis: DateTime(2026, 5, 1).millisecondsSinceEpoch,
        latin: 'Boletus edulis',
        confirmed: true,
      ),
      FindRecord(
        id: 'b',
        millis: DateTime(2026, 6, 1).millisecondsSinceEpoch,
        latin: 'Boletus edulis',
        spoken: 'penny bun',
        confirmed: true,
      ),
      FindRecord(
        id: 'c',
        millis: DateTime(2026, 5, 2).millisecondsSinceEpoch,
        latin: 'Amanita muscaria',
        confirmed: true,
      ),
      FindRecord(
        id: 'd',
        millis: DateTime(2026, 6, 2).millisecondsSinceEpoch,
        latin: 'Amanita muscaria',
        confirmed: true,
      ),
      FindRecord(
        id: 'e',
        millis: DateTime(2026, 7, 1).millisecondsSinceEpoch,
        outsideName: 'Agaricus augustus',
        confirmed: true,
      ),
    ]);
    expect(stats.most.map((mushroom) => mushroom.name), [
      'Amanita muscaria',
      'Boletus edulis',
    ]);
    expect(stats.most.last.spoken, 'penny bun');
    expect(stats.most.last.count, 2);
  });

  test('the same instant keeps the earlier id as first', () {
    final when = DateTime(2024, 1, 1).millisecondsSinceEpoch;
    final stats = notebookStats([
      FindRecord(
        id: 'b',
        millis: when,
        latin: 'Amanita muscaria',
        confirmed: true,
      ),
      FindRecord(
        id: 'a',
        millis: when,
        latin: 'Boletus edulis',
        confirmed: true,
      ),
    ]);
    expect(stats.first!.name, 'Boletus edulis');
    expect(stats.last!.name, 'Amanita muscaria');
  });

  test('public rows keep the outdoor counts and drop a review document', () {
    expect(statCountry('Middle Europe'), isNull);
    expect(statCountry('gb'), 'gb');
    expect(statGrouped(1778, locale: 'en'), '1,778');
    expect(
      statGrouped(1778, locale: 'en'),
      NumberFormat.decimalPattern('en').format(1778),
    );
    expect(
      statGrouped(1778, locale: 'de'),
      NumberFormat.decimalPattern('de').format(1778),
    );
    expect(
      statGrouped(1778, locale: 'sk'),
      NumberFormat.decimalPattern('sk').format(1778),
    );
    expect(
      statGrouped(1778, locale: 'fr'),
      NumberFormat.decimalPattern('fr').format(1778),
    );
    expect(
      statGrouped(1234567, locale: 'hi'),
      NumberFormat.decimalPattern('hi').format(1234567),
    );
    expect(
      statGrouped(1778, locale: 'de'),
      isNot(statGrouped(1778, locale: 'sk')),
    );
    expect(statGrouped(1778, locale: 'de').contains(','), isFalse);

    final load = sightingsFromDocs([
      {
        'status': 'review',
        'latin': 'Fomes fomentarius',
        'millis': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'uid': 'ada',
        'country': 'sk',
      },
      {
        'latin': 'Boletus edulis',
        'millis': DateTime(2020, 6, 1).millisecondsSinceEpoch,
        'uid': 'ada',
        'country': 'GB',
      },
      {
        'status': 'public',
        'latin': 'Boletus edulis',
        'millis': DateTime(2021, 6, 1).millisecondsSinceEpoch,
        'uid': 'bea',
        'country': 'gb',
      },
      {
        'status': 'public',
        'latin': 'Amanita muscaria',
        'millis': DateTime(2019, 5, 1).millisecondsSinceEpoch,
        'uid': 'ada',
      },
      {
        'status': 'public',
        'latin': ' ',
        'millis': DateTime(2018, 1, 1).millisecondsSinceEpoch,
        'uid': 'cy',
      },
    ]);
    final headline = load.headline!;
    expect(headline.count, 3);
    expect(headline.mushrooms, 2);
    expect(headline.people, 2);
    expect(headline.firstName, 'Amanita muscaria');
    expect(headline.lastName, 'Boletus edulis');
    expect(headline.mostName, 'Boletus edulis');
    expect(headline.mostCount, 2);
    expect(headline.countries.single.code, 'gb');
    expect(headline.countries.single.count, 2);
    expect(load.years.map((year) => year.year), [2019, 2020, 2021]);
  });

  test('an empty public list has no headline', () {
    final load = sightingsFromDocs(const <Map<String, dynamic>>[]);
    expect(load.headline, isNull);
    expect(load.years, isEmpty);
  });

  test('english and slovak statistics strings match the plants forms', () {
    final en = Copy('en');
    expect(en.statsFinds(1), 'Find');
    expect(en.statsFinds(5), 'Finds');
    expect(en.statsMushrooms(1), 'Mushroom');
    expect(en.statsMushrooms(5), 'Mushrooms');
    expect(en.statsShared(1), 'Shared');
    expect(en.statsShared(5), 'Shared');
    expect(en.statsDay(DateTime(2026, 10, 1)), 'Oct 1, 2026');
    expect(en.statsPlace('5', 1), contains('1 shared find'));
    expect(
      en.statsNoPlace(1),
      'One find has no place, so it isn’t in a country.',
    );

    final sk = Copy('sk');
    expect(sk.statsFinds(1), 'Nález');
    expect(sk.statsFinds(2), 'Nálezy');
    expect(sk.statsFinds(4), 'Nálezy');
    expect(sk.statsFinds(5), 'Nálezov');
    expect(sk.statsFinds(0), 'Nálezov');
    expect(sk.statsMushrooms(1), 'Huba');
    expect(sk.statsMushrooms(3), 'Huby');
    expect(sk.statsMushrooms(5), 'Húb');
    expect(sk.statsMushrooms(0), 'Húb');
    expect(sk.statsShared(1), 'Zdieľaný');
    expect(sk.statsShared(2), 'Zdieľané');
    expect(sk.statsShared(5), 'Zdieľaných');
    expect(sk.statsShared(0), 'Zdieľaných');
    expect(sk.statsDay(DateTime(2026, 10, 1)), '1. okt 2026');
    expect(sk.statsPlace('5', 1), contains('1 zdieľaný nález'));
    expect(sk.statsPlace('5', 3), contains('3 zdieľané nálezy'));
    expect(sk.statsPlace('5', 10), contains('10 zdieľaných nálezov'));
    expect(sk.statsSightingTimes(1), '1 pozorovanie');
    expect(sk.statsSightingTimes(3), '3 pozorovania');
    expect(sk.statsSightingTimes(5), '5 pozorovaní');
    expect(sk.statsToConfirm(1), 'Vrátane 1, ktorý ešte treba potvrdiť.');
    expect(sk.statistics, 'Štatistika');
  });

  testWidgets('a mushroom in the book opens, and one outside does not', (
    tester,
  ) async {
    final opened = <String>[];
    await _pump(
      tester,
      StatsPage(
        loadSightings: () async =>
            const SightingsLoad(headline: null, years: []),
        onOpen: (_, name) => opened.add(name),
      ),
      finds: [
        FindRecord(
          id: 'a',
          millis: DateTime(2026, 5, 1).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
        ),
        FindRecord(
          id: 'b',
          millis: DateTime(2026, 6, 1).millisecondsSinceEpoch,
          outsideName: 'Agaricus augustus',
          spoken: 'the prince',
          confirmed: true,
        ),
      ],
    );

    expect(find.text('penny bun'), findsWidgets);
    expect(find.text('the prince'), findsWidgets);
    expect(find.text('Includes 0 still to confirm.'), findsNothing);

    await tester.tap(find.text('penny bun').first);
    await tester.pump();
    expect(opened, ['Boletus edulis']);

    await tester.tap(find.text('the prince'));
    await tester.pump();
    expect(find.text('Not in the book'), findsOneWidget);
    expect(opened, ['Boletus edulis']);
  });

  testWidgets('the default open pushes the species page', (tester) async {
    await _pump(
      tester,
      StatsPage(
        loadSightings: () async =>
            const SightingsLoad(headline: null, years: []),
      ),
      finds: [
        FindRecord(
          id: 'a',
          millis: DateTime(2026, 5, 1).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
        ),
      ],
    );
    await tester.tap(find.text('penny bun').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SpeciesPage), findsOneWidget);
  });

  testWidgets('a country on a find is listed, and a missing one is named', (
    tester,
  ) async {
    await _pump(
      tester,
      StatsPage(
        loadSightings: () async =>
            const SightingsLoad(headline: null, years: []),
        countryOf: (find) => find.id == 'a' ? 'sk' : null,
      ),
      finds: [
        FindRecord(
          id: 'a',
          millis: DateTime(2026, 5, 1).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
        ),
        FindRecord(
          id: 'b',
          millis: DateTime(2026, 6, 1).millisecondsSinceEpoch,
          latin: 'Amanita muscaria',
          confirmed: true,
        ),
      ],
    );
    expect(find.text('BY COUNTRY · 1'), findsOneWidget);
    expect(find.text('Slovakia'), findsOneWidget);
    expect(
      find.text('One find has no place, so it isn’t in a country.'),
      findsOneWidget,
    );
  });

  testWidgets('sightings show the headline and a failed load can be retried', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      StatsPage(
        sightings: true,
        loadSightings: () async {
          calls++;
          if (calls == 1) throw StateError('offline');
          return SightingsLoad(
            headline: SightingHeadline(
              count: 2,
              mushrooms: 1,
              people: 2,
              firstName: 'Boletus edulis',
              firstWhen: DateTime(2020, 6, 1),
              lastName: 'Boletus edulis',
              lastWhen: DateTime(2021, 6, 1),
              mostName: 'Boletus edulis',
              mostCount: 2,
              countries: const [StatCountry('de', 1), StatCountry('sk', 2)],
            ),
            years: const [StatYear(2020, 1), StatYear(2021, 1)],
          );
        },
      ),
      finds: [
        FindRecord(
          id: 'a',
          millis: DateTime(2026, 5, 1).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
          confirmed: true,
          share: FindShare.shared,
        ),
      ],
    );
    await tester.pump();
    expect(find.text('Couldn’t load Sightings'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guide-stats-retry')));
    await tester.pump();
    expect(find.text('Sightings'), findsWidgets);
    expect(find.text('penny bun'), findsWidgets);
    expect(find.text('2 sightings'), findsOneWidget);
    expect(find.text('Slovakia'), findsOneWidget);
    expect(find.text('Germany'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
    expect(find.textContaining('1 shared find'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('slovak copy is on the page, and countries sit in two columns', (
    tester,
  ) async {
    await _pump(
      tester,
      StatsPage(
        sightings: true,
        fromSeen: true,
        loadSightings: () async => SightingsLoad(
          headline: const SightingHeadline(
            count: 4,
            mushrooms: 2,
            people: 3,
            firstName: 'Amanita muscaria',
            firstWhen: null,
            lastName: 'Boletus edulis',
            lastWhen: null,
            mostName: 'Boletus edulis',
            mostCount: 3,
            countries: [StatCountry('sk', 2), StatCountry('de', 2)],
          ),
          years: const [],
        ),
      ),
      language: 'sk',
      size: const Size(1200, 800),
      finds: [
        FindRecord(
          id: 'wait',
          millis: DateTime(2026, 5, 1).millisecondsSinceEpoch,
          latin: 'Boletus edulis',
        ),
      ],
    );
    await tester.pump();

    expect(find.text('ŠTATISTIKA'), findsOneWidget);
    expect(find.text('Pozorovania'), findsWidgets);
    expect(find.text('Nálezy'), findsWidgets);
    expect(find.text('hríb smrekový'), findsWidgets);
    expect(find.text('3 pozorovania'), findsOneWidget);
    expect(
      find.textContaining('Vrátane 1, ktorý ešte treba potvrdiť.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('guide-stats-yours')));
    await tester.pump();
    expect(
      find.textContaining('Vrátane 1, ktorý ešte treba potvrdiť.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('guide-stats-sightings')));
    await tester.pump();
    final germany = tester.getTopLeft(find.text('Nemecko'));
    final slovakia = tester.getTopLeft(find.text('Slovensko'));
    expect(germany.dx, isNot(slovakia.dx));
  });

  testWidgets('a slow sightings load shows the spinner, then the empty line', (
    tester,
  ) async {
    final pending = Completer<SightingsLoad>();
    await _pump(
      tester,
      StatsPage(sightings: true, loadSightings: () => pending.future),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const SightingsLoad(headline: null, years: []));
    await tester.pump();
    expect(
      find.text('No public sightings yet. Share one from Seen.'),
      findsOneWidget,
    );
  });

  testWidgets('german finds group thousands in german', (tester) async {
    final german = statGrouped(1778, locale: 'de');
    final slovak = statGrouped(1778, locale: 'sk');
    await _pump(
      tester,
      StatsPage(
        loadSightings: () async =>
            const SightingsLoad(headline: null, years: []),
        countryOf: (_) => 'de',
      ),
      language: 'de',
      finds: [
        for (var i = 0; i < 1778; i++)
          FindRecord(
            id: '$i',
            millis: DateTime(
              i < 900 ? 2019 : 2020,
              6,
              1,
            ).millisecondsSinceEpoch,
            latin: 'Boletus edulis',
            confirmed: true,
          ),
      ],
    );
    expect(find.text(german), findsWidgets);
    expect(find.text(slovak), findsNothing);
  });

  testWidgets('german sightings group thousands in german', (tester) async {
    final german = statGrouped(1778, locale: 'de');
    final slovak = statGrouped(1778, locale: 'sk');
    await _pump(
      tester,
      StatsPage(
        sightings: true,
        loadSightings: () async => const SightingsLoad(
          headline: SightingHeadline(
            count: 1778,
            mushrooms: 2,
            people: 3,
            firstName: 'Boletus edulis',
            firstWhen: null,
            lastName: 'Amanita muscaria',
            lastWhen: null,
            mostName: 'Boletus edulis',
            mostCount: 2,
            countries: [StatCountry('de', 1778)],
          ),
          years: [StatYear(2020, 2)],
        ),
      ),
      language: 'de',
    );
    await tester.pump();
    expect(find.text(german), findsWidgets);
    expect(find.text(slovak), findsNothing);
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
  Widget page, {
  String language = 'en',
  List<FindRecord> finds = const [],
  Size size = const Size(800, 1600),
}) async {
  tester.view.physicalSize = size;
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
      notebook: Notebook()..finds = finds,
      settings: settings,
      reload: () async {},
      selectTab: (_) {},
      child: MaterialApp(
        theme: guideTheme(Brightness.light),
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('sk'), Locale('de')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          CountryLocalizations.delegate,
        ],
        home: page,
      ),
    ),
  );
  await tester.pump();
}
