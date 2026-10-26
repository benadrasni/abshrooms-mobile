import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/seen/sighting_storage.dart';
import 'package:whats_that_mushroom/seen/stats.dart';

/// One accepted Sighting for a species page.
class SpeciesSighting {
  final String id;
  final String url;
  final DateTime? when;

  /// Lowercase ISO country code, when the row has one.
  final String? country;

  const SpeciesSighting({
    required this.id,
    required this.url,
    this.when,
    this.country,
  });
}

/// Public rows, newest first. A review or rejected row is left out.
/// A missing status is kept: the query already asked for public rows.
List<SpeciesSighting> speciesSightingsFromDocs(
  Iterable<({String id, Map<String, dynamic> data})> docs,
) {
  final rows = <SpeciesSighting>[];
  for (final doc in docs) {
    final row = _row(doc.id, doc.data);
    if (row != null) rows.add(row);
  }
  rows.sort((a, b) {
    final aw = a.when?.millisecondsSinceEpoch ?? 0;
    final bw = b.when?.millisecondsSinceEpoch ?? 0;
    return bw.compareTo(aw);
  });
  return rows;
}

SpeciesSighting? _row(String id, Map<String, dynamic> data) {
  final status = data['status'];
  if (status != null && status != 'public') return null;
  final photo = data['photo']?.toString().trim() ?? '';
  final url = sightingPhotoUrl(photo);
  if (url.isEmpty) return null;
  final millis = data['millis'];
  final when = millis is num
      ? DateTime.fromMillisecondsSinceEpoch(millis.round())
      : null;
  return SpeciesSighting(
    id: id,
    url: url,
    when: when,
    country: statCountry(data['country']),
  );
}

/// Public Sightings for one Latin name. No Firebase returns an empty list.
Future<List<SpeciesSighting>> loadSpeciesSightings(String latin) async {
  try {
    if (Firebase.apps.isEmpty) return const [];
  } catch (_) {
    return const [];
  }
  try {
    final snap = await FirebaseFirestore.instance
        .collection('sightings')
        .where('latin', isEqualTo: latin)
        .where('status', isEqualTo: 'public')
        .get();
    return speciesSightingsFromDocs([
      for (final doc in snap.docs) (id: doc.id, data: doc.data()),
    ]);
  } catch (error) {
    debugPrint('species sightings: $error');
    rethrow;
  }
}
