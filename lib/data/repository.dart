import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/models.dart';

/// Reads one language of the book. [server] skips the on-disk cache.
typedef CatalogRead = Future<Catalog> Function(
  String language, {
  required bool server,
});

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

  /// One read of `curated_lists`. An older in-flight read does not overwrite
  /// a newer one. Permission-denied stays an empty snapshot.
  Future<void> loadCuratedLists() async {
    final ticket = ++_listsTicket;
    final snapshot = await fetchCuratedLists();
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

  /// Reads the book from the server. The copy already on screen stays when
  /// the phone is offline. A warm process otherwise keeps the launch
  /// snapshot, so Seen, Seen lately, and New in the book change only after
  /// the app is killed. Returns false when this read lost to a newer one
  /// or the server could not be reached.
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

Future<Catalog> _readLiveCatalog(String language, {required bool server}) {
  return fetchCatalog(language, source: server ? Source.server : null);
}

Future<Map<String, KeyFacts>> loadKeyAsset() async {
  final raw = await rootBundle.loadString('assets/key.json');
  final decoded = json.decode(raw) as Map<String, dynamic>;
  return decoded.map((name, value) {
    final map = value as Map<String, dynamic>;
    return MapEntry(
      name,
      KeyFacts(
        hymenium: map['hymenium']?.toString() ?? '',
        where:
            (map['where'] as List?)?.map((item) => item.toString()).toList() ??
            const [],
        color:
            (map['color'] as List?)?.map((item) => item.toString()).toList() ??
            const [],
        added: map['added']?.toString() ?? '',
      ),
    );
  });
}

Future<Catalog> fetchCatalog(String language, {Source? source}) async {
  final db = FirebaseFirestore.instance;
  final options = source == null ? null : GetOptions(source: source);
  final key = await loadKeyAsset();
  final speciesSnap = await db.collection('species').get(options);
  final localSnap = await db
      .collection('translations')
      .doc(language)
      .collection('species')
      .get(options);
  final englishSnap = language == 'en'
      ? localSnap
      : await db
            .collection('translations')
            .doc('en')
            .collection('species')
            .get(options);
  final synonymSnap = await db.collection('synonyms').get(options);
  final taxaSnap = await db
      .collection('taxonomy')
      .doc(language)
      .collection('taxa')
      .get(options);
  return buildCatalog(
    language: language,
    speciesDocs: [for (final doc in speciesSnap.docs) Doc(doc.id, doc.data())],
    local: _byId(localSnap.docs),
    english: _byId(englishSnap.docs),
    synonyms: _byId(synonymSnap.docs),
    taxa: {
      for (final doc in taxaSnap.docs)
        doc.id: doc.data()['vernacular']?.toString() ?? '',
    },
    key: key,
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
