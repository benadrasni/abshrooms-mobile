import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/offline/offline_plan.dart';

/// Public catalog snapshot published beside the plates.
const catalogManifestPath = 'catalog/manifest.json';

const _requiredFiles = [
  'catalog/manifest.json',
  'catalog/species.json',
  'catalog/synonyms.json',
  'catalog/lists.json',
  'catalog/translations/en.json',
  'catalog/taxonomy/en.json',
];

/// One published revision of the book. [bytes] is the text files, not the
/// pictures.
class CatalogManifest {
  final String revision;
  final int speciesCount;
  final int bytes;
  final List<String> languages;
  final List<String> files;

  const CatalogManifest({
    required this.revision,
    required this.speciesCount,
    required this.bytes,
    required this.languages,
    required this.files,
  });
}

/// A manifest that names the book files and nothing outside `catalog/`.
CatalogManifest parseCatalogManifest(Object? decoded) {
  if (decoded is! Map) throw const FormatException('catalog manifest');
  final revision = decoded['revision']?.toString().trim() ?? '';
  if (revision.isEmpty ||
      revision.length > 64 ||
      revision.contains('/') ||
      revision.contains(r'\')) {
    throw const FormatException('catalog revision');
  }
  final rawFiles = decoded['files'];
  if (rawFiles is! List || rawFiles.isEmpty) {
    throw const FormatException('catalog files');
  }
  final files = <String>[];
  for (final item in rawFiles) {
    final path = item?.toString() ?? '';
    if (!catalogFilePath(path) || files.contains(path)) {
      throw const FormatException('catalog path');
    }
    files.add(path);
  }
  for (final required in _requiredFiles) {
    if (!files.contains(required)) {
      throw const FormatException('catalog files');
    }
  }
  final languages = <String>[];
  final rawLanguages = decoded['languages'];
  if (rawLanguages is List) {
    for (final item in rawLanguages) {
      final code = item?.toString() ?? '';
      if (RegExp(r'^[a-z]{2}$').hasMatch(code)) languages.add(code);
    }
  }
  return CatalogManifest(
    revision: revision,
    speciesCount: _count(decoded['speciesCount']),
    bytes: _count(decoded['bytes']),
    languages: List.unmodifiable(languages),
    files: List.unmodifiable(files),
  );
}

/// Storage path for one snapshot file. Other hosts and parent segments fail.
bool catalogFilePath(String path) {
  final relative = offlineRelative(path);
  return relative != null && relative == path && path.startsWith('catalog/');
}

/// The book stored under [root]/offline/catalog, or null when that copy is
/// missing or does not match [revision].
Catalog? readPackedCatalog(
  String root,
  String language, {
  required String revision,
}) {
  if (revision.isEmpty) return null;
  final pack = Directory('$root/offline/catalog');
  final manifestFile = File('${pack.path}/manifest.json');
  if (!manifestFile.existsSync()) return null;
  final manifest = parseCatalogManifest(
    jsonDecode(manifestFile.readAsStringSync()),
  );
  if (manifest.revision != revision) return null;
  final code = _language(language);
  final species = _objectFile(pack, 'species.json');
  final synonyms = _objectFile(pack, 'synonyms.json');
  final english = _objectFile(pack, 'translations/en.json');
  if (species == null || synonyms == null || english == null) return null;
  if (species.length != manifest.speciesCount) return null;
  final local = code == 'en'
      ? english
      : _objectFile(pack, 'translations/$code.json');
  return buildCatalog(
    language: code,
    speciesDocs: [
      for (final entry in species.entries) Doc(entry.key, entry.value),
    ],
    local: local ?? const {},
    english: english,
    synonyms: synonyms,
    taxa: _taxonomyFile(pack, 'taxonomy/$code.json'),
  );
}

/// Editorial lists stored with the book, or null when the file is missing.
CuratedListsSnapshot? readPackedLists(String root, {required String revision}) {
  if (revision.isEmpty) return null;
  final pack = Directory('$root/offline/catalog');
  final manifestFile = File('${pack.path}/manifest.json');
  final listsFile = File('${pack.path}/lists.json');
  if (!manifestFile.existsSync() || !listsFile.existsSync()) return null;
  final manifest = parseCatalogManifest(
    jsonDecode(manifestFile.readAsStringSync()),
  );
  if (manifest.revision != revision) return null;
  final decoded = jsonDecode(listsFile.readAsStringSync());
  if (decoded is! List) throw const FormatException('catalog lists');
  return CuratedListsSnapshot([
    for (final item in decoded)
      if (item is Map)
        CuratedListDoc.fromJson(
          Map<String, dynamic>.from(item),
          id: item['id']?.toString(),
        ),
  ]);
}

/// The published manifest, or null when this revision is not on the bucket yet.
Future<CatalogManifest?> fetchCatalogManifest() async {
  final client = HttpClient();
  try {
    final bytes = await _get(client, catalogManifestPath);
    if (bytes == null) return null;
    return parseCatalogManifest(jsonDecode(utf8.decode(bytes)));
  } finally {
    client.close(force: true);
  }
}

Future<List<int>?> _get(HttpClient client, String relative) async {
  final request = await client.getUrl(Uri.parse(storageRoot).resolve(relative));
  final response = await request.close().timeout(const Duration(minutes: 1));
  if (response.statusCode == 404) {
    await response.drain<void>();
    return null;
  }
  if (response.statusCode != 200) {
    await response.drain<void>();
    throw HttpException('HTTP ${response.statusCode} for $relative');
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Map<String, Map<String, dynamic>>? _objectFile(Directory pack, String name) {
  final file = File('${pack.path}/$name');
  if (!file.existsSync()) return null;
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) throw const FormatException('catalog object');
  final out = <String, Map<String, dynamic>>{};
  for (final entry in decoded.entries) {
    final value = entry.value;
    if (value is! Map) throw const FormatException('catalog object');
    out[entry.key.toString()] = Map<String, dynamic>.from(value);
  }
  return out;
}

Map<String, String> _taxonomyFile(Directory pack, String name) {
  final file = File('${pack.path}/$name');
  if (!file.existsSync()) return const {};
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) throw const FormatException('catalog taxonomy');
  final out = <String, String>{};
  for (final entry in decoded.entries) {
    final value = entry.value;
    final text = value is Map
        ? value['vernacular']?.toString().trim() ?? ''
        : value?.toString().trim() ?? '';
    if (text.isNotEmpty) out[entry.key.toString()] = text;
  }
  return out;
}

String _language(String language) {
  return RegExp(r'^[a-z]{2}$').hasMatch(language) ? language : 'en';
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0) return value.round();
  return 0;
}
