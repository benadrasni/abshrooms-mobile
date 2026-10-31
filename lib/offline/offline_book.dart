import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/data/catalog_pack.dart';
import 'package:whats_that_mushroom/shell/crash_reporting.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/offline/offline_plan.dart';

const _keyBook = 'offline_book';
const _keyFiles = 'offline_files';
const _keySkipped = 'offline_skipped';
const _keySpecies = 'offline_species';
const _keyCatalog = 'offline_catalog_revision';
const _folder = 'offline';

enum OfflineStart { started, needsWifi, skipped }

/// One download of the whole book. Pictures live under the app documents
/// directory. The pack is marked stored only when the download finishes.
class OfflineBook {
  static final revision = ValueNotifier<int>(0);
  static var stored = false;
  static var speciesSaved = 0;
  static final saved = <String>{};
  static final skipped = <String>{};

  /// Revision of the snapshot in [root]/offline/catalog. Empty until a
  /// download finishes the words.
  static var catalogRevision = '';

  /// Revision offered by the bucket this session. Empty until a check.
  static var remoteRevision = '';
  static var remoteBytes = 0;

  /// Replaces the manifest fetch. Tests use it.
  static Future<CatalogManifest?> Function()? readManifest;

  static var useMemory = false;
  static String? rootOverride;
  static final Map<String, Object> _memory = {};
  static String? _root;
  static int _generation = 0;
  static HttpClient? _client;
  static Future<void> idle = Future<void>.value();

  static String? get root => rootOverride ?? _root;

  static void resetForTest() {
    pause();
    useMemory = true;
    _memory.clear();
    stored = false;
    speciesSaved = 0;
    saved.clear();
    skipped.clear();
    catalogRevision = '';
    remoteRevision = '';
    remoteBytes = 0;
    readManifest = null;
    rootOverride = null;
    _root = null;
    revision.value = 0;
  }

  /// The stored book is behind the snapshot on the bucket.
  static bool get catalogStale {
    if (!stored || remoteRevision.isEmpty) return false;
    return remoteRevision != catalogRevision;
  }

  /// A file already on this phone, or null when the picture must come from
  /// the network. [url] may be a storage URL or a catalog path.
  static File? localFile(String url) {
    final relative = offlineRelative(url);
    final directory = root;
    if (relative == null || directory == null || !saved.contains(relative)) {
      return null;
    }
    final file = File('$directory/$_folder/$relative');
    if (!file.existsSync()) return null;
    return file;
  }

  static int claim() {
    _generation += 1;
    return _generation;
  }

  static void pause() {
    _generation += 1;
    _client?.close(force: true);
    _client = null;
  }

  static bool owns(int generation) => generation == _generation;

  static Future<void> restore() async {
    final book = await _getString(_keyBook);
    final files = _decode(await _getString(_keyFiles));
    final missed = _decode(await _getString(_keySkipped));
    final count = await _getInt(_keySpecies);
    if (rootOverride != null) {
      _root = rootOverride;
    } else if (!useMemory) {
      _root = (await getApplicationDocumentsDirectory()).path;
    }
    stored = book == 'all';
    speciesSaved = count ?? 0;
    catalogRevision = await _getString(_keyCatalog) ?? '';
    remoteRevision = '';
    remoteBytes = 0;
    saved
      ..clear()
      ..addAll(files);
    skipped
      ..clear()
      ..addAll(missed);
    final directory = root;
    if (directory != null) {
      saved.removeWhere(
        (path) => !File('$directory/$_folder/$path').existsSync(),
      );
      if (stored && saved.isEmpty && files.isNotEmpty) stored = false;
    }
    revision.value++;
  }

  static Future<void> clear() async {
    pause();
    stored = false;
    speciesSaved = 0;
    saved.clear();
    skipped.clear();
    catalogRevision = '';
    remoteRevision = '';
    remoteBytes = 0;
    await _remove(_keyBook);
    await _remove(_keyFiles);
    await _remove(_keySkipped);
    await _remove(_keySpecies);
    await _remove(_keyCatalog);
    final directory = root;
    if (directory != null) {
      final folder = Directory('$directory/$_folder');
      if (folder.existsSync()) await folder.delete(recursive: true);
    }
    revision.value++;
  }

  static Future<void> rememberCatalog(String next, int bytes) async {
    catalogRevision = next;
    remoteRevision = next;
    remoteBytes = bytes;
    await _setString(_keyCatalog, next);
    revision.value++;
  }

  /// Reads the published revision. A missing manifest leaves the offer as it
  /// was. A stored book with a different revision is ready to update.
  static Future<void> watchRemoteCatalog() async {
    if (!stored) return;
    try {
      final manifest = readManifest != null
          ? await readManifest!()
          : await fetchCatalogManifest();
      if (manifest == null) return;
      if (remoteRevision == manifest.revision &&
          remoteBytes == manifest.bytes) {
        return;
      }
      remoteRevision = manifest.revision;
      remoteBytes = manifest.bytes;
      revision.value++;
    } catch (error) {
      debugPrint('catalog manifest: $error');
    }
  }
}

class OfflineRequest {
  final String title;
  final int species;
  final List<String> pending;
  final int alreadyDone;
  final int totalFiles;
  final bool markStored;
  final bool update;

  /// Download the published words as well as the pictures.
  final bool includeCatalog;

  /// Text bytes to add to an update bar. Pictures keep their own estimate.
  final int catalogBytes;

  const OfflineRequest({
    required this.title,
    required this.species,
    required this.pending,
    required this.alreadyDone,
    required this.totalFiles,
    required this.markStored,
    required this.update,
    this.includeCatalog = false,
    this.catalogBytes = 0,
  });
}

Future<OfflineStart> startOfflineDownload({
  required OfflineRequest request,
  required void Function(int done, int total) onProgress,
  required void Function() onFinished,
  required void Function() onFailed,
  Future<bool> Function()? wifi,
  Future<List<int>?> Function(String relative)? fetch,
}) async {
  final picturesDone =
      request.pending.isEmpty && request.alreadyDone >= request.totalFiles;
  if ((request.totalFiles <= 0 || picturesDone) && !request.includeCatalog) {
    if (request.markStored) await _markStored(request.species);
    onFinished();
    return OfflineStart.started;
  }
  final online = await (wifi ?? _onWifi)();
  if (!online) return OfflineStart.needsWifi;
  final generation = OfflineBook.claim();
  final running = _run(
    request: request,
    generation: generation,
    onProgress: onProgress,
    onFinished: onFinished,
    onFailed: onFailed,
    fetch: fetch,
  );
  OfflineBook.idle = running;
  return OfflineStart.started;
}

Future<void> _run({
  required OfflineRequest request,
  required int generation,
  required void Function(int done, int total) onProgress,
  required void Function() onFinished,
  required void Function() onFailed,
  required Future<List<int>?> Function(String relative)? fetch,
}) async {
  final client = fetch == null ? HttpClient() : null;
  if (client != null) OfflineBook._client = client;
  try {
    final directory = await _directory();
    if (!OfflineBook.owns(generation)) return;
    final read = fetch ?? (String path) => _http(client!, path);
    if (request.includeCatalog) {
      final pulled = await _pullCatalog(
        directory: directory,
        generation: generation,
        fetch: read,
      );
      if (!pulled || !OfflineBook.owns(generation)) return;
    }
    if (request.pending.isEmpty) {
      onProgress(1, 1);
      if (request.markStored) await _markStored(request.species);
      if (!OfflineBook.owns(generation)) return;
      onFinished();
      return;
    }
    var done = request.alreadyDone;
    final total = request.totalFiles;
    onProgress(done, total);
    for (final relative in request.pending) {
      if (!OfflineBook.owns(generation)) return;
      if (OfflineBook.saved.contains(relative) ||
          OfflineBook.skipped.contains(relative)) {
        done += 1;
        onProgress(done, total);
        continue;
      }
      final bytes = await read(relative);
      if (!OfflineBook.owns(generation)) return;
      if (bytes == null) {
        if (offlineOptional(relative)) {
          OfflineBook.skipped.add(relative);
          await _persistSkipped();
          done += 1;
          onProgress(done, total);
          continue;
        }
        recordGuideError(
          StateError('missing $relative'),
          StackTrace.current,
          reason: 'offline download $relative',
        );
        onFailed();
        return;
      }
      await _write(directory, relative, bytes);
      if (!OfflineBook.owns(generation)) return;
      OfflineBook.saved.add(relative);
      await _persistFiles();
      OfflineBook.revision.value++;
      done += 1;
      onProgress(done, total);
    }
    if (!OfflineBook.owns(generation)) return;
    if (request.markStored) await _markStored(request.species);
    if (!OfflineBook.owns(generation)) return;
    onFinished();
  } catch (error, stack) {
    if (!OfflineBook.owns(generation)) return;
    debugPrint('offline: $error');
    recordGuideError(error, stack, reason: 'offline download');
    onFailed();
  } finally {
    if (identical(OfflineBook._client, client)) OfflineBook._client = null;
    client?.close(force: true);
  }
}

/// Writes the snapshot under offline/catalog, then records its revision.
/// A missing manifest leaves the current words in place and still lets the
/// pictures download. Returns false when this download was paused.
Future<bool> _pullCatalog({
  required String directory,
  required int generation,
  required Future<List<int>?> Function(String relative) fetch,
}) async {
  final raw = await fetch(catalogManifestPath);
  if (!OfflineBook.owns(generation)) return false;
  if (raw == null || raw.isEmpty) {
    debugPrint('catalog pack: no manifest');
    return true;
  }
  final manifest = parseCatalogManifest(jsonDecode(utf8.decode(raw)));
  if (_packMatches(directory, manifest)) return true;
  await _deleteStaging(directory);
  final staging = Directory('$directory/$_folder/catalog-next');
  try {
    await _write(directory, 'catalog-next/manifest.json', raw);
    final bodies = <String, List<int>>{};
    for (final relative in manifest.files) {
      if (!OfflineBook.owns(generation)) {
        await _deleteStaging(directory);
        return false;
      }
      if (relative == catalogManifestPath) continue;
      final bytes = await fetch(relative);
      if (!OfflineBook.owns(generation)) {
        await _deleteStaging(directory);
        return false;
      }
      if (bytes == null || bytes.isEmpty) {
        throw StateError('missing $relative');
      }
      bodies[relative] = bytes;
      await _write(
        directory,
        'catalog-next/${relative.substring('catalog/'.length)}',
        bytes,
      );
    }
    final species = bodies['catalog/species.json'];
    if (species == null) throw StateError('missing catalog/species.json');
    final decoded = jsonDecode(utf8.decode(species));
    if (decoded is! Map || decoded.length != manifest.speciesCount) {
      throw StateError('catalog species count');
    }
    if (!OfflineBook.owns(generation)) {
      await _deleteStaging(directory);
      return false;
    }
    _swapCatalog(directory, staging);
    await OfflineBook.rememberCatalog(manifest.revision, manifest.bytes);
    return true;
  } catch (error) {
    await _deleteStaging(directory);
    rethrow;
  }
}

bool _packMatches(String directory, CatalogManifest manifest) {
  if (OfflineBook.catalogRevision != manifest.revision) return false;
  final pack = Directory('$directory/$_folder/catalog');
  return File('${pack.path}/manifest.json').existsSync() &&
      File('${pack.path}/species.json').existsSync() &&
      File('${pack.path}/translations/en.json').existsSync();
}

void _swapCatalog(String directory, Directory staging) {
  final live = Directory('$directory/$_folder/catalog');
  final previous = Directory('$directory/$_folder/catalog-previous');
  if (previous.existsSync()) previous.deleteSync(recursive: true);
  if (live.existsSync()) live.renameSync(previous.path);
  try {
    staging.renameSync(live.path);
  } catch (error) {
    if (!live.existsSync() && previous.existsSync()) {
      previous.renameSync(live.path);
    }
    rethrow;
  }
  if (previous.existsSync()) previous.deleteSync(recursive: true);
}

Future<void> _deleteStaging(String directory) async {
  final staging = Directory('$directory/$_folder/catalog-next');
  if (staging.existsSync()) staging.deleteSync(recursive: true);
}

Future<List<int>?> _http(HttpClient client, String relative) async {
  final uri = Uri.parse(storageRoot).resolve(relative);
  final request = await client.getUrl(uri);
  final response = await request.close().timeout(const Duration(minutes: 2));
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

Future<bool> _onWifi() async {
  final results = await Connectivity().checkConnectivity();
  return results.contains(ConnectivityResult.wifi);
}

Future<String> _directory() async {
  final override = OfflineBook.rootOverride;
  if (override != null) {
    OfflineBook._root = override;
    return override;
  }
  OfflineBook._root ??= (await getApplicationDocumentsDirectory()).path;
  return OfflineBook._root!;
}

Future<void> _write(String directory, String relative, List<int> bytes) async {
  final file = File('$directory/$_folder/$relative');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> _markStored(int species) async {
  OfflineBook.stored = true;
  OfflineBook.speciesSaved = species;
  await _setString(_keyBook, 'all');
  await _setInt(_keySpecies, species);
  OfflineBook.revision.value++;
}

Future<void> _persistFiles() async {
  final files = OfflineBook.saved.toList()..sort();
  await _setString(_keyFiles, jsonEncode(files));
}

Future<void> _persistSkipped() async {
  final files = OfflineBook.skipped.toList()..sort();
  await _setString(_keySkipped, jsonEncode(files));
}

List<String> _decode(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded.map((item) => item.toString()).toList();
}

Future<String?> _getString(String key) async {
  if (OfflineBook.useMemory) return OfflineBook._memory[key] as String?;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<int?> _getInt(String key) async {
  if (OfflineBook.useMemory) return OfflineBook._memory[key] as int?;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(key);
}

Future<void> _setString(String key, String value) async {
  if (OfflineBook.useMemory) {
    OfflineBook._memory[key] = value;
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<void> _setInt(String key, int value) async {
  if (OfflineBook.useMemory) {
    OfflineBook._memory[key] = value;
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(key, value);
}

Future<void> _remove(String key) async {
  if (OfflineBook.useMemory) {
    OfflineBook._memory.remove(key);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
}
