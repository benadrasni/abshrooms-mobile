import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/data/favorites.dart';
import 'package:whats_that_mushroom/person/auth.dart';

/// Where a confirmed find sits with Sightings.
enum FindShare { none, review, shared, rejected }

/// A stored name, or the server status `public` for a published sighting.
FindShare findShareFrom(Object? raw) {
  switch (raw) {
    case 'review':
      return FindShare.review;
    case 'shared':
    case 'public':
      return FindShare.shared;
    case 'rejected':
      return FindShare.rejected;
    default:
      return FindShare.none;
  }
}

/// Another name Plant.id offered for the same photo.
class FindName {
  final String scientificName;
  final double probability;
  final List<String> commonNames;

  const FindName({
    required this.scientificName,
    required this.probability,
    this.commonNames = const [],
  });

  Map<String, dynamic> toJson() => {
    'scientificName': scientificName,
    'probability': probability,
    'commonNames': commonNames,
  };

  factory FindName.fromJson(Map<String, dynamic> json) {
    final names = json['commonNames'];
    return FindName(
      scientificName: json['scientificName']?.toString().trim() ?? '',
      probability: json['probability'] is num
          ? (json['probability'] as num).toDouble()
          : 0,
      commonNames: [
        for (final entry in names is List ? names : const [])
          if (entry.toString().trim().isNotEmpty) entry.toString(),
      ],
    );
  }
}

class FindRecord {
  final String id;
  final int millis;
  final String? latin;
  final String? outsideName;

  /// A common name for [outsideName], when Plant.id sent one.
  final String? spoken;
  final double? probability;
  final String? photoPath;
  final bool confirmed;

  /// Place from the photo, when the file had one. Zero is absent.
  final double? latitude;
  final double? longitude;

  /// Other names from the same photo that are already in the book.
  final List<FindName> others;

  /// Sightings status. [FindShare.none] has not been sent.
  final FindShare share;

  const FindRecord({
    required this.id,
    required this.millis,
    this.latin,
    this.outsideName,
    this.spoken,
    this.probability,
    this.photoPath,
    this.confirmed = false,
    this.latitude,
    this.longitude,
    this.others = const [],
    this.share = FindShare.none,
  });

  FindRecord copyWith({
    bool? confirmed,
    String? latin,
    bool dropLatin = false,
    String? outsideName,
    bool dropOutside = false,
    String? spoken,
    bool dropSpoken = false,
    double? probability,
    String? photoPath,
    List<FindName>? others,
    FindShare? share,
  }) {
    return FindRecord(
      id: id,
      millis: millis,
      latin: dropLatin ? null : (latin ?? this.latin),
      outsideName: dropOutside ? null : (outsideName ?? this.outsideName),
      spoken: dropSpoken ? null : (spoken ?? this.spoken),
      probability: probability ?? this.probability,
      photoPath: photoPath ?? this.photoPath,
      confirmed: confirmed ?? this.confirmed,
      latitude: latitude,
      longitude: longitude,
      others: others ?? this.others,
      share: share ?? this.share,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'millis': millis,
    if (latin != null) 'latin': latin,
    if (outsideName != null) 'outsideName': outsideName,
    if (spoken != null) 'spoken': spoken,
    if (probability != null) 'probability': probability,
    if (photoPath != null) 'photoPath': photoPath,
    'confirmed': confirmed,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (others.isNotEmpty) 'others': [for (final name in others) name.toJson()],
    if (share != FindShare.none) 'share': share.name,
  };

  factory FindRecord.fromJson(Map<String, dynamic> json) {
    return FindRecord(
      id: json['id']?.toString() ?? '',
      millis: json['millis'] is int ? json['millis'] as int : 0,
      latin: json['latin']?.toString(),
      outsideName: json['outsideName']?.toString(),
      spoken: json['spoken']?.toString(),
      probability: json['probability'] is num
          ? (json['probability'] as num).toDouble()
          : null,
      photoPath: json['photoPath']?.toString(),
      confirmed: json['confirmed'] == true,
      latitude: _coord(json['latitude']),
      longitude: _coord(json['longitude']),
      others: _findNames(json['others']),
      share: findShareFrom(json['share']),
    );
  }
}

double? _coord(Object? value) {
  if (value is! num) return null;
  final number = value.toDouble();
  if (number == 0) return null;
  return number;
}

List<FindName> _findNames(Object? raw) {
  if (raw is! List) return const [];
  final names = <FindName>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final name = FindName.fromJson(
      item.map((key, value) => MapEntry('$key', value)),
    );
    if (name.scientificName.isEmpty) continue;
    names.add(name);
  }
  return names;
}

class Notebook extends ChangeNotifier {
  List<FindRecord> finds = [];

  /// Latin names on the signed-in account. Empty while signed out.
  Set<String> favorites = {};
  int epoch = 0;
  SharedPreferences? _prefs;
  Directory? _dir;

  /// The phone list from before favorites lived on the account. Moved onto
  /// the next signed-in account, then cleared so another account does not
  /// inherit it.
  Set<String> _phoneFavorites = {};
  Set<String> _remoteFavorites = {};
  final Set<String> _pendingOn = {};
  final Set<String> _pendingOff = {};
  String? _favoriteUid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favoriteSub;
  var _favoriteMoving = false;
  var _followingFavorites = false;

  /// Replaces the signed-in uid in tests.
  @visibleForTesting
  String? favoriteAccount;

  /// Replaces the Firestore write in tests.
  @visibleForTesting
  Future<void> Function(String uid, String latin, bool on)? favoriteWrite;

  @override
  void notifyListeners() {
    epoch += 1;
    super.notifyListeners();
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _phoneFavorites = {
      for (final name in _prefs!.getStringList('favorites') ?? const <String>[])
        if (favoriteNameOk(name)) name.trim(),
    };
    _dir = await getApplicationDocumentsDirectory();
    final file = File('${_dir!.path}/notebook.json');
    if (await file.exists()) {
      final decoded = json.decode(await file.readAsString());
      if (decoded is List) {
        finds = [
          for (final item in decoded)
            if (item is Map)
              FindRecord.fromJson(
                item.map((key, value) => MapEntry('$key', value)),
              ),
        ];
        finds.sort((a, b) => b.millis.compareTo(a.millis));
      }
    }
    notifyListeners();
    followAccount();
  }

  /// Follows `users/{uid}/favorites` for the signed-in account. A guest, or
  /// signing out, clears the names here. The rows stay on the account.
  void followAccount() {
    if (_followingFavorites) return;
    _followingFavorites = true;
    Auth.revision.addListener(_onFavoriteAccount);
    _onFavoriteAccount();
  }

  void stopFavorites() {
    Auth.revision.removeListener(_onFavoriteAccount);
    _favoriteSub?.cancel();
    _favoriteSub = null;
    _followingFavorites = false;
    _favoriteUid = null;
  }

  /// Drops the phone list when the account that would receive it is deleted.
  Future<void> forgetPhoneFavorites() async {
    _favoriteSub?.cancel();
    _favoriteSub = null;
    _favoriteMoving = false;
    _phoneFavorites = {};
    _pendingOn.clear();
    _pendingOff.clear();
    await _persistPhoneFavorites();
    if (_signedInUid() == null) {
      if (favorites.isNotEmpty) {
        favorites = {};
        notifyListeners();
      }
      return;
    }
    _paintFavorites();
  }

  String? _signedInUid() {
    if (favoriteAccount != null) return favoriteAccount;
    try {
      if (Firebase.apps.isEmpty) return null;
    } catch (_) {
      return null;
    }
    return Auth.appUser?.uid;
  }

  @visibleForTesting
  void debugFavoriteAccount() => _onFavoriteAccount();

  void _onFavoriteAccount() {
    final uid = _signedInUid();
    if (uid != null && uid == _favoriteUid && _favoriteSub != null) return;
    _favoriteSub?.cancel();
    _favoriteSub = null;
    _favoriteMoving = false;
    _favoriteUid = uid;
    _remoteFavorites = {};
    _pendingOn.clear();
    _pendingOff.clear();
    if (uid == null) {
      if (favorites.isNotEmpty) {
        favorites = {};
        notifyListeners();
      }
      return;
    }
    _paintFavorites();
    if (favoriteAccount != null) return;
    _favoriteSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .listen((snap) {
          if (_favoriteUid != uid) return;
          _applyFavoriteSnapshot(
            uid,
            favoriteNamesFrom([
              for (final doc in snap.docs) (id: doc.id, value: doc.data()['v']),
            ]),
          );
        }, onError: (Object error) => debugPrint('favorites: $error'));
  }

  @visibleForTesting
  void applyFavoriteSnapshot(Set<String> remote) {
    final uid = _favoriteUid ?? favoriteAccount;
    if (uid == null) return;
    _favoriteUid = uid;
    _applyFavoriteSnapshot(uid, remote);
  }

  @visibleForTesting
  Set<String> get phoneFavorites => _phoneFavorites;

  @visibleForTesting
  set phoneFavorites(Set<String> names) {
    _phoneFavorites = {
      for (final name in names)
        if (favoriteNameOk(name)) name.trim(),
    };
  }

  void _applyFavoriteSnapshot(String uid, Set<String> remote) {
    if (_favoriteUid != uid) return;
    _remoteFavorites = remote;
    final before = _phoneFavorites.length;
    _phoneFavorites.removeAll(remote);
    _pendingOn.removeWhere(remote.contains);
    _pendingOff.removeWhere((name) => !remote.contains(name));
    if (_phoneFavorites.length != before) unawaited(_persistPhoneFavorites());
    _paintFavorites();
    final move = Set<String>.of(_phoneFavorites);
    if (move.isEmpty || _favoriteMoving) return;
    _favoriteMoving = true;
    unawaited(() async {
      try {
        for (final name in move) {
          if (_favoriteUid != uid) return;
          if (!_phoneFavorites.contains(name)) continue;
          try {
            await _writeFavorite(uid, name, true);
          } catch (error) {
            debugPrint('favorites: $error');
          }
        }
      } finally {
        if (_favoriteUid == uid) _favoriteMoving = false;
      }
    }());
  }

  void _paintFavorites() {
    if (_signedInUid() == null) return;
    final shown = favoriteNamesShown(_remoteFavorites, _phoneFavorites);
    shown.addAll(_pendingOn);
    shown.removeAll(_pendingOff);
    if (setEquals(favorites, shown)) return;
    favorites = shown;
    notifyListeners();
  }

  Future<void> _persistPhoneFavorites() async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (_phoneFavorites.isEmpty) {
      await prefs.remove('favorites');
    } else {
      await prefs.setStringList('favorites', _phoneFavorites.toList());
    }
  }

  Future<void> _writeFavorite(String uid, String latin, bool on) {
    final write = favoriteWrite;
    if (write != null) return write(uid, latin, on);
    return writeAccountFavorite(uid, latin, on);
  }

  /// Folder for find photos. The app sets this from its documents directory.
  @visibleForTesting
  void useStorage(Directory dir) {
    _dir = dir;
  }

  Future<String?> savePhoto(Uint8List bytes, String id) async {
    final dir = _dir;
    if (dir == null) return null;
    final folder = Directory('${dir.path}/finds');
    // Sync: these files are small, and the caller waits before the next step.
    // An async write never finishes inside a widget test's fake clock.
    folder.createSync(recursive: true);
    final path = '${folder.path}/$id.jpg';
    File(path).writeAsBytesSync(bytes, flush: true);
    return path;
  }

  Future<void> addFind(FindRecord record) async {
    finds = [record, ...finds.where((item) => item.id != record.id)];
    await _write();
  }

  Future<void> setShare(String id, FindShare share) async {
    finds = [
      for (final item in finds)
        if (item.id == id) item.copyWith(share: share) else item,
    ];
    await _write();
  }

  /// Replaces the notebook after a Sightings refresh.
  Future<void> replaceAll(List<FindRecord> next) async {
    finds = next;
    await _write();
  }

  Future<void> confirm(String id) async {
    finds = [
      for (final item in finds)
        if (item.id == id) item.copyWith(confirmed: true) else item,
    ];
    await _write();
  }

  Future<void> replace(FindRecord record) async {
    finds = [
      for (final item in finds)
        if (item.id == record.id) record else item,
    ];
    await _write();
  }

  Future<void> remove(String id) async {
    FindRecord? gone;
    for (final item in finds) {
      if (item.id == id) gone = item;
    }
    finds = finds.where((item) => item.id != id).toList();
    final path = gone?.photoPath;
    if (path != null) {
      final file = File(path);
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // The file is already gone. The record still leaves the notebook.
      }
    }
    await _write();
  }

  bool isFavorite(String latin) => favorites.contains(latin.trim());

  Future<void> toggleFavorite(String latin) {
    return setFavorite(latin, !isFavorite(latin));
  }

  /// Writes `users/{uid}/favorites/{latin}` as 1, or removes it.
  /// Does nothing useful when nobody is signed in: the list stays on the
  /// account, and a guest sees an empty list.
  Future<void> setFavorite(String latin, bool on) async {
    final name = latin.trim();
    if (!favoriteNameOk(name)) return;
    final uid = _signedInUid();
    if (uid == null) throw StateError('not signed in');
    if (on) {
      _pendingOff.remove(name);
      _pendingOn.add(name);
    } else {
      _pendingOn.remove(name);
      _pendingOff.add(name);
      if (_phoneFavorites.remove(name)) unawaited(_persistPhoneFavorites());
    }
    _paintFavorites();
    try {
      await _writeFavorite(uid, name, on);
      if (_signedInUid() == uid) {
        if (on && _pendingOn.remove(name)) {
          _remoteFavorites = {..._remoteFavorites, name};
        } else if (!on && _pendingOff.remove(name)) {
          _remoteFavorites = {..._remoteFavorites}..remove(name);
        }
        _paintFavorites();
      }
    } catch (error) {
      if (_signedInUid() == uid) {
        if (on) {
          _pendingOn.remove(name);
        } else {
          _pendingOff.remove(name);
        }
        _paintFavorites();
      }
      rethrow;
    }
  }

  Future<void> _write() async {
    final dir = _dir;
    if (dir != null) {
      final file = File('${dir.path}/notebook.json');
      // Sync for the same reason as savePhoto.
      file.writeAsStringSync(
        json.encode(finds.map((item) => item.toJson()).toList()),
      );
    }
    notifyListeners();
  }
}
