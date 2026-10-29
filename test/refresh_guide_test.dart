import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/refresh_guide.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/find/find_page.dart';
import 'package:whats_that_mushroom/seen/seen_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

Species _species(String name, {String added = ''}) {
  return Species(
    id: 1,
    name: name,
    author: '',
    family: '',
    genus: '',
    order: '',
    taxonomy: const {},
    edibility: '',
    hymenium: '',
    where: const [],
    colors: const [],
    fruitingFrom: null,
    fruitingTo: null,
    capFrom: null,
    capTo: null,
    stipeHeightFrom: null,
    stipeHeightTo: null,
    stipeThickFrom: null,
    stipeThickTo: null,
    illustrationUrl: '',
    photoUrls: const [],
    synonyms: const [],
    added: added,
  );
}

Catalog _catalog(List<Species> species) {
  return Catalog(
    language: 'en',
    species: species,
    local: const {},
    english: const {},
    taxa: const {},
  );
}

void main() {
  test('a refresh replaces the book and asks the server', () async {
    final next = _catalog([_species('Agaricus augustus', added: '2026-10-29')]);
    final repo = CatalogRepository(
      readCatalog: (language, {required bool server}) async {
        expect(language, 'en');
        expect(server, isTrue);
        return next;
      },
    )..data = _catalog([_species('Boletus edulis', added: '2026-10-22')]);

    expect(await repo.refresh(), isTrue);
    expect(repo.data, same(next));
    expect(repo.error, isNull);
    expect(repo.loading, isFalse);
  });

  test('a failed refresh keeps the book on screen', () async {
    final kept = _catalog([_species('Boletus edulis', added: '2026-10-22')]);
    final repo = CatalogRepository(
      readCatalog: (language, {required bool server}) async {
        expect(server, isTrue);
        throw StateError('offline');
      },
    )..data = kept;

    expect(await repo.refresh(), isFalse);
    expect(identical(repo.data, kept), isTrue);
    expect(repo.error, isNull);
    expect(repo.loading, isFalse);
  });

  test('a failed refresh with no book records the error', () async {
    final repo = CatalogRepository(
      readCatalog: (language, {required bool server}) async {
        throw StateError('offline');
      },
    );

    expect(await repo.refresh(), isFalse);
    expect(repo.data, isNull);
    expect(repo.error, isA<StateError>());
  });

  test('a refresh leaves the book up while the server answers', () async {
    final gate = Completer<Catalog>();
    final repo = CatalogRepository(
      readCatalog: (language, {required bool server}) => gate.future,
    )..data = _catalog([_species('Boletus edulis')]);

    final pending = repo.refresh();
    expect(repo.loading, isFalse);
    expect(repo.data!.species.single.name, 'Boletus edulis');
    gate.complete(_catalog([_species('Agaricus augustus')]));
    await pending;
    expect(repo.data!.species.single.name, 'Agaricus augustus');
  });

  test('a slower refresh does not replace a newer book', () async {
    final first = Completer<Catalog>();
    final second = Completer<Catalog>();
    var calls = 0;
    final repo = CatalogRepository(
      readCatalog: (language, {required bool server}) {
        calls += 1;
        return calls == 1 ? first.future : second.future;
      },
    );
    final older = repo.refresh();
    final newer = repo.refresh();
    second.complete(
      _catalog([_species('Agaricus augustus', added: '2026-10-29')]),
    );
    await newer;
    first.complete(_catalog([_species('Boletus edulis', added: '2026-10-22')]));
    await older;
    expect(repo.data!.species.single.name, 'Agaricus augustus');
  });

  test('a language reload wins over an older refresh', () async {
    final gate = Completer<Catalog>();
    final repo = CatalogRepository(
      readCatalog: (language, {required bool server}) async {
        if (server) return gate.future;
        return _catalog([_species('Suillus grevillei')]);
      },
    );
    final refreshing = repo.refresh();
    final loading = repo.load('sk');
    gate.complete(_catalog([_species('Boletus edulis')]));
    await refreshing;
    await loading;
    expect(repo.language, 'sk');
    expect(repo.data!.species.single.name, 'Suillus grevillei');
    expect(repo.loading, isFalse);
  });

  test('an open refresh adopts a name that is now in the book', () async {
    final notebook = Notebook()
      ..finds = const [
        FindRecord(
          id: 'out',
          millis: 5,
          outsideName: 'Agaricus augustus',
          confirmed: true,
        ),
      ];
    final repo = CatalogRepository(
      readCatalog: (language, {required bool server}) async {
        return _catalog([_species('Agaricus augustus', added: '2026-10-29')]);
      },
    )..data = _catalog([_species('Boletus edulis', added: '2026-10-22')]);
    Notebook? synced;
    await refreshOpenGuide(
      catalog: repo,
      notebook: notebook,
      syncSightings: (current) async {
        synced = current;
      },
    );

    expect(notebook.finds.single.latin, 'Agaricus augustus');
    expect(notebook.finds.single.outsideName, isNull);
    expect(synced, same(notebook));
  });

  test('a failed catalog read still syncs Sightings', () async {
    final notebook = Notebook()
      ..finds = const [
        FindRecord(
          id: 'out',
          millis: 5,
          outsideName: 'Agaricus augustus',
          confirmed: true,
        ),
      ];
    final repo = CatalogRepository(
      readCatalog: (language, {required bool server}) async {
        throw StateError('offline');
      },
    )..data = _catalog([_species('Boletus edulis', added: '2026-10-22')]);
    var synced = false;
    await refreshOpenGuide(
      catalog: repo,
      notebook: notebook,
      syncSightings: (_) async {
        synced = true;
      },
    );

    expect(synced, isTrue);
    expect(notebook.finds.single.outsideName, 'Agaricus augustus');
    expect(notebook.finds.single.latin, isNull);
  });

  testWidgets('Find and Seen show a species added while the app was open', (
    tester,
  ) async {
    final opened = buildCatalog(
      language: 'en',
      speciesDocs: [
        Doc('Boletus edulis', {
          'name': 'Boletus edulis',
          'id': 4,
          'added': '2026-10-22',
        }),
      ],
      local: const {
        'Boletus edulis': {'label': 'penny bun'},
      },
      english: const {
        'Boletus edulis': {'label': 'penny bun'},
      },
      synonyms: const {},
      taxa: const {},
    );
    final added = buildCatalog(
      language: 'en',
      speciesDocs: [
        Doc('Boletus edulis', {
          'name': 'Boletus edulis',
          'id': 4,
          'added': '2026-10-22',
        }),
        Doc('Agaricus augustus', {
          'name': 'Agaricus augustus',
          'id': 90,
          'added': '2026-10-29',
        }),
      ],
      local: const {
        'Boletus edulis': {'label': 'penny bun'},
        'Agaricus augustus': {'label': 'the prince'},
      },
      english: const {
        'Boletus edulis': {'label': 'penny bun'},
        'Agaricus augustus': {'label': 'the prince'},
      },
      synonyms: const {},
      taxa: const {},
    );
    final repo =
        CatalogRepository(
            readCatalog: (language, {required bool server}) async => added,
          )
          ..data = opened
          ..loading = false;
    final notebook = Notebook()
      ..finds = [
        FindRecord(
          id: 'out',
          millis: DateTime(2026, 10, 24, 9).millisecondsSinceEpoch,
          outsideName: 'Agaricus augustus',
          confirmed: true,
        ),
      ];
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_page(repo, notebook, const FindPage()));
    expect(find.text('Seen lately'), findsOneWidget);
    expect(find.text('Agaricus augustus'), findsOneWidget);
    expect(find.text('the prince'), findsNothing);
    expect(find.textContaining('1 mushroom'), findsOneWidget);

    await tester.pumpWidget(_page(repo, notebook, const _Seen()));
    expect(find.text('Not in the book'), findsOneWidget);
    expect(find.text('the prince'), findsNothing);

    await refreshOpenGuide(catalog: repo, notebook: notebook);
    await tester.pumpWidget(_page(repo, notebook, const FindPage()));
    expect(find.text('the prince'), findsOneWidget);
    expect(find.text('Agaricus augustus'), findsNothing);
    expect(find.textContaining('2 mushrooms'), findsOneWidget);
    expect(find.textContaining('1 mushroom'), findsNothing);

    await tester.pumpWidget(_page(repo, notebook, const _Seen()));
    expect(find.text('Not in the book'), findsNothing);
    expect(find.text('the prince'), findsOneWidget);
    expect(find.text('Agaricus augustus'), findsNothing);
  });
}

class _Seen extends StatelessWidget {
  const _Seen();

  @override
  Widget build(BuildContext context) {
    return const SeenPage(signedIn: false);
  }
}

Widget _page(CatalogRepository catalog, Notebook notebook, Widget page) {
  return GuideScope(
    catalog: catalog,
    notebook: notebook,
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
      home: Scaffold(body: page),
    ),
  );
}
