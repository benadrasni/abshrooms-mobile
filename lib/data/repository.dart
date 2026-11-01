import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/data/catalog_pack.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/language.dart';
import 'package:whats_that_mushroom/offline/offline_book.dart';

/// Reads one language of the book.
///
/// [server] true is [Source.server]. [server] false is [Source.cache].
typedef CatalogRead = Future<Catalog> Function(
  String language, {
  required bool server,
});

/// Replaces the Firestore read. Tests use it. [server] false is the cache.
CatalogRead? debugCatalogRead;

/// Replaces the `curated_lists` read. Tests use it. The stored file is used
/// only when this read fails.
Future<CuratedListsSnapshot> Function()? debugCuratedListsRead;

class CatalogRepository {
  Catalog? data;
  Object? error;
  bool loading = false;
  String language = 'en';
  CuratedListsSnapshot curatedLists = const CuratedListsSnapshot([]);
  var _listsTicket = 0;
  var _ticket = 0;

  /// Set when [data] is already this pack, so a later offline read does not
  /// build it again. Null when the book came from Firestore.
  String? _shownPackRevision;
  final CatalogRead _readCatalog;

  CatalogRepository({CatalogRead? readCatalog})
    : _readCatalog = readCatalog ?? _readLiveCatalog;

  /// One read of `curated_lists`. The database comes first. The stored file
  /// is used only when that read fails and the file is on the phone. An
  /// older in-flight read does not overwrite a newer one.
  Future<void> loadCuratedLists() async {
    final ticket = ++_listsTicket;
    var snapshot = const CuratedListsSnapshot([], failed: true);
    try {
      final read = debugCuratedListsRead;
      snapshot = read == null ? await fetchCuratedLists() : await read();
    } catch (error) {
      debugPrint('curated lists: $error');
    }
    if (snapshot.failed) {
      final packed = _packedLists();
      if (packed != null) snapshot = packed;
    }
    if (ticket != _listsTicket) return;
    curatedLists = snapshot;
  }

  Future<void> load(String language) async {
    final ticket = ++_ticket;
    this.language = language;
    loading = true;
    error = null;
    try {
      await _resolve(language, ticket);
    } catch (caught) {
      if (ticket != _ticket) return;
      error = caught;
    } finally {
      if (ticket == _ticket) loading = false;
    }
  }

  /// Reads the book from the server and replaces the copy on screen.
  /// When that read has no species, the same offline choice as [load] runs.
  /// Returns false when this read lost to a newer one, or nothing new was
  /// put on screen.
  Future<bool> refresh() async {
    final ticket = ++_ticket;
    final language = this.language;
    try {
      return await _resolve(language, ticket);
    } catch (caught) {
      if (ticket != _ticket) return false;
      if (data == null || data!.species.isEmpty) error = caught;
      return false;
    } finally {
      if (ticket == _ticket) loading = false;
    }
  }

  /// A server catalog with species is the book. Otherwise the pack, unless
  /// the cache's newest `added` day is strictly later. An empty screen uses
  /// the pack. [added] is only that species check, not a version of the book.
  Future<bool> _resolve(String language, int ticket) async {
    Object? failure;
    Catalog? server;
    try {
      server = await _readCatalog(language, server: true);
    } catch (error) {
      failure = error;
      debugPrint('catalog server: $error');
    }
    if (ticket != _ticket) return false;
    if (server != null && server.species.isNotEmpty) {
      data = server;
      _shownPackRevision = null;
      error = null;
      return true;
    }

    Catalog? cache;
    try {
      cache = await _readCatalog(language, server: false);
    } catch (error) {
      failure ??= error;
      debugPrint('catalog cache: $error');
    }
    if (ticket != _ticket) return false;

    final previous = data;
    final screenEmpty = previous == null || previous.species.isEmpty;
    final showingPack = _showingThisPack(language);
    final pack = showingPack ? previous : _packedCatalog(language);
    if (screenEmpty && pack != null) {
      data = pack;
      _shownPackRevision = OfflineBook.catalogRevision;
      error = null;
      return true;
    }
    if (!screenEmpty && pack != null && _cacheIsStrictlyLater(cache, pack)) {
      data = cache;
      _shownPackRevision = null;
      error = null;
      return !identical(previous, cache);
    }
    if (pack != null) {
      if (!showingPack) data = pack;
      _shownPackRevision = OfflineBook.catalogRevision;
      error = null;
      return !showingPack;
    }
    if (cache != null && cache.species.isNotEmpty) {
      data = cache;
      _shownPackRevision = null;
      error = null;
      return !identical(previous, cache);
    }
    if (screenEmpty) error = failure ?? StateError('catalog');
    return false;
  }

  /// True when [data] is already the pack for [language].
  bool _showingThisPack(String language) {
    final shown = data;
    final revision = OfflineBook.catalogRevision;
    return _shownPackRevision != null &&
        _shownPackRevision == revision &&
        revision.isNotEmpty &&
        shown != null &&
        shown.species.isNotEmpty &&
        contentLanguage(shown.language) == contentLanguage(language);
  }
}

/// The cache has a species birthday the pack does not.
bool _cacheIsStrictlyLater(Catalog? cache, Catalog? pack) {
  if (cache == null || cache.species.isEmpty || pack == null) return false;
  final cacheDay = _newestAddedDay(cache);
  if (cacheDay == null) return false;
  final packDay = _newestAddedDay(pack);
  return packDay == null || cacheDay.isAfter(packDay);
}

DateTime? _newestAddedDay(Catalog catalog) {
  DateTime? newest;
  for (final species in catalog.species) {
    final day = addedDate(species.added);
    if (day == null) continue;
    if (newest == null || day.isAfter(newest)) newest = day;
  }
  return newest;
}

Future<Catalog> _readLiveCatalog(
  String language, {
  required bool server,
}) async {
  final read = debugCatalogRead;
  if (read != null) return await read(language, server: server);
  return fetchCatalog(language, source: server ? Source.server : Source.cache);
}

Catalog? _packedCatalog(String language) {
  if (!OfflineBook.stored) return null;
  final root = OfflineBook.root;
  if (root == null) return null;
  try {
    return readPackedCatalog(
      root,
      language,
      revision: OfflineBook.catalogRevision,
    );
  } catch (error) {
    debugPrint('catalog pack: $error');
    return null;
  }
}

CuratedListsSnapshot? _packedLists() {
  if (!OfflineBook.stored) return null;
  final root = OfflineBook.root;
  if (root == null) return null;
  try {
    return readPackedLists(root, revision: OfflineBook.catalogRevision);
  } catch (error) {
    debugPrint('catalog pack: $error');
    return null;
  }
}

Future<Catalog> fetchCatalog(String language, {Source? source}) async {
  final code = contentLanguage(language);
  final db = FirebaseFirestore.instance;
  final options = source == null ? null : GetOptions(source: source);
  final speciesSnap = await db.collection('species').get(options);
  final localSnap = await db
      .collection('translations')
      .doc(code)
      .collection('species')
      .get(options);
  final englishSnap = code == 'en'
      ? localSnap
      : await db
            .collection('translations')
            .doc('en')
            .collection('species')
            .get(options);
  final synonymSnap = await db.collection('synonyms').get(options);
  final taxaSnap = await db
      .collection('taxonomy')
      .doc(code)
      .collection('taxa')
      .get(options);
  return buildCatalog(
    language: code,
    speciesDocs: [for (final doc in speciesSnap.docs) Doc(doc.id, doc.data())],
    local: _byId(localSnap.docs),
    english: _byId(englishSnap.docs),
    synonyms: _byId(synonymSnap.docs),
    taxa: {
      for (final doc in taxaSnap.docs)
        doc.id: doc.data()['vernacular']?.toString() ?? '',
    },
  );
}

Map<String, Map<String, dynamic>> _byId(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  return {for (final doc in docs) doc.id: doc.data()};
}

bool catalogDenied(Object? error) {
  return error is FirebaseException && error.code == 'permission-denied';
}
