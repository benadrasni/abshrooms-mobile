import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:whats_that_mushroom/data/models.dart';

class CatalogRepository {
  Catalog? data;
  Object? error;
  bool loading = false;
  String language = 'en';

  Future<void> load(String language) async {
    this.language = language;
    loading = true;
    error = null;
    try {
      data = await fetchCatalog(language);
    } catch (caught) {
      error = caught;
    } finally {
      loading = false;
    }
  }
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

Future<Catalog> fetchCatalog(String language) async {
  final db = FirebaseFirestore.instance;
  final key = await loadKeyAsset();
  final speciesSnap = await db.collection('species').get();
  final localSnap = await db
      .collection('translations')
      .doc(language)
      .collection('species')
      .get();
  final englishSnap = language == 'en'
      ? localSnap
      : await db
            .collection('translations')
            .doc('en')
            .collection('species')
            .get();
  final synonymSnap = await db.collection('synonyms').get();
  final taxaSnap = await db
      .collection('taxonomy')
      .doc(language)
      .collection('taxa')
      .get();
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
