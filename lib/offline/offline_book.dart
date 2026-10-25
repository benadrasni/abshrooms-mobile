import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/shell/crash_reporting.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/offline/offline_plan.dart';

const _keyBook = 'offline_book';
const _keyFiles = 'offline_files';
const _keySkipped = 'offline_skipped';
const _keySpecies = 'offline_species';
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
    rootOverride = null;
    _root = null;
    revision.value = 0;
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
    await _remove(_keyBook);
    await _remove(_keyFiles);
    await _remove(_keySkipped);
    await _remove(_keySpecies);
    final directory = root;
    if (directory != null) {
      final folder = Directory('$directory/$_folder');
      if (folder.existsSync()) await folder.delete(recursive: true);
    }
    revision.value++;
  }
}

/// Caches the active language, and the other one when it can, so the words
/// open with the pictures.
Future<void> warmOfflineWords(
  CatalogRepository catalog,
  String language,
) async {
  await catalog.load(language);
  if (catalog.error != null || catalog.data == null) {
    final error = catalog.error;
    if (error != null) throw error;
    throw StateError('catalog');
  }
  final other = language == 'sk' ? 'en' : 'sk';
  try {
    await fetchCatalog(other);
  } catch (error) {
    debugPrint('offline words: $error');
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

  const OfflineRequest({
    required this.title,
    required this.species,
    required this.pending,
    required this.alreadyDone,
    required this.totalFiles,
    required this.markStored,
    required this.update,
  });
}

Future<OfflineStart> startOfflineDownload({
  required OfflineRequest request,
  required void Function(int done, int total) onProgress,
  required void Function() onFinished,
  required void Function() onFailed,
  Future<bool> Function()? wifi,
  Future<void> Function()? warm,
  Future<List<int>?> Function(String relative)? fetch,
}) async {
  if (request.totalFiles <= 0 ||
      (request.pending.isEmpty && request.alreadyDone >= request.totalFiles)) {
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
    warm: warm,
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
  required Future<void> Function()? warm,
  required Future<List<int>?> Function(String relative)? fetch,
}) async {
  final client = fetch == null ? HttpClient() : null;
  if (client != null) OfflineBook._client = client;
  try {
    if (warm != null) {
      await warm();
      if (!OfflineBook.owns(generation)) return;
    }
    final directory = await _directory();
    if (!OfflineBook.owns(generation)) return;
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
      final bytes = await (fetch ?? (String path) => _http(client!, path))(
        relative,
      );
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
