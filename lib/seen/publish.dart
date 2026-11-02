import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/seen/country.dart';
import 'package:whats_that_mushroom/seen/share.dart';
import 'package:whats_that_mushroom/seen/sighting_storage.dart';
import 'package:whats_that_mushroom/seen/stats.dart';
import 'package:whats_that_mushroom/species/seen_photo.dart';

/// Publishes one confirmed find for review. Returns false when there is no
/// account, no photo, or the write fails. The photo's location is removed.
/// The document keeps the country and the coordinates when the find has a place.
Future<bool> publishSighting(
  FindRecord find, {
  Future<String?> Function(double latitude, double longitude)? countryOf,
}) async {
  try {
    final user = _account();
    final latin = find.latin?.trim() ?? '';
    final path = find.photoPath;
    if (user == null || !find.confirmed || latin.isEmpty || path == null) {
      return false;
    }
    final file = File(path);
    if (!await file.exists()) return false;
    final photo = seenPhotoFromBytes(await file.readAsBytes());
    if (photo == null) return false;
    final object = _objectPath(user.uid, find.id);
    await sightingStorage()
        .ref(object)
        .putData(photo.bytes, sightingJpegMetadata());
    final country = await sightingCountryForShare(find, lookup: countryOf);
    await FirebaseFirestore.instance
        .collection('sightings')
        .doc(find.id)
        .set(
          sightingCreateFields(
            uid: user.uid,
            id: find.id,
            latin: latin,
            millis: find.millis,
            country: country,
            latitude: find.latitude,
            longitude: find.longitude,
          ),
        );
    return true;
  } catch (error) {
    debugPrint('seen share: $error');
    return false;
  }
}

/// Fields for a new Sighting. [country] is a lowercase ISO code. Coordinates
/// are copied when they are a real place. 0, 0 stays off the document.
Map<String, Object> sightingCreateFields({
  required String uid,
  required String id,
  required String latin,
  required int millis,
  String? country,
  double? latitude,
  double? longitude,
}) {
  return {
    'uid': uid,
    'latin': latin,
    'millis': millis,
    'status': 'review',
    'photo': 'sightings/$uid/$id.jpg',
    ...sightingPlacePatch(
      country: country,
      latitude: latitude,
      longitude: longitude,
      remote: const {},
    ),
  };
}

/// Country and coordinates to add. A value the document already has stays.
Map<String, Object> sightingPlacePatch({
  required String? country,
  required double? latitude,
  required double? longitude,
  required Map<String, dynamic> remote,
}) {
  final patch = <String, Object>{};
  final code = statCountry(country);
  if (code != null && statCountry(remote['country']) == null) {
    patch['country'] = code;
  }
  final place = latitude == null || longitude == null
      ? null
      : photoPlace(latitude, longitude);
  if (place != null &&
      remote['latitude'] is! num &&
      remote['longitude'] is! num) {
    patch['latitude'] = place.latitude;
    patch['longitude'] = place.longitude;
  }
  return patch;
}

/// A place already stored on a Sighting. Anything else is absent.
PhotoPlace? sightingStoredPlace(Object? latitude, Object? longitude) {
  if (latitude is! num || longitude is! num) return null;
  return photoPlace(latitude.toDouble(), longitude.toDouble());
}

/// Removes a sent find from Sightings. The notebook row stays.
Future<bool> withdrawSighting(FindRecord find) async {
  return _removeSighting(find.id);
}

/// Removes the cloud copy of a sent find. Local deletion is separate.
Future<bool> deleteSighting(FindRecord find) async {
  return _removeSighting(find.id);
}

/// The send writes `review` into the on-phone cache. A default get returns
/// that copy, so Seen stays on In review after the sighting is accepted.
const sightingGetOptions = GetOptions(source: Source.server);

/// Copies this account's Sightings onto the notebook.
///
/// A document that is not already on the phone is added, with its photo
/// URL, so Find and Seen show it after sign-in. A sent find whose document
/// is gone returns to [FindShare.none]. A row whose only photo is that
/// Sighting is removed, because the document was its only copy. A review
/// that publishes the find under another catalog name replaces the name
/// on the phone. The same list is not written again.
/// The read asks the server. Offline, this keeps the notebook as it is.
Future<void> syncSightings(Notebook notebook) async {
  try {
    final user = _account();
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('sightings')
        .where('uid', isEqualTo: user.uid)
        .get(sightingGetOptions);
    final remote = [
      for (final doc in snap.docs)
        (id: doc.id, data: Map<String, dynamic>.from(doc.data())),
    ];
    await _cacheOwnerDownloadUrls(remote);
    final next = mergeAccountSightings(notebook.finds, remote);
    if (identical(next, notebook.finds)) return;
    await notebook.replaceAll(next);
  } catch (error) {
    debugPrint('seen share sync: $error');
  }
}

/// One Sighting document, as `id` plus its fields.
typedef SightingRow = ({String id, Map<String, dynamic> data});

/// The notebook plus this account's Sightings. Returns [local] unchanged
/// when nothing was added or updated.
List<FindRecord> mergeAccountSightings(
  List<FindRecord> local,
  Iterable<SightingRow> remote,
) {
  final byId = <String, Map<String, dynamic>>{};
  final order = <SightingRow>[];
  for (final row in remote) {
    if (row.id.isEmpty || byId.containsKey(row.id)) continue;
    byId[row.id] = row.data;
    order.add(row);
  }
  final seen = <String>{};
  final next = <FindRecord>[];
  var changed = false;
  for (final find in local) {
    seen.add(find.id);
    final data = byId[find.id];
    if (data == null) {
      if (sightingPhotoIsRemote(find.photoPath)) {
        changed = true;
        continue;
      }
      if (find.share == FindShare.none) {
        next.add(find);
      } else {
        changed = true;
        next.add(find.copyWith(share: FindShare.none));
      }
      continue;
    }
    final merged = _withSighting(find, data);
    if (identical(merged, find)) {
      next.add(find);
    } else {
      changed = true;
      next.add(merged);
    }
  }
  for (final row in order) {
    if (seen.contains(row.id)) continue;
    final added = _importedSighting(row.id, row.data);
    if (added == null) continue;
    changed = true;
    next.add(added);
  }
  if (!changed) return local;
  next.sort((a, b) {
    final byWhen = b.millis.compareTo(a.millis);
    if (byWhen != 0) return byWhen;
    return b.id.compareTo(a.id);
  });
  return next;
}

FindRecord _withSighting(FindRecord find, Map<String, dynamic> data) {
  final share = findShareFrom(data['status']);
  final photo = _sightingPhoto(find, data);
  final country = statCountry(data['country']) ?? find.country;
  final latin = _sightingLatin(find, data);
  final place = sightingStoredPlace(data['latitude'], data['longitude']);
  final latitude = place?.latitude ?? find.latitude;
  final longitude = place?.longitude ?? find.longitude;
  if (share == find.share &&
      photo == find.photoPath &&
      country == find.country &&
      latin == find.latin &&
      latitude == find.latitude &&
      longitude == find.longitude) {
    return find;
  }
  return find.copyWith(
    share: share,
    photoPath: photo,
    country: country,
    latin: latin,
    latitude: latitude,
    longitude: longitude,
    setPlace: true,
  );
}

/// Review can publish a find under a different catalog name. The notebook
/// takes that name. A document with no latin leaves the name on the phone.
String? _sightingLatin(FindRecord find, Map<String, dynamic> data) {
  final latin = data['latin']?.toString().trim() ?? '';
  if (latin.isEmpty) return find.latin;
  return latin;
}

/// Keeps a file on this phone. A public Sighting uses the token-less URL.
/// An in-review photo uses the download URL cached on this device.
String? _sightingPhoto(FindRecord find, Map<String, dynamic> data) {
  if (seenPhotoOnPhone(find.photoPath)) return find.photoPath;
  final photo = data['photo']?.toString().trim() ?? '';
  if (data['status'] == 'public') {
    final url = sightingPhotoUrl(photo);
    return url.isEmpty ? find.photoPath : url;
  }
  final cached = _ownerDownloadUrl(data);
  if (cached != null) return cached;
  if (sightingPhotoIsRemote(find.photoPath)) return find.photoPath;
  return find.photoPath;
}

/// Set by sync after the owner calls getDownloadURL. Not a Firestore field.
String? _ownerDownloadUrl(Map<String, dynamic> data) {
  final url = data['downloadUrl']?.toString().trim() ?? '';
  if (url.startsWith('https://') || url.startsWith('http://')) return url;
  return null;
}

/// In-review and rejected photos stay owner-only. The signed-in owner asks
/// Storage for a download URL and the notebook keeps it. The document does not.
Future<void> _cacheOwnerDownloadUrls(List<SightingRow> remote) async {
  for (final row in remote) {
    if (row.data['status'] == 'public') continue;
    final photo = row.data['photo']?.toString().trim() ?? '';
    if (!photo.startsWith('sightings/') || !photo.endsWith('.jpg')) continue;
    try {
      row.data['downloadUrl'] = await sightingStorage()
          .ref(photo)
          .getDownloadURL();
    } catch (error) {
      debugPrint('sighting photo: $error');
    }
  }
}

FindRecord? _importedSighting(String id, Map<String, dynamic> data) {
  final latin = data['latin']?.toString().trim() ?? '';
  final millis = data['millis'];
  if (latin.isEmpty || millis is! num || millis <= 0) return null;
  final photo = data['photo']?.toString().trim() ?? '';
  final url = data['status'] == 'public'
      ? sightingPhotoUrl(photo)
      : (_ownerDownloadUrl(data) ?? '');
  final place = sightingStoredPlace(data['latitude'], data['longitude']);
  return FindRecord(
    id: id,
    millis: millis.round(),
    latin: latin,
    photoPath: url.isEmpty ? null : url,
    confirmed: true,
    share: findShareFrom(data['status']),
    country: statCountry(data['country']),
    latitude: place?.latitude,
    longitude: place?.longitude,
  );
}

/// Writes the ISO country onto this account's Sighting when the document
/// has none. A missing document or a rules rejection leaves the share in
/// place. True when the document already has a country, or the write landed.
Future<bool> writeSightingCountry(String id, String code) async {
  if (statCountry(code) == null || id.isEmpty) return false;
  return writeSightingPlace(FindRecord(id: id, millis: 0, country: code));
}

/// Writes a missing country and missing coordinates onto this account's
/// Sighting. A value already on the document stays. True when there was
/// nothing to add, or the write landed.
Future<bool> writeSightingPlace(FindRecord find) async {
  final country = statCountry(find.country);
  final latitude = find.latitude;
  final longitude = find.longitude;
  final place = latitude == null || longitude == null
      ? null
      : photoPlace(latitude, longitude);
  if ((country == null && place == null) || find.id.isEmpty) return false;
  try {
    final user = _account();
    if (user == null) return false;
    final ref = FirebaseFirestore.instance.collection('sightings').doc(find.id);
    final snap = await ref.get();
    if (!snap.exists) return false;
    final data = snap.data();
    if (data == null) return false;
    if (data['uid'] != user.uid) return true;
    final patch = sightingPlacePatch(
      country: country,
      latitude: latitude,
      longitude: longitude,
      remote: data,
    );
    if (patch.isEmpty) return true;
    await ref.update(patch);
    return true;
  } catch (error) {
    debugPrint('sighting place ${find.id}: $error');
    return false;
  }
}

String _objectPath(String uid, String id) => 'sightings/$uid/$id.jpg';

/// Deletes this account's Sighting documents and their JPEGs.
/// A missing file is already gone. Any other failure stops account deletion.
Future<void> deleteOwnedSightings(String uid) async {
  if (uid.isEmpty) return;
  final snap = await FirebaseFirestore.instance
      .collection('sightings')
      .where('uid', isEqualTo: uid)
      .get();
  final paths = sightingObjectPaths(uid, [
    for (final doc in snap.docs)
      (id: doc.id, photo: doc.data()['photo']?.toString()),
  ]);
  final storage = sightingStorage();
  for (final path in paths) {
    try {
      await storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
  for (final doc in snap.docs) {
    await doc.reference.delete();
  }
}

/// Whether [publishSighting] may write for this Firebase user.
/// An unverified password account is not signed in.
@visibleForTesting
bool sightingAccountSignedIn({
  required bool firebaseReady,
  required bool hasUser,
  required bool anonymous,
  required bool emailVerified,
  required Iterable<String> providerIds,
}) {
  if (!firebaseReady || !hasUser || anonymous) return false;
  return !passwordEmailUnverified(
    anonymous: anonymous,
    emailVerified: emailVerified,
    providerIds: providerIds,
  );
}

User? _account() {
  User? user;
  var ready = false;
  try {
    ready = Firebase.apps.isNotEmpty;
    if (ready) user = FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
  if (user == null ||
      !sightingAccountSignedIn(
        firebaseReady: ready,
        hasUser: true,
        anonymous: user.isAnonymous,
        emailVerified: user.emailVerified,
        providerIds: [for (final info in user.providerData) info.providerId],
      )) {
    return null;
  }
  return user;
}

Future<bool> _removeSighting(String id) async {
  try {
    final user = _account();
    if (user == null || id.isEmpty) return false;
    final ref = FirebaseFirestore.instance.collection('sightings').doc(id);
    final snap = await ref.get();
    if (snap.exists && snap.data()?['uid'] != user.uid) return false;
    try {
      await sightingStorage().ref(_objectPath(user.uid, id)).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        debugPrint('seen share photo: $error');
      }
    }
    if (snap.exists) await ref.delete();
    return true;
  } catch (error) {
    debugPrint('seen share withdraw: $error');
    return false;
  }
}
