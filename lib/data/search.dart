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

List<SearchHit> _matches(Catalog catalog, String query) {
  final needle = foldName(query);
  if (needle.length < 2) return const [];
  final hits = <SearchHit>[];

  void rankTaxon(String kind, String name) {
    final spoken = catalog.taxonVernacular(name);
    final folded = foldName(name);
    final spokenFold = foldName(spoken);
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
          name: name,
          label: spoken.isEmpty ? null : spoken,
          score: score,
        ),
      );
    }
  }

  for (final name in catalog.namesOf('family')) {
    rankTaxon('family', name);
  }
  for (final name in catalog.namesOf('genus')) {
    rankTaxon('genus', name);
  }
  for (final species in catalog.species) {
    final text = catalog.textFor(species);
    final names = <String>[
      species.name,
      if (text.label != null) text.label!,
      ...text.names,
      ...species.synonymLines,
    ];
    var mushroomScore = 99;
    for (final name in names) {
      final folded = foldName(name);
      final score = folded == needle
          ? 0
          : folded.startsWith(needle)
          ? 1
          : folded.contains(needle)
          ? 2
          : 99;
      if (score < mushroomScore) mushroomScore = score;
    }
    if (mushroomScore < 99) {
      hits.add(
        SearchHit(
          kind: 'mushroom',
          name: species.name,
          label: text.label,
          family: species.family,
          score: mushroomScore + 3,
        ),
      );
    }
  }
  return hits;
}
