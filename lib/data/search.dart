import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/text.dart';

class SearchHit {
  final String kind;
  final String name;
  final String? label;
  final String? family;
  final int score;

  const SearchHit({
    required this.kind,
    required this.name,
    this.label,
    this.family,
    required this.score,
  });
}

class SearchSections {
  final List<SearchHit> mushrooms;
  final List<SearchHit> genera;
  final List<SearchHit> families;

  const SearchSections({
    this.mushrooms = const [],
    this.genera = const [],
    this.families = const [],
  });

  bool get isEmpty => mushrooms.isEmpty && genera.isEmpty && families.isEmpty;
}

const searchMushroomLimit = 8;
const searchTaxonLimit = 4;

/// Mushrooms, then genera, then families. Each group keeps its own limit,
/// matching the plants search page.
SearchSections searchSections(Catalog catalog, String query) {
  final hits = _matches(catalog, query);
  return SearchSections(
    mushrooms: _takeKind(hits, 'mushroom', searchMushroomLimit),
    genera: _takeKind(hits, 'genus', searchTaxonLimit),
    families: _takeKind(hits, 'family', searchTaxonLimit),
  );
}

/// Same ranking as the website: family and genus before species.
List<SearchHit> searchHits(Catalog catalog, String query) {
  final hits = [..._matches(catalog, query)]..sort(_compareHits);
  return hits.take(12).toList();
}

List<SearchHit> _takeKind(List<SearchHit> hits, String kind, int limit) {
  final rows = [
    for (final hit in hits)
      if (hit.kind == kind) hit,
  ]..sort(_compareHits);
  return rows.take(limit).toList();
}

int _compareHits(SearchHit a, SearchHit b) {
  final byScore = a.score.compareTo(b.score);
  if (byScore != 0) return byScore;
  return a.name.compareTo(b.name);
}

class _TaxonEntry {
  final String name;
  final String? label;
  final String foldedName;
  final String foldedLabel;

  const _TaxonEntry({
    required this.name,
    required this.label,
    required this.foldedName,
    required this.foldedLabel,
  });
}

class _SpeciesEntry {
  final String name;
  final String? label;
  final String family;
  final List<String> foldedNames;

  const _SpeciesEntry({
    required this.name,
    required this.label,
    required this.family,
    required this.foldedNames,
  });
}

class _SearchIndex {
  final List<_TaxonEntry> families;
  final List<_TaxonEntry> genera;
  final List<_SpeciesEntry> mushrooms;

  const _SearchIndex({
    required this.families,
    required this.genera,
    required this.mushrooms,
  });
}

final _searchIndexes = Expando<_SearchIndex>('catalog_search_index');

_SearchIndex _indexFor(Catalog catalog) {
  final existing = _searchIndexes[catalog];
  if (existing != null) return existing;

  _TaxonEntry taxonEntry(String name) {
    final spoken = catalog.taxonVernacular(name);
    return _TaxonEntry(
      name: name,
      label: spoken.isEmpty ? null : spoken,
      foldedName: foldName(name),
      foldedLabel: spoken.isEmpty ? '' : foldName(spoken),
    );
  }

  final families = [
    for (final name in catalog.namesOf('family')) taxonEntry(name),
  ];
  final genera = [
    for (final name in catalog.namesOf('genus')) taxonEntry(name),
  ];
  final mushrooms = <_SpeciesEntry>[];
  for (final species in catalog.species) {
    final own = catalog.local[species.name];
    final label = own?.label;
    final foldedNames = <String>[
      foldName(species.name),
      if (label != null) foldName(label),
      if (own != null)
        for (final name in own.names) foldName(name),
      for (final synonym in species.synonyms) foldName(synonym.line),
    ];
    mushrooms.add(
      _SpeciesEntry(
        name: species.name,
        label: label,
        family: species.family,
        foldedNames: foldedNames,
      ),
    );
  }
  final built = _SearchIndex(
    families: families,
    genera: genera,
    mushrooms: mushrooms,
  );
  _searchIndexes[catalog] = built;
  return built;
}

List<SearchHit> _matches(Catalog catalog, String query) {
  final needle = foldName(query);
  if (needle.length < 2) return const [];
  final index = _indexFor(catalog);
  final hits = <SearchHit>[];

  void rankTaxon(String kind, _TaxonEntry entry) {
    final folded = entry.foldedName;
    final spokenFold = entry.foldedLabel;
    var score = 99;
    if (folded == needle || (spokenFold.isNotEmpty && spokenFold == needle)) {
      score = 0;
    } else if (folded.startsWith(needle) ||
        (spokenFold.isNotEmpty && spokenFold.startsWith(needle))) {
      score = 1;
    } else if (folded.contains(needle) ||
        (spokenFold.isNotEmpty && spokenFold.contains(needle))) {
      score = 2;
    }
    if (score < 99) {
      hits.add(
        SearchHit(
          kind: kind,
          name: entry.name,
          label: entry.label,
          score: score,
        ),
      );
    }
  }

  for (final entry in index.families) {
    rankTaxon('family', entry);
  }
  for (final entry in index.genera) {
    rankTaxon('genus', entry);
  }
  for (final entry in index.mushrooms) {
    var mushroomScore = 99;
    for (final folded in entry.foldedNames) {
      final score = folded == needle
          ? 0
          : folded.startsWith(needle)
          ? 1
          : folded.contains(needle)
          ? 2
          : 99;
      if (score < mushroomScore) {
        mushroomScore = score;
        if (mushroomScore == 0) break;
      }
    }
    if (mushroomScore < 99) {
      hits.add(
        SearchHit(
          kind: 'mushroom',
          name: entry.name,
          label: entry.label,
          family: entry.family,
          score: mushroomScore + 3,
        ),
      );
    }
  }
  return hits;
}
