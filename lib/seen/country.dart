import 'package:country_picker/country_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/seen/publish.dart';
import 'package:whats_that_mushroom/seen/stats.dart';
import 'package:whats_that_mushroom/species/seen_photo.dart';

final Map<String, Future<String?>> _countryLookups = {};
final Set<String> _lookupTried = {};
final Set<String> _remoteStored = {};
final Set<String> _placeWritten = {};
Future<void> _fillChain = Future<void>.value();

/// ISO country of a find. 0, 0 is no place and does not ask. One lookup is
/// shared by every photo at the same thousandth of a degree.
Future<String?> sightingCountryCode(double latitude, double longitude) {
  if (photoPlace(latitude, longitude) == null) return Future<String?>.value();
  final key = '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
  return _countryLookups.putIfAbsent(
    key,
    () => _readCountry(latitude, longitude),
  );
}

Future<String?> _readCountry(double latitude, double longitude) async {
  try {
    final marks = await Geocoding()
        .placemarkFromCoordinates(latitude, longitude)
        .timeout(const Duration(seconds: 10));
    if (marks.isEmpty) return null;
    return statCountry(marks.first.isoCountryCode);
  } catch (error) {
    debugPrint('sighting country: $error');
    return null;
  }
}

/// Country to store with a share. A code already on the find is kept.
/// Coordinates with no country are looked up once. No place stays empty.
Future<String?> sightingCountryForShare(
  FindRecord find, {
  Future<String?> Function(double latitude, double longitude)? lookup,
}) async {
  final known = statCountry(find.country);
  if (known != null) return known;
  final latitude = find.latitude;
  final longitude = find.longitude;
  if (latitude == null || longitude == null) return null;
  if (photoPlace(latitude, longitude) == null) return null;
  final ask = lookup ?? sightingCountryCode;
  try {
    return statCountry(await ask(latitude, longitude));
  } catch (error) {
    debugPrint('sighting country: $error');
    return null;
  }
}

/// The country name in the open language. A code the picker does not know
/// stays as two letters.
String? sightingCountryName(BuildContext context, String? code) {
  final iso = statCountry(code);
  if (iso == null) return null;
  final country = Country.tryParse(iso.toUpperCase());
  if (country == null) return iso.toUpperCase();
  final translated = country.getTranslatedName(context)?.trim();
  if (translated != null && translated.isNotEmpty) return translated;
  final name = country.name.trim();
  if (name.isNotEmpty) return name;
  return iso.toUpperCase();
}

/// Writes a country onto finds that have a place and none yet, then copies
/// the country and coordinates onto this account's Sighting. A lookup that
/// finds nothing is not retried until the next launch. Calls run one after
/// another, so two visits cannot overwrite each other's write.
Future<void> fillSightingCountries(
  Notebook notebook, {
  Future<String?> Function(double latitude, double longitude)? lookup,
  Future<bool> Function(String id, String code)? storeRemote,
  Future<bool> Function(FindRecord find)? storePlace,
}) {
  final run = _fillChain.then(
    (_) => _fillSightingCountries(
      notebook,
      lookup: lookup,
      storeRemote: storeRemote,
      storePlace: storePlace,
    ),
  );
  _fillChain = run.then((_) {}, onError: (Object _, StackTrace _) {});
  return run;
}

Future<void> _fillSightingCountries(
  Notebook notebook, {
  required Future<String?> Function(double latitude, double longitude)? lookup,
  required Future<bool> Function(String id, String code)? storeRemote,
  required Future<bool> Function(FindRecord find)? storePlace,
}) async {
  final ask = lookup ?? sightingCountryCode;
  final pending = <FindRecord>[];
  for (final find in notebook.finds) {
    if (statCountry(find.country) != null) continue;
    final latitude = find.latitude;
    final longitude = find.longitude;
    if (latitude == null || longitude == null) continue;
    if (photoPlace(latitude, longitude) == null) continue;
    if (!_lookupTried.add(find.id)) continue;
    pending.add(find);
  }
  if (pending.isNotEmpty) {
    final codes = await _lookupCountries(pending, ask);
    for (final row in codes) {
      final code = row.code;
      if (code == null) continue;
      final current = _find(notebook, row.id);
      if (current == null || statCountry(current.country) != null) continue;
      await notebook.replace(current.copyWith(country: code));
    }
  }
  if (storeRemote != null) {
    for (final find in notebook.finds) {
      final code = statCountry(find.country);
      if (code == null || find.share == FindShare.none) continue;
      if (!_remoteStored.add(find.id)) continue;
      final stored = await storeRemote(find.id, code);
      if (!stored) _remoteStored.remove(find.id);
    }
    return;
  }
  final writePlace = storePlace ?? writeSightingPlace;
  for (final find in notebook.finds) {
    if (find.share == FindShare.none) continue;
    final code = statCountry(find.country);
    final latitude = find.latitude;
    final longitude = find.longitude;
    final hasPlace =
        latitude != null &&
        longitude != null &&
        photoPlace(latitude, longitude) != null;
    final wantCountry = code != null && !_remoteStored.contains(find.id);
    final wantPlace = hasPlace && !_placeWritten.contains(find.id);
    if (!wantCountry && !wantPlace) continue;
    final stored = await writePlace(find);
    if (!stored) continue;
    if (code != null) _remoteStored.add(find.id);
    if (hasPlace) _placeWritten.add(find.id);
  }
}

Future<List<({String id, String? code})>> _lookupCountries(
  List<FindRecord> pending,
  Future<String?> Function(double latitude, double longitude) ask,
) async {
  final codes = List<({String id, String? code})?>.filled(pending.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < pending.length) {
      final index = next;
      next++;
      final find = pending[index];
      String? code;
      try {
        code = statCountry(await ask(find.latitude!, find.longitude!));
      } catch (error) {
        debugPrint('sighting country ${find.id}: $error');
      }
      codes[index] = (id: find.id, code: code);
    }
  }

  final width = pending.length < 3 ? pending.length : 3;
  await Future.wait([for (var i = 0; i < width; i++) worker()]);
  return [for (final row in codes) ?row];
}

FindRecord? _find(Notebook notebook, String id) {
  for (final find in notebook.finds) {
    if (find.id == id) return find;
  }
  return null;
}

@visibleForTesting
void resetSightingCountryFills() {
  _lookupTried.clear();
  _remoteStored.clear();
  _placeWritten.clear();
  _countryLookups.clear();
}
