import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/text.dart';

const underChoices = [
  'gills',
  'tubes',
  'ridges',
  'teeth',
  'pits',
  'smooth',
  'gleba',
];
const whereChoices = ['wood', 'ground', 'grass'];
const colorChoices = [
  'white',
  'yellow',
  'red',
  'brown',
  'green',
  'purple',
  'dark',
];
const seasonChoices = ['spring', 'summer', 'autumn', 'winter'];

const seasonMonths = {
  'spring': [3, 4, 5],
  'summer': [6, 7, 8],
  'autumn': [9, 10, 11],
  'winter': [12, 1, 2],
};

class KeySelection {
  final String under;
  final String where;
  final String color;
  final String season;

  const KeySelection({
    this.under = '',
    this.where = '',
    this.color = '',
    this.season = '',
  });

  String axis(String name) => switch (name) {
    'under' => under,
    'where' => where,
    'color' => color,
    'season' => season,
    _ => '',
  };

  KeySelection copyWith({
    String? under,
    String? where,
    String? color,
    String? season,
  }) {
    return KeySelection(
      under: under ?? this.under,
      where: where ?? this.where,
      color: color ?? this.color,
      season: season ?? this.season,
    );
  }

  /// Tap the selected value again to clear it.
  KeySelection toggle(String axisName, String value) {
    final next = axis(axisName) == value ? '' : value;
    return switch (axisName) {
      'under' => copyWith(under: next),
      'where' => copyWith(where: next),
      'color' => copyWith(color: next),
      'season' => copyWith(season: next),
      _ => this,
    };
  }
}

bool matchesAxis(Species species, String axis, String value) {
  if (value.isEmpty) return true;
  switch (axis) {
    case 'under':
      return species.hymenium == value;
    case 'season':
      final from = species.fruitingFrom;
      final to = species.fruitingTo;
      if (from == null || to == null) return false;
      final want = seasonMonths[value] ?? const <int>[];
      final months = fruitingMonths(from, to);
      return want.any(months.contains);
    case 'where':
      if (species.where.isEmpty) return false;
      return species.where.contains(value);
    case 'color':
      if (species.colors.isEmpty) return false;
      return species.colors.contains(value);
  }
  return false;
}

bool matchesSelection(Species species, KeySelection selection) {
  for (final axis in ['under', 'where', 'color', 'season']) {
    if (!matchesAxis(species, axis, selection.axis(axis))) return false;
  }
  return true;
}

bool matchesOther(Species species, KeySelection selection, String axis) {
  for (final name in ['under', 'where', 'color', 'season']) {
    if (name == axis) continue;
    if (!matchesAxis(species, name, selection.axis(name))) return false;
  }
  return true;
}

List<String> choicesFor(String axis) => switch (axis) {
  'under' => underChoices,
  'where' => whereChoices,
  'color' => colorChoices,
  _ => seasonChoices,
};

Map<String, int> optionCounts(
  List<Species> species,
  KeySelection selection,
  String axis,
) {
  final counts = {for (final id in choicesFor(axis)) id: 0};
  for (final item in species) {
    if (!matchesOther(item, selection, axis)) continue;
    if (axis == 'under') {
      if (counts.containsKey(item.hymenium)) {
        counts[item.hymenium] = counts[item.hymenium]! + 1;
      }
      continue;
    }
    if (axis == 'season') {
      for (final id in seasonChoices) {
        if (matchesAxis(item, 'season', id)) {
          counts[id] = counts[id]! + 1;
        }
      }
      continue;
    }
    final values = axis == 'where' ? item.where : item.colors;
    for (final id in values) {
      if (counts.containsKey(id)) counts[id] = counts[id]! + 1;
    }
  }
  return counts;
}

/// Fruiting this month first, then the rest. A chosen season stays one list.
List<Species> orderedResults(
  Catalog catalog,
  List<Species> matches,
  KeySelection selection,
  int month,
) {
  int byName(Species a, Species b) {
    return catalog.compareTitles(catalog.heading(a), catalog.heading(b));
  }

  if (selection.season.isNotEmpty) {
    final rows = [...matches]..sort(byName);
    return rows;
  }
  final now = <Species>[];
  final later = <Species>[];
  for (final item in matches) {
    (item.fruitsIn(month) ? now : later).add(item);
  }
  now.sort(byName);
  later.sort(byName);
  return [...now, ...later];
}
