import 'dart:math';

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

/// Download token stored on a Sighting. An in-review JPEG is not
/// world-readable. Another device loads it with this token.
bool sightingTokenOk(String token) {
  return RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(token);
}

/// A new download token for one Sighting JPEG.
String sightingDownloadToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The `token` query on a Firebase download URL, when it is well formed.
String? downloadTokenFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final token = uri.queryParameters['token']?.trim() ?? '';
  if (!sightingTokenOk(token)) return null;
  return token;
}

/// Download URL for one object in [sightingStorageBucket].
///
/// The host is the Firebase Storage API, so `firebase/storage.rules` applies.
/// A public Sighting can be read with no token. An in-review photo needs
/// [token], the download token stored on the sighting document. A full URL
/// is left as it is.
String sightingPhotoUrl(String path, {String? token}) {
  final object = path.trim();
  if (object.isEmpty) return '';
  if (object.startsWith('http://') || object.startsWith('https://')) {
    return object;
  }
  final encoded = Uri.encodeComponent(object);
  final base =
      'https://firebasestorage.googleapis.com/v0/b/$sightingStorageBucket/o/$encoded?alt=media';
  final download = token?.trim() ?? '';
  if (!sightingTokenOk(download)) return base;
  return '$base&token=${Uri.encodeQueryComponent(download)}';
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
