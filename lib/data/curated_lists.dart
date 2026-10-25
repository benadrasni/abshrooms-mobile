import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/text.dart';

/// Firestore collection of editorial lists. Not user lists.
///
/// The read rule is documented in `docs/CURATED_LISTS.md`. This app never writes.
const curatedListsCollection = 'curated_lists';

enum CuratedListType { year, region, species }

CuratedListType curatedListTypeOf(String? raw) {
  switch (raw) {
    case 'year':
      return CuratedListType.year;
    case 'region':
      return CuratedListType.region;
    default:
      return CuratedListType.species;
  }
}

class CuratedListEntry {
  final String? name;
  final int? speciesId;
  final int? year;
  final String? region;

  const CuratedListEntry({this.name, this.speciesId, this.year, this.region});

  factory CuratedListEntry.fromJson(Map<String, dynamic> json) {
    final regionValue = json['region'] ?? json['state'];
    final region = regionValue?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    return CuratedListEntry(
      name: name.isEmpty ? null : name,
      speciesId: asInt(json['speciesId']),
      year: asInt(json['year']),
      region: region.isEmpty ? null : region,
    );
  }
}

class CuratedListDoc {
  final String id;
  final CuratedListType type;
  final int sort;
  final List<String> locales;
  final String? parameter;
  final String? sourceUrl;
  final String? coverUrl;
  final String? coverSpecies;
  final int? coverSpeciesId;
  final Map<String, String> titles;
  final Map<String, String> descriptions;
  final List<CuratedListEntry> entries;

  const CuratedListDoc({
    required this.id,
    required this.type,
    required this.sort,
    required this.locales,
    required this.titles,
    required this.descriptions,
    required this.entries,
    this.parameter,
    this.sourceUrl,
    this.coverUrl,
    this.coverSpecies,
    this.coverSpeciesId,
  });

  factory CuratedListDoc.fromJson(Map<String, dynamic> json, {String? id}) {
    final rawId = (id ?? json['id']?.toString() ?? '').trim();
    final locales = _locales(json['locales']);
    final entries = <CuratedListEntry>[];
    final rawEntries = json['entries'];
    if (rawEntries is List) {
      for (final item in rawEntries) {
        if (item is Map) {
          entries.add(
            CuratedListEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return CuratedListDoc(
      id: rawId.isEmpty ? 'list' : rawId,
      type: curatedListTypeOf(json['type']?.toString()),
      sort: asInt(json['sort']) ?? 0,
      locales: locales.isEmpty ? const ['en'] : List.unmodifiable(locales),
      parameter: _text(json['parameter']),
      sourceUrl: _text(json['sourceUrl']),
      coverUrl: _text(json['coverUrl']),
      coverSpecies: _text(json['coverSpecies']),
      coverSpeciesId: asInt(json['coverSpeciesId']),
      titles: _texts(json['titles']),
      descriptions: _texts(json['descriptions']),
      entries: List.unmodifiable(entries),
    );
  }
}

class CuratedEntryView {
  final Species species;
  final String title;
  final bool titleIsLatin;
  final int? year;
  final String? region;
  final bool thisYear;

  const CuratedEntryView({
    required this.species,
    required this.title,
    required this.titleIsLatin,
    this.year,
    this.region,
    this.thisYear = false,
  });
}

class CuratedListView {
  final String id;
  final CuratedListType type;
  final int sort;
  final String title;
  final String description;
  final String? parameter;
  final String? sourceUrl;
  final String coverPhotoUrl;
  final List<CuratedEntryView> entries;

  const CuratedListView({
    required this.id,
    required this.type,
    required this.sort,
    required this.title,
    required this.description,
    required this.coverPhotoUrl,
    required this.entries,
    this.parameter,
    this.sourceUrl,
  });
}

class CuratedListsSnapshot {
  final List<CuratedListDoc> documents;
  final bool failed;

  const CuratedListsSnapshot(this.documents, {this.failed = false});
}

/// Title or description for [language], then English, then any stored text.
String localizedListText(
  Map<String, String> texts,
  String language, {
  String fallback = '',
}) {
  final own = texts[language.toLowerCase()];
  if (own != null && own.trim().isNotEmpty) return own.trim();
  final english = texts['en'];
  if (english != null && english.trim().isNotEmpty) return english.trim();
  for (final value in texts.values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return fallback;
}

/// A language with any list of its own sees those lists plus every `*` list.
/// A language with none sees the English set plus every `*` list.
List<CuratedListDoc> selectCuratedLists(
  List<CuratedListDoc> lists,
  String language,
) {
  final code = language.toLowerCase();
  final hasOwn = lists.any((list) => list.locales.contains(code));
  if (hasOwn) {
    return [
      for (final list in lists)
        if (list.locales.contains(code) || list.locales.contains('*')) list,
    ];
  }
  return [
    for (final list in lists)
      if (list.locales.contains('en') || list.locales.contains('*')) list,
  ];
}

int compareCuratedListViews(CuratedListView a, CuratedListView b) {
  final bySort = a.sort.compareTo(b.sort);
  if (bySort != 0) return bySort;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

/// Drops species the catalog does not have. Year lists are newest first.
/// Region lists are ordered by the state or region name.
CuratedListView presentCuratedList(
  CuratedListDoc doc,
  Catalog catalog,
  String language, {
  DateTime? now,
}) {
  final yearNow = (now ?? DateTime.now()).year;
  final resolved = <({int index, CuratedEntryView view})>[];
  for (var i = 0; i < doc.entries.length; i++) {
    final entry = doc.entries[i];
    final species = _resolve(catalog, entry);
    if (species == null) continue;
    final title = catalog.heading(species);
    resolved.add((
      index: i,
      view: CuratedEntryView(
        species: species,
        title: title,
        titleIsLatin: title == species.name,
        year: entry.year,
        region: entry.region,
        thisYear: entry.year != null && entry.year == yearNow,
      ),
    ));
  }
  resolved.sort((a, b) => _compareEntries(doc.type, a, b));
  final entries = [for (final item in resolved) item.view];
  return CuratedListView(
    id: doc.id,
    type: doc.type,
    sort: doc.sort,
    title: localizedListText(doc.titles, language, fallback: doc.id),
    description: localizedListText(doc.descriptions, language),
    parameter: doc.parameter,
    sourceUrl: doc.sourceUrl,
    coverPhotoUrl: _cover(doc, catalog, entries),
    entries: entries,
  );
}

Species? _resolve(Catalog catalog, CuratedListEntry entry) {
  final name = entry.name?.trim();
  if (name != null && name.isNotEmpty) {
    final byName = catalog.byName(name);
    if (byName != null) return byName;
  }
  final id = entry.speciesId;
  if (id == null) return null;
  for (final species in catalog.species) {
    if (species.id == id) return species;
  }
  return null;
}

int _compareEntries(
  CuratedListType type,
  ({int index, CuratedEntryView view}) a,
  ({int index, CuratedEntryView view}) b,
) {
  switch (type) {
    case CuratedListType.year:
      final ay = a.view.year;
      final by = b.view.year;
      if (ay == null && by == null) return a.index.compareTo(b.index);
      if (ay == null) return 1;
      if (by == null) return -1;
      final byYear = by.compareTo(ay);
      if (byYear != 0) return byYear;
      return a.index.compareTo(b.index);
    case CuratedListType.region:
      final ar = (a.view.region ?? '').toLowerCase();
      final br = (b.view.region ?? '').toLowerCase();
      if (ar.isEmpty && br.isEmpty) return a.index.compareTo(b.index);
      if (ar.isEmpty) return 1;
      if (br.isEmpty) return -1;
      final byRegion = ar.compareTo(br);
      if (byRegion != 0) return byRegion;
      return a.index.compareTo(b.index);
    case CuratedListType.species:
      return a.index.compareTo(b.index);
  }
}

String curatedImage(Species species, {required bool plate}) {
  if (plate) {
    final drawn = cardPlate(species.illustrationUrl);
    if (drawn.isNotEmpty) return drawn;
  }
  if (species.photoUrls.isNotEmpty) return mediaUrl(species.photoUrls.first);
  return cardPlate(species.illustrationUrl);
}

String? sourceHost(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// Reads `curated_lists`. Permission denied and a missing Firebase app are
/// an empty list, not an error: the rules may not be published yet.
Future<CuratedListsSnapshot> fetchCuratedLists() async {
  if (Firebase.apps.isEmpty) return const CuratedListsSnapshot([]);
  try {
    final snap = await FirebaseFirestore.instance
        .collection(curatedListsCollection)
        .get();
    return CuratedListsSnapshot([
      for (final doc in snap.docs)
        CuratedListDoc.fromJson(doc.data(), id: doc.id),
    ]);
  } on FirebaseException catch (error) {
    if (error.code == 'permission-denied') {
      return const CuratedListsSnapshot([]);
    }
    return const CuratedListsSnapshot([], failed: true);
  } catch (_) {
    return const CuratedListsSnapshot([], failed: true);
  }
}

String _cover(
  CuratedListDoc doc,
  Catalog catalog,
  List<CuratedEntryView> entries,
) {
  final explicit = doc.coverUrl;
  if (explicit != null && explicit.isNotEmpty) return mediaUrl(explicit);
  final named = doc.coverSpecies?.trim();
  Species? cover;
  if (named != null && named.isNotEmpty) cover = catalog.byName(named);
  final coverId = doc.coverSpeciesId;
  if (cover == null && coverId != null) {
    for (final species in catalog.species) {
      if (species.id == coverId) {
        cover = species;
        break;
      }
    }
  }
  if (cover != null) {
    final photo = curatedImage(cover, plate: false);
    if (photo.isNotEmpty) return photo;
  }
  for (final entry in entries) {
    final photo = curatedImage(entry.species, plate: false);
    if (photo.isNotEmpty) return photo;
  }
  return '';
}

List<String> _locales(Object? raw) {
  if (raw is! List) return const [];
  final values = <String>[];
  for (final item in raw) {
    final text = item?.toString().trim().toLowerCase() ?? '';
    if (text.isNotEmpty) values.add(text);
  }
  return values;
}

Map<String, String> _texts(Object? raw) {
  if (raw is! Map) return const {};
  final values = <String, String>{};
  for (final entry in raw.entries) {
    final text = entry.value?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    values[entry.key.toString().trim().toLowerCase()] = text;
  }
  return values;
}

String? _text(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
