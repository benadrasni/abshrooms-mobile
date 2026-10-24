import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FindRecord {
  final String id;
  final int millis;
  final String? latin;
  final String? outsideName;
  final double? probability;
  final String? photoPath;
  final bool confirmed;

  const FindRecord({
    required this.id,
    required this.millis,
    this.latin,
    this.outsideName,
    this.probability,
    this.photoPath,
    this.confirmed = false,
  });

  FindRecord copyWith({bool? confirmed, String? latin}) {
    return FindRecord(
      id: id,
      millis: millis,
      latin: latin ?? this.latin,
      outsideName: outsideName,
      probability: probability,
      photoPath: photoPath,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'millis': millis,
    if (latin != null) 'latin': latin,
    if (outsideName != null) 'outsideName': outsideName,
    if (probability != null) 'probability': probability,
    if (photoPath != null) 'photoPath': photoPath,
    'confirmed': confirmed,
  };

  factory FindRecord.fromJson(Map<String, dynamic> json) {
    return FindRecord(
      id: json['id']?.toString() ?? '',
      millis: json['millis'] is int ? json['millis'] as int : 0,
      latin: json['latin']?.toString(),
      outsideName: json['outsideName']?.toString(),
      probability: json['probability'] is num
          ? (json['probability'] as num).toDouble()
          : null,
      photoPath: json['photoPath']?.toString(),
      confirmed: json['confirmed'] == true,
    );
  }
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

  Future<String?> savePhoto(Uint8List bytes, String id) async {
    final dir = _dir;
    if (dir == null) return null;
    final folder = Directory('${dir.path}/finds');
    await folder.create(recursive: true);
    final path = '${folder.path}/$id.jpg';
    await File(path).writeAsBytes(bytes, flush: true);
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
      await file.writeAsString(
        json.encode(finds.map((item) => item.toJson()).toList()),
      );
    }
    notifyListeners();
  }
}
