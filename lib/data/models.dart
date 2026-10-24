import 'package:whats_that_mushroom/data/text.dart';

const rankOrder = [
  'kingdom',
  'subkingdom',
  'phylum',
  'subphylum',
  'class',
  'subclass',
  'suborder',
  'order',
  'family',
  'genus',
];

class KeyFacts {
  final String hymenium;
  final List<String> where;
  final List<String> color;

  /// Day the species joined the book, `YYYY-MM-DD`, from web/catalog.js.
  final String added;

  const KeyFacts({
    required this.hymenium,
    required this.where,
    required this.color,
    this.added = '',
  });
}

class Synonym {
  final String name;
  final String author;

  const Synonym({required this.name, required this.author});

  String get line => author.isEmpty ? name : '$name $author';
}

class Translation {
  final String? label;
  final List<String> names;
  final String? description;
  final String? cap;
  final String? hymenium;
  final String? stipe;
  final String? flesh;
  final String? sporePrint;
  final String? habitat;
  final String? uses;
  final String? confusion;
  final String? notes;
  final List<String> sourceUrls;

  const Translation({
    this.label,
    this.names = const [],
    this.description,
    this.cap,
    this.hymenium,
    this.stipe,
    this.flesh,
    this.sporePrint,
    this.habitat,
    this.uses,
    this.confusion,
    this.notes,
    this.sourceUrls = const [],
  });

  factory Translation.fromMap(Map<String, dynamic> data) {
    return Translation(
      label: _blank(data['label']),
      names: stringList(data['names']),
      description: _blank(data['description']),
      cap: _blank(data['cap']),
      hymenium: _blank(data['hymenium']),
      stipe: _blank(data['stipe']),
      flesh: _blank(data['flesh']),
      sporePrint: _blank(data['sporePrint']),
      habitat: _blank(data['habitat']),
      uses: _blank(data['uses']),
      confusion: _blank(data['confusion']),
      notes: _blank(data['notes']),
      sourceUrls: stringList(data['sourceUrls']),
    );
  }
}

class SpeciesText {
  final String? label;
  final List<String> names;
  final String? description;
  final String? cap;
  final String? hymenium;
  final String? stipe;
  final String? flesh;
  final String? sporePrint;
  final String? habitat;
  final String? uses;
  final String? confusion;
  final String? notes;
  final List<String> sourceUrls;

  const SpeciesText({
    this.label,
    this.names = const [],
    this.description,
    this.cap,
    this.hymenium,
    this.stipe,
    this.flesh,
    this.sporePrint,
    this.habitat,
    this.uses,
    this.confusion,
    this.notes,
    this.sourceUrls = const [],
  });
}

class Species {
  final int id;
  final String name;
  final String author;
  final String family;
  final String genus;
  final String order;
  final Map<String, String> taxonomy;
  final String edibility;
  final String hymenium;
  final List<String> where;
  final List<String> colors;
  final int? fruitingFrom;
  final int? fruitingTo;
  final double? capFrom;
  final double? capTo;
  final double? stipeHeightFrom;
  final double? stipeHeightTo;
  final double? stipeThickFrom;
  final double? stipeThickTo;
  final String illustrationUrl;
  final List<String> photoUrls;
  final List<Synonym> synonyms;

  /// Day the species joined the book, `YYYY-MM-DD`. Empty when unknown.
  final String added;

  const Species({
    required this.id,
    required this.name,
    required this.author,
    required this.family,
    required this.genus,
    required this.order,
    required this.taxonomy,
    required this.edibility,
    required this.hymenium,
    required this.where,
    required this.colors,
    required this.fruitingFrom,
    required this.fruitingTo,
    required this.capFrom,
    required this.capTo,
    required this.stipeHeightFrom,
    required this.stipeHeightTo,
    required this.stipeThickFrom,
    required this.stipeThickTo,
    required this.illustrationUrl,
    required this.photoUrls,
    required this.synonyms,
    this.added = '',
  });

  List<String> get synonymLines =>
      synonyms.map((synonym) => synonym.line).toList();

  bool fruitsIn(int month) {
    final from = fruitingFrom;
    final to = fruitingTo;
    if (from == null || to == null) return false;
    return fruitingMonths(from, to).contains(month);
  }
}

class Catalog {
  final String language;
  final List<Species> species;
  final Map<String, Translation> local;
  final Map<String, Translation> english;
  final Map<String, String> taxa;

  Catalog({
    required this.language,
    required this.species,
    required this.local,
    required this.english,
    required this.taxa,
  });

  int compareTitles(String a, String b) => compareTitle(a, b, language);

  Species? byName(String name) {
    for (final item in species) {
      if (item.name.toLowerCase() == name.toLowerCase()) return item;
    }
    return null;
  }

  SpeciesText textFor(Species species) {
    final own = local[species.name];
    final en = english[species.name];
    String? body(String? Function(Translation text) pick) {
      final localText = own == null ? null : pick(own);
      if (localText != null && localText.trim().isNotEmpty) return localText;
      final englishText = en == null ? null : pick(en);
      if (englishText != null && englishText.trim().isNotEmpty) {
        return englishText;
      }
      return null;
    }

    final urls = own?.sourceUrls ?? const <String>[];
    return SpeciesText(
      label: own?.label,
      names: own?.names ?? const [],
      description: body((text) => text.description),
      cap: body((text) => text.cap),
      hymenium: body((text) => text.hymenium),
      stipe: body((text) => text.stipe),
      flesh: body((text) => text.flesh),
      sporePrint: body((text) => text.sporePrint),
      habitat: body((text) => text.habitat),
      uses: body((text) => text.uses),
      confusion: body((text) => text.confusion),
      notes: body((text) => text.notes),
      sourceUrls: urls.isNotEmpty ? urls : (en?.sourceUrls ?? const []),
    );
  }

  String taxonVernacular(String scientific) => taxa[scientific]?.trim() ?? '';

  String taxonTitle(String scientific) {
    final spoken = displayName(taxonVernacular(scientific), language);
    return spoken.isEmpty ? scientific : spoken;
  }

  String heading(Species species) {
    return titleFor(textFor(species).label, species.name, language);
  }

  List<String> namesOf(String kind) {
    final names = <String>{};
    for (final item in species) {
      final name = kind == 'family' ? item.family : item.genus;
      if (name.isNotEmpty) names.add(name);
    }
    final list = names.toList();
    list.sort((a, b) => compareTitles(taxonTitle(a), taxonTitle(b)));
    return list;
  }

  int countOf(String kind, String name) {
    var count = 0;
    for (final item in species) {
      final value = kind == 'family' ? item.family : item.genus;
      if (value == name) count += 1;
    }
    return count;
  }

  List<Species> speciesIn(String kind, String name) {
    final rows = species.where((item) {
      return (kind == 'family' ? item.family : item.genus) == name;
    }).toList();
    rows.sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }
}

class Doc {
  final String id;
  final Map<String, dynamic> data;

  const Doc(this.id, this.data);
}

Species speciesFromMap(String id, Map<String, dynamic> data, KeyFacts? key) {
  final rawTaxonomy = data['taxonomy'];
  final taxonomy = <String, String>{};
  if (rawTaxonomy is Map) {
    rawTaxonomy.forEach((rank, name) {
      final value = name?.toString().trim() ?? '';
      if (value.isNotEmpty) taxonomy[rank.toString()] = value;
    });
  }
  return Species(
    id: asInt(data['id']) ?? 0,
    name: _blank(data['name']) ?? id,
    author: _blank(data['author']) ?? '',
    family: taxonomy['family'] ?? '',
    genus: taxonomy['genus'] ?? '',
    order: taxonomy['order'] ?? '',
    taxonomy: taxonomy,
    edibility: _blank(data['edibility']) ?? '',
    hymenium: key?.hymenium ?? '',
    where: key?.where ?? const [],
    colors: key?.color ?? const [],
    fruitingFrom: asInt(data['fruitingFrom']),
    fruitingTo: asInt(data['fruitingTo']),
    capFrom: asDouble(data['capWidthFromCm']),
    capTo: asDouble(data['capWidthToCm']),
    stipeHeightFrom: asDouble(data['stipeHeightFromCm']),
    stipeHeightTo: asDouble(data['stipeHeightToCm']),
    stipeThickFrom: asDouble(data['stipeThicknessFromCm']),
    stipeThickTo: asDouble(data['stipeThicknessToCm']),
    illustrationUrl: _blank(data['illustrationUrl']) ?? '',
    photoUrls: stringList(data['photoUrls']),
    synonyms: const [],
    added: key?.added ?? '',
  );
}

List<Synonym> synonymsFromMap(Map<String, dynamic>? data) {
  if (data == null) return const [];
  final out = <Synonym>[];
  for (final group in ['homotypic', 'heterotypic']) {
    final list = data[group];
    if (list is! List) continue;
    for (final item in list) {
      if (item is! Map) continue;
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      out.add(
        Synonym(name: name, author: item['author']?.toString().trim() ?? ''),
      );
    }
  }
  return out;
}

Catalog buildCatalog({
  required String language,
  required List<Doc> speciesDocs,
  required Map<String, Map<String, dynamic>> local,
  required Map<String, Map<String, dynamic>> english,
  required Map<String, Map<String, dynamic>> synonyms,
  required Map<String, String> taxa,
  required Map<String, KeyFacts> key,
}) {
  final rows = <Species>[];
  for (final doc in speciesDocs) {
    final parsed = speciesFromMap(
      doc.id,
      doc.data,
      key[doc.id] ?? key[doc.data['name']],
    );
    if (parsed.name.trim().isEmpty) continue;
    rows.add(
      Species(
        id: parsed.id,
        name: parsed.name,
        author: parsed.author,
        family: parsed.family,
        genus: parsed.genus,
        order: parsed.order,
        taxonomy: parsed.taxonomy,
        edibility: parsed.edibility,
        hymenium: parsed.hymenium,
        where: parsed.where,
        colors: parsed.colors,
        fruitingFrom: parsed.fruitingFrom,
        fruitingTo: parsed.fruitingTo,
        capFrom: parsed.capFrom,
        capTo: parsed.capTo,
        stipeHeightFrom: parsed.stipeHeightFrom,
        stipeHeightTo: parsed.stipeHeightTo,
        stipeThickFrom: parsed.stipeThickFrom,
        stipeThickTo: parsed.stipeThickTo,
        illustrationUrl: parsed.illustrationUrl,
        photoUrls: parsed.photoUrls,
        synonyms: synonymsFromMap(synonyms[parsed.name]),
        added: parsed.added,
      ),
    );
  }
  rows.sort((a, b) => a.name.compareTo(b.name));
  return Catalog(
    language: language,
    species: rows,
    local: local.map((name, data) => MapEntry(name, Translation.fromMap(data))),
    english: english.map(
      (name, data) => MapEntry(name, Translation.fromMap(data)),
    ),
    taxa: taxa,
  );
}

String? _blank(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
