import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:image/image.dart' as img;
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/purchase/names.dart';
import 'package:whats_that_mushroom/shell/app_check.dart';
import 'package:whats_that_mushroom/shell/crash_reporting.dart';

/// `identifyMushroom` refused the photo before calling Plant.id.
class NameRefused implements Exception {
  final String reason;

  const NameRefused(this.reason);
}

class NameGuess {
  final String scientificName;
  final double probability;
  final List<String> commonNames;

  const NameGuess({
    required this.scientificName,
    required this.probability,
    required this.commonNames,
  });
}

/// Longest side becomes [edge] pixels. The bytes stay a JPEG.
/// The date and the place written on the file are not copied across.
/// Null when [bytes] is not a JPEG.
Uint8List? jpegMaxEdge(Uint8List bytes, {int edge = 1280}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return _jpegWithoutApp1(bytes);
  decoded.exif = img.ExifData();
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final img.Image sized;
  if (longest <= edge) {
    sized = decoded;
  } else {
    final wide = decoded.width >= decoded.height;
    sized = img.copyResize(
      decoded,
      width: wide ? edge : null,
      height: wide ? null : edge,
    );
  }
  return Uint8List.fromList(img.encodeJpg(sized, quality: 85));
}

/// Drops every APP1 segment before the scan and copies the rest.
/// Null when [bytes] has no JPEG start.
Uint8List? _jpegWithoutApp1(Uint8List bytes) {
  if (bytes.length < 2 || bytes[0] != 0xff || bytes[1] != 0xd8) return null;
  final kept = BytesBuilder(copy: false)
    ..addByte(0xff)
    ..addByte(0xd8);
  var i = 2;
  while (i + 1 < bytes.length) {
    if (bytes[i] != 0xff) {
      kept.add(bytes.sublist(i));
      return kept.takeBytes();
    }
    final marker = bytes[i + 1];
    if (marker == 0xff) {
      kept.addByte(0xff);
      i++;
      continue;
    }
    if (marker == 0xda || marker == 0xd9) {
      kept.add(bytes.sublist(i));
      return kept.takeBytes();
    }
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      kept
        ..addByte(0xff)
        ..addByte(marker);
      i += 2;
      continue;
    }
    if (i + 3 >= bytes.length) {
      kept.add(bytes.sublist(i));
      return kept.takeBytes();
    }
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    if (length < 2 || i + 2 + length > bytes.length) {
      kept.add(bytes.sublist(i));
      return kept.takeBytes();
    }
    final end = i + 2 + length;
    if (marker != 0xe1) kept.add(bytes.sublist(i, end));
    i = end;
  }
  if (i < bytes.length) kept.add(bytes.sublist(i));
  return kept.takeBytes();
}

List<NameGuess> guessesFrom(Object? data) {
  if (data is! Map) return const [];
  final raw = data['suggestions'];
  if (raw is! List) return const [];
  final guesses = <NameGuess>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final name = item['scientificName']?.toString().trim() ?? '';
    if (name.isEmpty) continue;
    final probability = item['probability'];
    final names = item['commonNames'];
    guesses.add(
      NameGuess(
        scientificName: name,
        probability: probability is num ? probability.toDouble() : 0,
        commonNames: [
          for (final entry in names is List ? names : const [])
            if (entry.toString().trim().isNotEmpty) entry.toString(),
        ],
      ),
    );
  }
  return guesses;
}

String confidenceLabel(double probability, Copy copy) {
  if (probability >= 0.5) return copy.likely;
  if (probability >= 0.2) return copy.possible;
  return copy.uncertain;
}

String refusalCopy(String reason, Copy copy, {bool signedIn = false}) {
  switch (reason) {
    case 'cooldown':
      return copy.cameraTooSoon;
    case 'repeat-photo':
      return copy.cameraSamePhoto;
    case 'daily-ceiling':
      return copy.cameraPausedToday;
    case 'no-names':
      return copy.cameraLimitTitle;
    case 'sign-in':
      return signedIn ? copy.cameraAuthExpired : copy.cameraNeedsAccount;
    default:
      return signedIn ? copy.cameraAuthExpired : copy.cameraNeedsAccount;
  }
}

String cameraFailure(Object error, Copy copy, {bool signedIn = false}) {
  if (error is NameRefused) {
    return refusalCopy(error.reason, copy, signedIn: signedIn);
  }
  if (error is FirebaseFunctionsException) {
    if (error.code == 'unauthenticated') {
      return signedIn ? copy.cameraAuthExpired : copy.cameraNeedsAccount;
    }
    if (error.code == 'not-found' || error.code == 'unavailable') {
      return copy.cameraUnavailable;
    }
    if (error.code == 'resource-exhausted') {
      return copy.cameraLimitTitle;
    }
  }
  return copy.cameraFailed;
}

/// The app never holds the Plant.id key. `identifyMushroom` does, in
/// us-central1, and it counts the name before Plant.id is called.
Future<List<NameGuess>> identifyMushroom(
  Uint8List jpeg,
  String language,
) async {
  try {
    await GuideAppCheck.ensure();
  } catch (_) {}
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final callable = functions.httpsCallable(
    'identifyMushroom',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );
  try {
    final result = await callable.call<Object?>({
      'image': base64Encode(jpeg),
      'language': language,
    });
    _applyQuota(result.data);
    return guessesFrom(result.data);
  } on FirebaseFunctionsException catch (error, stack) {
    if (error.code == 'resource-exhausted') {
      _applyQuota(error.details);
      final details = error.details;
      final reason = details is Map
          ? details['reason']?.toString() ?? error.message
          : error.message;
      throw NameRefused(reason ?? 'sign-in');
    }
    recordGuideError(error, stack, reason: 'identifyMushroom');
    rethrow;
  } catch (error, stack) {
    recordGuideError(error, stack, reason: 'identifyMushroom');
    rethrow;
  }
}

void _applyQuota(Object? data) {
  if (data is! Map) return;
  if (!data.containsKey('namesUsed') &&
      !data.containsKey('anonymousFreeUsed')) {
    return;
  }
  final guest = data['guest'] == true || !photoAccountSignedIn();
  Names.applyServer(
    signedIn: !guest,
    charged: data['charged'] == true,
    anonymousFreeUsed: data['anonymousFreeUsed'] == true,
    namesUsed: _countOf(data['namesUsed']),
    adGrants: _countOf(data['adGrants']),
  );
}

int? _countOf(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
