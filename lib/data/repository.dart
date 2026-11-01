import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/data/catalog_pack.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/language.dart';
import 'package:whats_that_mushroom/offline/offline_book.dart';

/// Reads one language of the book. [server] skips the on-disk cache.
typedef CatalogRead = Future<Catalog> Function(
  String language, {
  required bool server,
});

/// Replaces the Firestore read. Tests use it. The stored offline book is
/// used only when this read fails.
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

  /// Pack revision of [data] when the book on screen came from the offline
  /// snapshot. Null when it came from Firestore.
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
      final resolved = await _bookForLoad(language);
      if (ticket != _ticket) return;
      data = resolved.catalog;
      _shownPackRevision = resolved.packRevision;
    } catch (caught) {
      if (ticket != _ticket) return;
      error = caught;
    } finally {
      if (ticket == _ticket) loading = false;
    }
  }

  /// Cache first. An empty cache uses the offline pack. The default Firestore
  /// source falls back to a cached book and would hide that empty cache, so
  /// a successful empty read is treated like a miss. A cache with species
  /// stays. The server is asked only when the cache is empty and no pack is
  /// on the phone.
  Future<({Catalog catalog, String? packRevision})> _bookForLoad(
    String language,
  ) async {
    Catalog? read;
    try {
      read = await _readCatalog(language, server: false);
    } catch (error) {
      debugPrint('catalog load: $error');
    }
    if (read != null && read.species.isNotEmpty) {
      return (catalog: read, packRevision: null);
    }
    final packed = _packedCatalog(language);
    if (packed != null) {
      return (catalog: packed, packRevision: OfflineBook.catalogRevision);
    }
    if (read != null) return (catalog: read, packRevision: null);
    final server = await _readCatalog(language, server: true);
    return (catalog: server, packRevision: null);
  }

  /// Reads the book from the database and replaces the copy on screen.
  /// Offline, the book already on screen stays unless the stored pack is
  /// newer. Returns false when this read lost to a newer one, or the
  /// database could not be reached and no newer pack is on the phone.
  Future<bool> refresh() async {
    final ticket = ++_ticket;
    try {
      final next = await _readCatalog(language, server: true);
      if (ticket != _ticket) return false;
      data = next;
      _shownPackRevision = null;
      error = null;
      loading = false;
      return true;
    } catch (caught) {
      if (ticket != _ticket) return false;
      final packed = _packedCatalog(language);
      final replacement = packed == null
          ? null
          : newerOfflinePack(
              current: data,
              currentRevision: _shownPackRevision,
              pack: packed,
              packRevision: OfflineBook.catalogRevision,
            );
      loading = false;
      if (replacement != null) {
        data = replacement;
        _shownPackRevision = OfflineBook.catalogRevision;
        error = null;
        return true;
      }
      if (data == null || data!.species.isEmpty) error = caught;
      return false;
    }
  }
}

/// The offline pack when it should replace [current] after a server refresh
/// failed.
///
/// A live cache stays unless the pack's newest `added` day is later. A pack
/// already on screen is replaced only by a different pack revision, which is
/// the later download. Revision hashes are not an order by themselves.
Catalog? newerOfflinePack({
  required Catalog? current,
  required String? currentRevision,
  required Catalog pack,
  required String packRevision,
}) {
  if (packRevision.isEmpty) return null;
  if (current == null || current.species.isEmpty) return pack;
  if (currentRevision != null && currentRevision.isNotEmpty) {
    return currentRevision == packRevision ? null : pack;
  }
  final packDay = _latestAdded(pack);
  final currentDay = _latestAdded(current);
  if (packDay == null) return null;
  if (currentDay == null || packDay.isAfter(currentDay)) return pack;
  return null;
}

DateTime? _latestAdded(Catalog catalog) {
  DateTime? latest;
  for (final species in catalog.species) {
    final day = addedDate(species.added);
    if (day == null) continue;
    if (latest == null || day.isAfter(latest)) latest = day;
  }
  return latest;
}

Future<Catalog> _readLiveCatalog(
  String language, {
  required bool server,
}) async {
  final read = debugCatalogRead;
  if (read != null) return await read(language, server: server);
  // [server] false keeps the default source so an online launch still reads
  // the database. That source also returns a cached book without throwing,
  // and [CatalogRepository.load] uses the pack when that book is empty.
  return fetchCatalog(language, source: server ? Source.server : null);
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
