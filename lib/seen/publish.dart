import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/seen/sighting_storage.dart';
import 'package:whats_that_mushroom/species/seen_photo.dart';

/// Publishes one confirmed find for review. Returns false when there is no
/// account, no photo, or the write fails. The place stays off the photo.
Future<bool> publishSighting(FindRecord find) async {
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
        .putData(photo.bytes, SettableMetadata(contentType: 'image/jpeg'));
    await FirebaseFirestore.instance.collection('sightings').doc(find.id).set({
      'uid': user.uid,
      'latin': latin,
      'millis': find.millis,
      'status': 'review',
      'photo': object,
    });
    return true;
  } catch (error) {
    debugPrint('seen share: $error');
    return false;
  }
}

/// Removes a sent find from Sightings. The notebook row stays.
Future<bool> withdrawSighting(FindRecord find) async {
  return _removeSighting(find.id);
}

/// Removes the cloud copy of a sent find. Local deletion is separate.
Future<bool> deleteSighting(FindRecord find) async {
  return _removeSighting(find.id);
}

/// Copies review, public, and rejected onto the notebook. A sent find whose
/// document is gone returns to [FindShare.none].
Future<void> syncSightings(Notebook notebook) async {
  try {
    final user = _account();
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('sightings')
        .where('uid', isEqualTo: user.uid)
        .get();
    final remote = <String, FindShare>{
      for (final doc in snap.docs) doc.id: findShareFrom(doc.data()['status']),
    };
    final next = <FindRecord>[];
    var changed = false;
    for (final find in notebook.finds) {
      final share = remote[find.id] ?? FindShare.none;
      if (share == find.share) {
        next.add(find);
      } else {
        changed = true;
        next.add(find.copyWith(share: share));
      }
    }
    if (!changed) return;
    await notebook.replaceAll(next);
  } catch (error) {
    debugPrint('seen share sync: $error');
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

User? _account() {
  try {
    if (Firebase.apps.isEmpty) return null;
  } catch (_) {
    return null;
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) return null;
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
