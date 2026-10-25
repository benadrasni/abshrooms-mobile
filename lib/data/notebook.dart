import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    List<FindName>? others,
  }) {
    return FindRecord(
      id: id,
      millis: millis,
      latin: dropLatin ? null : (latin ?? this.latin),
      outsideName: dropOutside ? null : (outsideName ?? this.outsideName),
      spoken: dropSpoken ? null : (spoken ?? this.spoken),
      probability: probability ?? this.probability,
      photoPath: photoPath,
      confirmed: confirmed ?? this.confirmed,
      latitude: latitude,
      longitude: longitude,
      others: others ?? this.others,
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
  Set<String> favorites = {};
  int epoch = 0;
  SharedPreferences? _prefs;
  Directory? _dir;

  @override
  void notifyListeners() {
    epoch += 1;
    super.notifyListeners();
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    favorites = (_prefs!.getStringList('favorites') ?? []).toSet();
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

  bool isFavorite(String latin) => favorites.contains(latin);

  Future<void> toggleFavorite(String latin) async {
    if (favorites.contains(latin)) {
      favorites = {...favorites}..remove(latin);
    } else {
      favorites = {...favorites, latin};
    }
    await _prefs?.setStringList('favorites', favorites.toList());
    notifyListeners();
  }

  List<FindRecord> forSpecies(String latin) {
    return finds.where((item) => item.latin == latin).toList();
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
