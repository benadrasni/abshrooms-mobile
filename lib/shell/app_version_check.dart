import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/shell/app_version.dart';
import 'package:whats_that_mushroom/shell/version_gate.dart';

const Duration versionCheckTimeout = Duration(seconds: 5);

/// World-readable catalog document. Clients cannot write it.
///
/// `minAndroid` and `minIos` are the lowest build numbers still allowed.
/// A build below that floor stays closed. `android` and `ios` are the
/// build numbers currently on the stores. A higher store build shows a
/// banner the person can dismiss. Missing numbers mean no floor and no banner.
const String versionDocument = 'meta/versions';

const String versionBlockFloorKey = 'version_block_floor';
const String versionBannerDismissedKey = 'version_banner_dismissed';
const String versionFloorCacheKey = 'version_floor_cache';

class VersionRemote {
  /// Null when the read failed. Zero when the document sets no floor.
  final int? floor;

  /// Null when the store build is missing or the read failed.
  final int? storeBuild;

  const VersionRemote({required this.floor, required this.storeBuild});
}

/// Reads one platform out of `meta/versions`. A missing document is no floor.
VersionRemote versionRemoteFromMap(
  Map<String, dynamic>? data, {
  required bool android,
}) {
  if (data == null) return const VersionRemote(floor: 0, storeBuild: null);
  final floor = _asInt(data[android ? 'minAndroid' : 'minIos']) ?? 0;
  final store = _asInt(data[android ? 'android' : 'ios']);
  return VersionRemote(
    floor: floor,
    storeBuild: store != null && store > 0 ? store : null,
  );
}

/// Closes the guide before the first frame when this install was already
/// below the floor. A first launch, or a failed read, leaves it open.
Future<void> applyRememberedVersionBlock() async {
  try {
    final build = await readAppBuildNumber();
    final local = decideVersion(await readLocalVersionFacts(build));
    if (local.prompt == VersionPrompt.block) {
      VersionGateController.instance.apply(VersionPrompt.block);
    }
  } catch (error) {
    debugPrint('version check: $error');
  }
}

Future<int> readAppBuildNumber() async {
  try {
    final info = await PackageInfo.fromPlatform().timeout(versionCheckTimeout);
    return int.tryParse(info.buildNumber) ?? 0;
  } catch (error) {
    debugPrint('app build: $error');
    return 0;
  }
}

Future<VersionFacts> readLocalVersionFacts(int build) async {
  final remembered = await _prefInt(versionBlockFloorKey);
  final dismissed = await _prefInt(versionBannerDismissedKey);
  return VersionFacts(
    build: build,
    fetchedFloor: null,
    cachedFloor: 0,
    rememberedFloor: remembered,
    storeBuild: null,
    dismissedStore: dismissed,
  );
}

Future<VersionFacts> readFreshVersionFacts(int build) async {
  final android = Platform.isAndroid;
  final remote = _readRemote(android: android);
  final remembered = _prefInt(versionBlockFloorKey);
  final dismissed = _prefInt(versionBannerDismissedKey);
  final cached = _prefInt(versionFloorCacheKey);
  final results = await Future.wait<Object?>([
    remote,
    remembered,
    dismissed,
    cached,
  ]);
  final version = results[0] as VersionRemote;
  return VersionFacts(
    build: build,
    fetchedFloor: version.floor,
    cachedFloor: results[3] as int,
    rememberedFloor: results[1] as int,
    storeBuild: version.storeBuild,
    dismissedStore: results[2] as int,
  );
}

Future<void> persistVersionDecision(
  VersionDecision decision, {
  int? cacheFloor,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (cacheFloor != null) {
      await prefs.setInt(versionFloorCacheKey, cacheFloor);
    }
    if (decision.clearFloor) {
      await prefs.remove(versionBlockFloorKey);
      return;
    }
    final floor = decision.persistFloor;
    if (floor != null) {
      await prefs.setInt(versionBlockFloorKey, floor);
    }
  } catch (error) {
    debugPrint('version check: $error');
  }
}

Future<void> rememberDismissedStore(int store) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(versionBannerDismissedKey, store);
  } catch (error) {
    debugPrint('version check: $error');
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

Future<int> _prefInt(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(key) ?? 0;
}

Future<VersionRemote> _readRemote({required bool android}) async {
  try {
    final snap = await FirebaseFirestore.instance
        .doc(versionDocument)
        .get(const GetOptions(source: Source.server))
        .timeout(versionCheckTimeout);
    if (!snap.exists) {
      return const VersionRemote(floor: 0, storeBuild: null);
    }
    return versionRemoteFromMap(snap.data(), android: android);
  } catch (error) {
    debugPrint('version check: $error');
    return const VersionRemote(floor: null, storeBuild: null);
  }
}
