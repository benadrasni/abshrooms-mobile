import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/seen/country.dart';

void main() {
  setUp(resetSightingCountryFills);

  test('coordinates with no place do not ask for a country', () async {
    expect(await sightingCountryCode(0, 0), isNull);
    expect(await sightingCountryCode(double.nan, 17), isNull);
    expect(await sightingCountryCode(91, 10), isNull);
  });

  test('the notebook keeps a country and drops anything else', () {
    final stored = FindRecord.fromJson(
      FindRecord(
        id: 'a',
        millis: 5,
        latin: 'Boletus edulis',
        latitude: 48.15,
        longitude: 17.11,
        country: 'at',
      ).toJson(),
    );
    expect(stored.country, 'at');
    expect(stored.latitude, 48.15);
    expect(
      FindRecord.fromJson({'id': 'b', 'millis': 1, 'country': 'Middle Europe'})
          .country,
      isNull,
    );
    expect(
      FindRecord.fromJson({'id': 'c', 'millis': 1, 'country': ' SK '}).country,
      'sk',
    );
  });

  test(
    'a placed find gets one country and a sent find is written once',
    () async {
      final notebook = Notebook()
        ..finds = [
          FindRecord(
            id: 'placed',
            millis: 1,
            latin: 'Boletus edulis',
            confirmed: true,
            latitude: 48.15,
            longitude: 17.11,
          ),
          FindRecord(
            id: 'known',
            millis: 2,
            latin: 'Amanita muscaria',
            confirmed: true,
            latitude: 48.2,
            longitude: 17.2,
            country: 'sk',
          ),
          FindRecord(
            id: 'sent',
            millis: 3,
            latin: 'Boletus edulis',
            confirmed: true,
            country: 'de',
            share: FindShare.shared,
          ),
          FindRecord(id: 'bare', millis: 4, latin: 'Boletus edulis'),
        ];
      final asked = <String>[];
      final remote = <String, int>{};
      var acceptRemote = false;

      Future<void> fill() {
        return fillSightingCountries(
          notebook,
          lookup: (latitude, longitude) async {
            asked.add(
              '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}',
            );
            return 'SK';
          },
          storeRemote: (id, code) async {
            remote[id] = (remote[id] ?? 0) + 1;
            expect(code, anyOf('sk', 'de'));
            return acceptRemote;
          },
        );
      }

      await fill();
      expect(asked, ['48.15,17.11']);
      expect(
        notebook.finds.firstWhere((find) => find.id == 'placed').country,
        'sk',
      );
      expect(
        notebook.finds.firstWhere((find) => find.id == 'known').country,
        'sk',
      );
      expect(remote.keys, ['sent']);
      expect(remote['sent'], 1);

      notebook.finds = [
        for (final find in notebook.finds)
          if (find.id == 'placed')
            find.copyWith(share: FindShare.shared)
          else
            find,
      ];
      acceptRemote = true;
      await fill();
      expect(asked, ['48.15,17.11']);
      expect(remote['sent'], 2);
      expect(remote['placed'], 1);

      await fill();
      expect(remote['sent'], 2);
      expect(remote['placed'], 1);
    },
  );

  test('a share keeps a known country and looks up a missing one', () async {
    var asked = 0;
    final known = await sightingCountryForShare(
      FindRecord(
        id: 'a',
        millis: 1,
        country: ' SK ',
        latitude: 48.15,
        longitude: 17.11,
      ),
      lookup: (latitude, longitude) async {
        asked++;
        return 'de';
      },
    );
    expect(known, 'sk');
    expect(asked, 0);

    final looked = await sightingCountryForShare(
      FindRecord(id: 'b', millis: 1, latitude: 48.15, longitude: 17.11),
      lookup: (latitude, longitude) async => 'SK',
    );
    expect(looked, 'sk');
    expect(
      await sightingCountryForShare(
        FindRecord(id: 'c', millis: 1),
        lookup: (latitude, longitude) async => 'sk',
      ),
      isNull,
    );
    expect(
      await sightingCountryForShare(
        FindRecord(id: 'd', millis: 1, latitude: 48.15, longitude: 17.11),
        lookup: (latitude, longitude) async => throw StateError('down'),
      ),
      isNull,
    );
  });

  test(
    'a shared find copies its place when the country lookup is empty',
    () async {
      final notebook = Notebook()
        ..finds = [
          FindRecord(
            id: 'placed',
            millis: 1,
            latin: 'Boletus edulis',
            confirmed: true,
            latitude: 48.15,
            longitude: 17.11,
            share: FindShare.shared,
          ),
          FindRecord(
            id: 'home',
            millis: 2,
            confirmed: true,
            latitude: 1,
            longitude: 2,
          ),
        ];
      final writes = <String, int>{};

      Future<void> fill({required bool ok}) {
        return fillSightingCountries(
          notebook,
          lookup: (latitude, longitude) async => null,
          storePlace: (find) async {
            writes[find.id] = (writes[find.id] ?? 0) + 1;
            expect(find.latitude, 48.15);
            expect(find.longitude, 17.11);
            return ok;
          },
        );
      }

      await fill(ok: false);
      expect(writes, {'placed': 1});
      await fill(ok: true);
      expect(writes['placed'], 2);
      await fill(ok: true);
      expect(writes['placed'], 2);
    },
  );
}
