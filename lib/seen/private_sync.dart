import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/seen/share.dart';
import 'package:whats_that_mushroom/seen/sighting_storage.dart';

/// Private notebook for a Field Guide account. Rows and photos copy only
/// while that plan is active. A lapsed plan leaves what was already stored
/// and stops the watch. Guests and other accounts stay on the phone.
const privateFindsCollection = 'finds';

/// Storage object for one private photo. Empty when [id] is not a file name.
String privatePhotoObject(String uid, String id) {
  final cleanUid = uid.trim();
  final cleanId = id.trim();
  if (cleanUid.isEmpty ||
      cleanId.isEmpty ||
      cleanUid.contains('/') ||
      cleanId.contains('/') ||
      cleanId.contains('..')) {
    return '';
  }
  return 'private/$cleanUid/$cleanId.jpg';
}

/// Fields stored on `users/{uid}/finds/{id}`. The phone path stays local.
/// A half place, a probability outside 0–1, or a long list of other names
/// is left off so the rest of the find can still be stored.
Map<String, dynamic> privateFindData(FindRecord find) {
  final lat = find.latitude;
  final lng = find.longitude;
  final place =
      lat != null &&
      lng != null &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0 && lng == 0);
  final probability = find.probability;
  final others = find.others.length > 11
      ? find.others.sublist(0, 11)
      : find.others;
  return {
    'millis': find.millis,
    'updated': find.updated,
    'confirmed': find.confirmed,
    if (_nameOk(find.latin)) 'latin': find.latin,
    if (_nameOk(find.outsideName)) 'outsideName': find.outsideName,
    if (_nameOk(find.spoken)) 'spoken': find.spoken,
    if (probability != null && probability >= 0 && probability <= 1)
      'probability': probability,
    if (place) 'latitude': lat,
    if (place) 'longitude': lng,
    if (_countryOk(find.country)) 'country': find.country,
    if (find.share != FindShare.none) 'share': find.share.name,
    if (others.isNotEmpty) 'others': [for (final name in others) name.toJson()],
  };
}

bool _nameOk(String? value) {
  if (value == null) return false;
  final text = value.trim();
  return text.isNotEmpty && text.length < 200;
}

bool _countryOk(String? value) {
  if (value == null || value.length != 2) return false;
  for (final unit in value.codeUnits) {
    if (unit < 0x61 || unit > 0x7a) return false;
  }
  return true;
}

/// One account row turned back into a find. [photoPath] is a file or a
/// Sighting URL already on this phone. The storage path is not a file.
FindRecord findFromPrivate(
  String id,
  Map<String, dynamic> data, {
  String? photoPath,
  String? syncedUid,
}) {
  return FindRecord.fromJson({
    'id': id,
    'millis': data['millis'],
    'confirmed': data['confirmed'] == true,
    if (data['latin'] != null) 'latin': data['latin'],
    if (data['outsideName'] != null) 'outsideName': data['outsideName'],
    if (data['spoken'] != null) 'spoken': data['spoken'],
    if (data['probability'] != null) 'probability': data['probability'],
    if (data['latitude'] != null) 'latitude': data['latitude'],
    if (data['longitude'] != null) 'longitude': data['longitude'],
    if (data['country'] != null) 'country': data['country'],
    if (data['share'] != null) 'share': data['share'],
    if (data['others'] is List) 'others': data['others'],
    if (data['updated'] is num) 'updated': (data['updated'] as num).toInt(),
    if (photoPath != null) 'photoPath': photoPath,
    if (syncedUid != null) 'syncedUid': syncedUid,
  });
}

bool samePrivateFind(FindRecord find, Map<String, dynamic> data) {
  final other = findFromPrivate(find.id, data, photoPath: find.photoPath);
  return other.millis == find.millis &&
      other.latin == find.latin &&
      other.outsideName == find.outsideName &&
      other.spoken == find.spoken &&
      other.probability == find.probability &&
      other.confirmed == find.confirmed &&
      other.latitude == find.latitude &&
      other.longitude == find.longitude &&
      other.country == find.country &&
      other.share == find.share &&
      _sameOthers(other.others, find.others);
}

bool _sameOthers(List<FindName> left, List<FindName> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    final a = left[i];
    final b = right[i];
    if (a.scientificName != b.scientificName ||
        a.probability != b.probability) {
      return false;
    }
    if (a.commonNames.length != b.commonNames.length) return false;
    for (var n = 0; n < a.commonNames.length; n++) {
      if (a.commonNames[n] != b.commonNames[n]) return false;
    }
  }
  return true;
}

int _updated(Map<String, dynamic>? data) {
  final value = data?['updated'];
  if (value is! num) return 0;
  return value.toInt();
}

/// What one snapshot should do to the phone notebook.
class PrivateSyncPlan {
  final List<FindRecord> finds;
  final bool changed;
  final List<FindRecord> upload;
  final List<String> deleteRemote;
  final List<String> deleteFiles;
  final List<({String id, String object})> downloads;

  const PrivateSyncPlan({
    required this.finds,
    required this.changed,
    required this.upload,
    required this.deleteRemote,
    required this.deleteFiles,
    required this.downloads,
  });
}

/// Merges [remote] into [local]. A row already synced to [uid] and missing
/// from a server snapshot is removed when [allowDrops] is set. A cache
/// snapshot leaves those rows. [deletedLocal] was removed on this phone
/// and must not come back from an older snapshot.
PrivateSyncPlan planPrivateSync({
  required String uid,
  required List<FindRecord> local,
  required Map<String, Map<String, dynamic>> remote,
  required bool allowDrops,
  required Set<String> deletedLocal,
  required bool Function(String? path) onPhone,
  required int now,
}) {
  final next = <FindRecord>[];
  final upload = <FindRecord>[];
  final deleteFiles = <String>[];
  final downloads = <({String id, String object})>[];
  final localIds = <String>{};
  var changed = false;

  for (final find in local) {
    if (find.id.isEmpty) {
      next.add(find);
      continue;
    }
    localIds.add(find.id);
    if (find.syncedUid != null && find.syncedUid != uid) {
      next.add(find);
      continue;
    }
    final data = remote[find.id];
    if (data == null) {
      if (find.syncedUid == uid && allowDrops) {
        changed = true;
        if (onPhone(find.photoPath)) deleteFiles.add(find.photoPath!);
        continue;
      }
      if (find.syncedUid == uid) {
        next.add(find);
        continue;
      }
      if (find.millis <= 0) {
        next.add(find);
        continue;
      }
      final stamped = find.updated > 0 ? find : find.copyWith(updated: now);
      upload.add(stamped);
      if (stamped.updated != find.updated) changed = true;
      next.add(stamped);
      continue;
    }
    final remoteUpdated = _updated(data);
    final object = _photoObject(uid, find.id, data);
    final photoMissing = _photoMissing(uid, find, data, onPhone);
    if (remoteUpdated > find.updated) {
      final applied = _applied(find, data, uid, onPhone);
      next.add(applied);
      changed = true;
      // The other phone edited the row. Keep those fields, and still send
      // a photo this phone has when the account copy has none.
      if (photoMissing) upload.add(applied);
      _queueDownload(downloads, applied, object, onPhone);
      continue;
    }
    if (remoteUpdated < find.updated ||
        !samePrivateFind(find, data) ||
        photoMissing) {
      final stamped = find.updated > 0 ? find : find.copyWith(updated: now);
      upload.add(stamped);
      final kept = find.syncedUid == uid
          ? stamped
          : stamped.copyWith(setSyncedUid: true, syncedUid: uid);
      if (kept.syncedUid != find.syncedUid || kept.updated != find.updated) {
        changed = true;
      }
      next.add(kept);
    } else {
      final kept = find.syncedUid == uid
          ? find
          : find.copyWith(setSyncedUid: true, syncedUid: uid);
      if (kept.syncedUid != find.syncedUid) changed = true;
      next.add(kept);
    }
    _queueDownload(downloads, find, object, onPhone);
  }

  for (final entry in remote.entries) {
    if (localIds.contains(entry.key) || deletedLocal.contains(entry.key)) {
      continue;
    }
    final applied = findFromPrivate(entry.key, entry.value, syncedUid: uid);
    if (applied.millis <= 0) continue;
    next.add(applied);
    changed = true;
    _queueDownload(
      downloads,
      applied,
      _photoObject(uid, entry.key, entry.value),
      onPhone,
    );
  }

  if (changed) {
    next.sort((a, b) {
      final byWhen = b.millis.compareTo(a.millis);
      if (byWhen != 0) return byWhen;
      return b.id.compareTo(a.id);
    });
  }

  final deleteRemote = <String>[
    for (final id in deletedLocal)
      if (remote.containsKey(id)) id,
  ];
  return PrivateSyncPlan(
    finds: changed ? next : local,
    changed: changed,
    upload: upload,
    deleteRemote: deleteRemote,
    deleteFiles: deleteFiles,
    downloads: downloads,
  );
}

String _photoObject(String uid, String id, Map<String, dynamic> data) {
  final photo = data['photo']?.toString() ?? '';
  final object = privatePhotoObject(uid, id);
  if (photo.isEmpty || object.isEmpty || photo != object) return '';
  return object;
}

/// This phone has the JPEG and the account row does not name it yet.
bool _photoMissing(
  String uid,
  FindRecord find,
  Map<String, dynamic> data,
  bool Function(String? path) onPhone,
) {
  if (!onPhone(find.photoPath)) return false;
  final object = privatePhotoObject(uid, find.id);
  if (object.isEmpty) return false;
  return data['photo']?.toString() != object;
}

FindRecord _applied(
  FindRecord find,
  Map<String, dynamic> data,
  String uid,
  bool Function(String? path) onPhone,
) {
  final keep = onPhone(find.photoPath) || sightingPhotoIsRemote(find.photoPath)
      ? find.photoPath
      : null;
  return findFromPrivate(find.id, data, photoPath: keep, syncedUid: uid);
}

void _queueDownload(
  List<({String id, String object})> downloads,
  FindRecord find,
  String object,
  bool Function(String? path) onPhone,
) {
  if (object.isEmpty || onPhone(find.photoPath)) return;
  if (sightingPhotoIsRemote(find.photoPath)) return;
  downloads.add((id: find.id, object: object));
}

/// Watches `users/{uid}/finds` while Field Guide is on and copies photos
/// to `private/{uid}/{id}.jpg`. Signing out or losing the plan stops the
/// watch. Rows already on the phone stay.
class PrivateNotebookSync {
  final Notebook notebook;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  Map<String, Map<String, dynamic>> _remote = {};
  final Set<String> _gone = {};
  var _applying = false;
  var _pushing = false;
  var _pushAgain = false;
  var _stopped = false;

  PrivateNotebookSync(this.notebook) {
    notebook.addListener(_onLocal);
  }

  void retarget() {
    if (_stopped) return;
    final uid = _accountUid();
    if (uid == null || !Purchases.hasFieldGuide()) {
      _stopWatch();
      return;
    }
    if (uid == _uid && _sub != null) return;
    _stopWatch();
    _uid = uid;
    _remote = {};
    _gone.clear();
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(privateFindsCollection)
        .snapshots()
        .listen(
          (snap) => unawaited(_onSnap(uid, snap)),
          onError: (Object error) {
            debugPrint('private finds: $error');
          },
        );
  }

  void stop() {
    _stopped = true;
    notebook.removeListener(_onLocal);
    _stopWatch();
  }

  void _stopWatch() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _remote = {};
    _gone.clear();
  }

  String? _accountUid() {
    if (notebook.favoriteAccount != null) return null;
    final user = Auth.appUser;
    if (user == null || user.isAnonymous) return null;
    return user.uid;
  }

  void _onLocal() {
    if (_applying || _stopped) return;
    final uid = _uid;
    if (uid == null) return;
    final ids = {for (final find in notebook.finds) find.id};
    for (final id in _remote.keys) {
      if (!ids.contains(id)) _gone.add(id);
    }
    unawaited(_push());
  }

  Future<void> _onSnap(
    String uid,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    if (_uid != uid || _stopped || !Purchases.hasFieldGuide()) return;
    _remote = {for (final doc in snap.docs) doc.id: doc.data()};
    final allowDrops = !snap.metadata.isFromCache;
    // File deletes wait. A find removed on this phone during that wait
    // must not be written back from the plan taken before the delete.
    final dropping = _plan(uid, allowDrops);
    for (final path in dropping.deleteFiles) {
      final file = File(path);
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // The file is already gone.
      }
    }
    if (_uid != uid || _stopped || !Purchases.hasFieldGuide()) return;
    final plan = _plan(uid, allowDrops);
    if (plan.changed) {
      _applying = true;
      try {
        await notebook.replaceAll(plan.finds);
      } finally {
        _applying = false;
      }
    }
    if (_uid != uid || !Purchases.hasFieldGuide()) return;
    await _fetchPhotos(uid, plan.downloads);
    await _push();
  }

  PrivateSyncPlan _plan(String uid, bool allowDrops) {
    return planPrivateSync(
      uid: uid,
      local: notebook.finds,
      remote: _remote,
      allowDrops: allowDrops,
      deletedLocal: _gone,
      onPhone: seenPhotoOnPhone,
      now: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _push() async {
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    _pushing = true;
    try {
      do {
        _pushAgain = false;
        await _pushOnce();
      } while (_pushAgain && _uid != null);
    } finally {
      _pushing = false;
    }
  }

  Future<void> _pushOnce() async {
    final uid = _uid;
    if (uid == null || _stopped || !Purchases.hasFieldGuide()) return;
    final plan = _plan(uid, false);
    for (final id in plan.deleteRemote) {
      await _deleteRemote(uid, id);
      _remote.remove(id);
      _gone.remove(id);
    }
    if (plan.upload.isEmpty) return;
    final done = <FindRecord>[];
    for (final find in plan.upload) {
      if (_uid != uid) return;
      try {
        await _upload(uid, find);
        done.add(find);
      } catch (error) {
        debugPrint('private find ${find.id}: $error');
      }
    }
    if (done.isEmpty || _uid != uid) return;
    final byId = {for (final find in done) find.id: find};
    final next = [
      for (final find in notebook.finds)
        if (byId[find.id] != null && find.updated <= byId[find.id]!.updated)
          find.copyWith(
            updated: byId[find.id]!.updated,
            setSyncedUid: true,
            syncedUid: uid,
          )
        else
          find,
    ];
    _applying = true;
    try {
      await notebook.replaceAll(next);
    } finally {
      _applying = false;
    }
  }

  Future<void> _upload(String uid, FindRecord find) async {
    final data = privateFindData(find);
    final object = privatePhotoObject(uid, find.id);
    if (object.isNotEmpty && seenPhotoOnPhone(find.photoPath)) {
      await sightingStorage()
          .ref(object)
          .putFile(File(find.photoPath!), sightingJpegMetadata());
      data['photo'] = object;
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(privateFindsCollection)
        .doc(find.id)
        .set(data);
    _remote[find.id] = data;
  }

  Future<void> _fetchPhotos(
    String uid,
    List<({String id, String object})> downloads,
  ) async {
    for (final row in downloads) {
      if (_uid != uid) return;
      final path = notebook.photoFile(row.id);
      if (path == null) continue;
      final file = File(path);
      try {
        if (await file.exists() && await file.length() > 0) {
          await _keepPhoto(row.id, path);
          continue;
        }
        await file.parent.create(recursive: true);
        await sightingStorage().ref(row.object).writeToFile(file);
        if (await file.exists() && await file.length() > 0) {
          await _keepPhoto(row.id, path);
        }
      } catch (error) {
        debugPrint('private photo ${row.id}: $error');
      }
    }
  }

  Future<void> _keepPhoto(String id, String path) async {
    var changed = false;
    final next = [
      for (final find in notebook.finds)
        if (find.id == id && find.photoPath != path)
          () {
            changed = true;
            return find.copyWith(photoPath: path);
          }()
        else
          find,
    ];
    if (!changed) return;
    _applying = true;
    try {
      await notebook.replaceAll(next);
    } finally {
      _applying = false;
    }
  }

  Future<void> _deleteRemote(String uid, String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(privateFindsCollection)
          .doc(id)
          .delete();
    } catch (error) {
      debugPrint('private find delete $id: $error');
    }
    final object = privatePhotoObject(uid, id);
    if (object.isEmpty) return;
    try {
      await sightingStorage().ref(object).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        debugPrint('private photo delete $id: $error');
      }
    }
  }
}

/// Removes the account notebook and its private photos.
/// A missing row does not block account deletion.
Future<void> deletePrivateFinds(String uid) async {
  if (uid.isEmpty) return;
  try {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(privateFindsCollection);
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) return;
      for (final doc in snap.docs) {
        final object = privatePhotoObject(uid, doc.id);
        if (object.isEmpty) continue;
        try {
          await sightingStorage().ref(object).delete();
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') rethrow;
        }
      }
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < 400) return;
    }
  } on FirebaseException catch (error) {
    if (error.code == 'permission-denied' || error.code == 'not-found') {
      return;
    }
    rethrow;
  }
}
