import 'package:whats_that_mushroom/data/notebook.dart';

/// One mushroom row on the statistics page.
class StatMushroom {
  final String name;
  final DateTime when;
  final int count;
  final String? spoken;
  final String? photoPath;

  const StatMushroom({
    required this.name,
    required this.when,
    this.count = 1,
    this.spoken,
    this.photoPath,
  });
}

class StatYear {
  final int year;
  final int count;

  const StatYear(this.year, this.count);
}

class StatCountry {
  final String code;
  final int count;

  const StatCountry(this.code, this.count);
}

/// Finds in one Seen notebook. A row with no name is left out.
class NotebookStats {
  final int finds;
  final int mushrooms;
  final int shared;
  final int unconfirmed;
  final StatMushroom? first;
  final StatMushroom? last;

  /// Mushrooms tied for the highest count, when that count is greater than one.
  final List<StatMushroom> most;
  final List<StatYear> years;
  final List<StatCountry> countries;
  final int unplaced;

  const NotebookStats({
    required this.finds,
    required this.mushrooms,
    required this.shared,
    required this.unconfirmed,
    required this.first,
    required this.last,
    required this.most,
    required this.years,
    required this.countries,
    required this.unplaced,
  });
}

/// Accepted public Sightings. Years come from the same rows.
class SightingHeadline {
  final int count;
  final int mushrooms;
  final int people;
  final String firstName;
  final DateTime? firstWhen;
  final String lastName;
  final DateTime? lastWhen;
  final String mostName;
  final int mostCount;
  final List<StatCountry> countries;

  const SightingHeadline({
    required this.count,
    required this.mushrooms,
    required this.people,
    required this.firstName,
    required this.firstWhen,
    required this.lastName,
    required this.lastWhen,
    required this.mostName,
    required this.mostCount,
    required this.countries,
  });
}

class SightingsLoad {
  final SightingHeadline? headline;
  final List<StatYear> years;

  const SightingsLoad({required this.headline, required this.years});
}

/// A two-letter ISO code, lowercased. Anything else is no country.
String? statCountry(Object? value) {
  if (value is! String) return null;
  final code = value.trim().toLowerCase();
  if (code.length != 2) return null;
  for (final unit in code.codeUnits) {
    if (unit < 0x61 || unit > 0x7a) return null;
  }
  return code;
}

/// Thousands grouped for the page. Slovak uses a narrow space.
String statGrouped(int value, {required bool slovak}) {
  final negative = value < 0;
  final raw = (negative ? -value : value).toString();
  final separator = slovak ? '\u00A0' : ',';
  final buffer = StringBuffer();
  if (negative) buffer.write('-');
  for (var i = 0; i < raw.length; i++) {
    final left = raw.length - i;
    if (i > 0 && left % 3 == 0) buffer.write(separator);
    buffer.write(raw[i]);
  }
  return buffer.toString();
}

/// [countryOf] reads a stored code. The notebook keeps coordinates, not a
/// country, so the page leaves this empty until a lookup writes one.
NotebookStats notebookStats(
  Iterable<FindRecord> finds, {
  String? Function(FindRecord find)? countryOf,
}) {
  final rows = [
    for (final find in finds)
      if (_name(find) != null) find,
  ]..sort(_byWhen);
  final byName = <String, List<FindRecord>>{};
  final years = <int, int>{};
  final countries = <String, int>{};
  var shared = 0;
  var unconfirmed = 0;
  var unplaced = 0;
  for (final find in rows) {
    byName.putIfAbsent(_name(find)!, () => []).add(find);
    final when = _when(find);
    years[when.year] = (years[when.year] ?? 0) + 1;
    final country = countryOf == null ? null : statCountry(countryOf(find));
    if (country == null) {
      unplaced++;
    } else {
      countries[country] = (countries[country] ?? 0) + 1;
    }
    if (find.confirmed && find.share == FindShare.shared) shared++;
    if (!find.confirmed) unconfirmed++;
  }
  var top = 0;
  for (final group in byName.values) {
    if (group.length > top) top = group.length;
  }
  final most = <StatMushroom>[];
  if (top > 1) {
    final names =
        byName.keys.where((name) => byName[name]!.length == top).toList()
          ..sort();
    for (final name in names) {
      final group = byName[name]!;
      most.add(_mushroom(group.last, count: top));
    }
  }
  return NotebookStats(
    finds: rows.length,
    mushrooms: byName.length,
    shared: shared,
    unconfirmed: unconfirmed,
    first: rows.isEmpty ? null : _mushroom(rows.first),
    last: rows.isEmpty ? null : _mushroom(rows.last),
    most: most,
    years: _years(years),
    countries: _countries(countries),
    unplaced: unplaced,
  );
}

/// Public `sightings` documents. A status other than `public` is left out.
/// A missing status is kept: the query already asked for public rows.
SightingsLoad sightingsFromDocs(Iterable<Map<String, dynamic>> rows) {
  final kept = <_Public>[];
  for (final row in rows) {
    final parsed = _public(row);
    if (parsed != null) kept.add(parsed);
  }
  if (kept.isEmpty) {
    return const SightingsLoad(headline: null, years: []);
  }
  kept.sort((a, b) {
    final byWhen = a.when.compareTo(b.when);
    if (byWhen != 0) return byWhen;
    return a.name.compareTo(b.name);
  });
  final mushrooms = <String, int>{};
  final countries = <String, int>{};
  final years = <int, int>{};
  final people = <String>{};
  for (final row in kept) {
    mushrooms[row.name] = (mushrooms[row.name] ?? 0) + 1;
    years[row.when.year] = (years[row.when.year] ?? 0) + 1;
    final country = row.country;
    if (country != null) countries[country] = (countries[country] ?? 0) + 1;
    final uid = row.uid;
    if (uid != null) people.add(uid);
  }
  var top = 0;
  var mostName = '';
  final names = mushrooms.keys.toList()..sort();
  for (final name in names) {
    final count = mushrooms[name]!;
    if (count > top) {
      top = count;
      mostName = name;
    }
  }
  final first = kept.first;
  final last = kept.last;
  return SightingsLoad(
    headline: SightingHeadline(
      count: kept.length,
      mushrooms: mushrooms.length,
      people: people.length,
      firstName: first.name,
      firstWhen: first.when,
      lastName: last.name,
      lastWhen: last.when,
      mostName: mostName,
      mostCount: top,
      countries: _countries(countries),
    ),
    years: _years(years),
  );
}

String? _name(FindRecord find) {
  final latin = find.latin?.trim() ?? '';
  if (latin.isNotEmpty) return latin;
  final outside = find.outsideName?.trim() ?? '';
  if (outside.isNotEmpty) return outside;
  return null;
}

DateTime _when(FindRecord find) {
  return DateTime.fromMillisecondsSinceEpoch(find.millis);
}

int _byWhen(FindRecord a, FindRecord b) {
  final byWhen = a.millis.compareTo(b.millis);
  if (byWhen != 0) return byWhen;
  return a.id.compareTo(b.id);
}

StatMushroom _mushroom(FindRecord find, {int count = 1}) {
  final spoken = find.spoken?.trim();
  return StatMushroom(
    name: _name(find)!,
    when: _when(find),
    count: count,
    spoken: spoken == null || spoken.isEmpty ? null : spoken,
    photoPath: find.photoPath,
  );
}

class _Public {
  final String name;
  final DateTime when;
  final String? uid;
  final String? country;

  const _Public(this.name, this.when, this.uid, this.country);
}

_Public? _public(Map<String, dynamic> row) {
  final status = row['status'];
  if (status != null && status.toString() != 'public') return null;
  final name = row['latin']?.toString().trim() ?? '';
  if (name.isEmpty) return null;
  final when = _millis(row['millis']);
  if (when == null) return null;
  final uid = row['uid']?.toString().trim();
  return _Public(
    name,
    when,
    uid == null || uid.isEmpty ? null : uid,
    statCountry(row['country']),
  );
}

DateTime? _millis(Object? value) {
  final int millis;
  if (value is int) {
    millis = value;
  } else if (value is num) {
    millis = value.toInt();
  } else {
    return null;
  }
  if (millis <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

List<StatYear> _years(Map<int, int> counts) {
  final years = [
    for (final entry in counts.entries) StatYear(entry.key, entry.value),
  ]..sort((a, b) => a.year.compareTo(b.year));
  return years;
}

List<StatCountry> _countries(Map<String, int> counts) {
  final rows = [
    for (final entry in counts.entries)
      if (entry.value > 0) StatCountry(entry.key, entry.value),
  ];
  rows.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.code.compareTo(b.code);
  });
  return rows;
}
