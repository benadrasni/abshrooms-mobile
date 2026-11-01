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
      final next = await _readCatalog(language, server: false);
      if (ticket != _ticket) return;
      data = next;
    } catch (caught) {
      if (ticket != _ticket) return;
      error = caught;
    } finally {
      if (ticket == _ticket) loading = false;
    }
  }

  /// Reads the book from the database and replaces the copy on screen. The
  /// stored offline file is used only when that read fails. Returns false
  /// when this read lost to a newer one, or the database could not be
  /// reached and no stored book is on the phone.
  Future<bool> refresh() async {
    final ticket = ++_ticket;
    try {
      final next = await _readCatalog(language, server: true);
      if (ticket != _ticket) return false;
      data = next;
      error = null;
      loading = false;
      return true;
    } catch (caught) {
      if (ticket != _ticket) return false;
      if (data == null) error = caught;
      loading = false;
      return false;
    }
  }
}

Future<Catalog> _readLiveCatalog(
  String language, {
  required bool server,
}) async {
  final packed = _packedCatalog(language);
  try {
    final read = debugCatalogRead;
    if (read != null) return await read(language, server: server);
    return await fetchCatalog(language, source: server ? Source.server : null);
  } catch (error) {
    debugPrint('catalog read: $error');
    if (packed != null) return packed;
    rethrow;
  }
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
