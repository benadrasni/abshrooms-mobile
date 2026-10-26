import 'package:firebase_storage/firebase_storage.dart';

/// Default Firebase Storage bucket. Catalog plates stay on
/// `abshrooms-resources`; a Sighting photo is written and read here.
const sightingStorageBucket = 'abshrooms-a9d4c.firebasestorage.app';

FirebaseStorage sightingStorage() {
  return FirebaseStorage.instanceFor(bucket: 'gs://$sightingStorageBucket');
}

/// Download URL for one object in [sightingStorageBucket].
///
/// The host is the Firebase Storage API, so `firebase/storage.rules` applies.
/// A full URL is left as it is.
String sightingPhotoUrl(String path) {
  final object = path.trim();
  if (object.isEmpty) return '';
  if (object.startsWith('http://') || object.startsWith('https://')) {
    return object;
  }
  final encoded = Uri.encodeComponent(object);
  return 'https://firebasestorage.googleapis.com/v0/b/$sightingStorageBucket/o/$encoded?alt=media';
}

/// Object paths for one account's Sightings. Each document id is
/// `sightings/{uid}/{id}.jpg`. A stored photo outside that prefix is left out.
List<String> sightingObjectPaths(
  String uid,
  Iterable<({String id, String? photo})> rows,
) {
  final paths = <String>{};
  for (final row in rows) {
    if (row.id.isEmpty) continue;
    paths.add('sightings/$uid/${row.id}.jpg');
    final photo = row.photo?.trim() ?? '';
    if (photo.startsWith('sightings/$uid/') && photo.endsWith('.jpg')) {
      paths.add(photo);
    }
  }
  final ordered = paths.toList()..sort();
  return ordered;
}
