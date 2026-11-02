import 'package:firebase_storage/firebase_storage.dart';

/// Default Firebase Storage bucket. Catalog plates stay on
/// `abshrooms-resources`; a Sighting photo is written and read here.
const sightingStorageBucket = 'abshrooms-a9d4c.firebasestorage.app';

FirebaseStorage sightingStorage() {
  return FirebaseStorage.instanceFor(bucket: 'gs://$sightingStorageBucket');
}

/// A Sighting photo stored as its download URL, not a file on this phone.
bool sightingPhotoIsRemote(String? path) {
  if (path == null) return false;
  return path.startsWith('https://') || path.startsWith('http://');
}

/// JPEG upload. Content type only. The Storage client rejects
/// `firebaseStorageDownloadTokens` as custom metadata.
SettableMetadata sightingJpegMetadata() {
  return SettableMetadata(contentType: 'image/jpeg');
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

/// Object path of the guest-readable copy. The id is the sighting id.
/// An id with a slash or `..` is refused.
String publicSightingObject(String id) {
  final clean = id.trim();
  if (clean.isEmpty ||
      clean.contains('/') ||
      clean.contains('\\') ||
      clean.contains('..')) {
    return '';
  }
  return 'sightings/public/$clean.jpg';
}

/// Token-less URL for a public card photo. Any other path is empty, so a
/// guest page never requests `sightings/{uid}/`.
String publicSightingPhotoUrl(String path) {
  final object = path.trim();
  if (!RegExp(r'^sightings/public/[^/]+\.jpg$').hasMatch(object)) return '';
  return sightingPhotoUrl(object);
}

/// Object paths for one account's Sightings. Each document id is
/// `sightings/{uid}/{id}.jpg`, and the public copy is
/// `sightings/public/{id}.jpg`. A stored photo outside that account is
/// left out.
List<String> sightingObjectPaths(
  String uid,
  Iterable<({String id, String? photo})> rows,
) {
  final paths = <String>{};
  for (final row in rows) {
    if (row.id.isEmpty) continue;
    paths.add('sightings/$uid/${row.id}.jpg');
    final public = publicSightingObject(row.id);
    if (public.isNotEmpty) paths.add(public);
    final photo = row.photo?.trim() ?? '';
    if (photo.startsWith('sightings/$uid/') && photo.endsWith('.jpg')) {
      paths.add(photo);
    }
  }
  final ordered = paths.toList()..sort();
  return ordered;
}
