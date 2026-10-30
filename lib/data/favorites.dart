import 'package:cloud_firestore/cloud_firestore.dart';

/// Field on `users/{uid}/favorites/{Latin}`. The value is always 1, as on
/// the plants account, so the list has no saved time.
const favoriteValueField = 'v';

/// A Latin name that can be a Firestore document id.
bool favoriteNameOk(String name) {
  final trimmed = name.trim();
  return trimmed.isNotEmpty && trimmed.length < 200 && !trimmed.contains('/');
}

/// Latin names in a `users/{uid}/favorites` snapshot. A value other than 1
/// is skipped.
Set<String> favoriteNamesFrom(Iterable<({String id, Object? value})> rows) {
  final names = <String>{};
  for (final row in rows) {
    final name = row.id.trim();
    if (!favoriteNameOk(name) || row.value != 1) continue;
    names.add(name);
  }
  return names;
}

/// Writes or removes `users/{uid}/favorites/{latin}`.
Future<void> writeAccountFavorite(String uid, String latin, bool on) async {
  final name = latin.trim();
  if (uid.isEmpty || !favoriteNameOk(name)) return;
  final ref = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('favorites')
      .doc(name);
  if (on) {
    await ref.set({favoriteValueField: 1});
  } else {
    await ref.delete();
  }
}

/// Removes every favorite before the account itself is deleted.
///
/// A missing collection, or a rules denial while that rule is not published,
/// does not block the deletion.
Future<void> deleteAccountFavorites(String uid) async {
  if (uid.isEmpty) return;
  try {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites');
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) return;
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
