import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:image/image.dart' as img;
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/shell/crash_reporting.dart';
import 'package:whats_that_mushroom/purchase/names.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';

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
Uint8List jpegMaxEdge(Uint8List bytes, {int edge = 1280}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longest <= edge) {
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
  }
  final wide = decoded.width >= decoded.height;
  final resized = img.copyResize(
    decoded,
    width: wide ? edge : null,
    height: wide ? null : edge,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
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

String cameraFailure(Object error, Copy copy) {
  if (error is NameRefused) return copy.cameraNeedsAccount;
  if (error is FirebaseFunctionsException) {
    if (error.code == 'unauthenticated') return copy.cameraNeedsAccount;
    if (error.code == 'not-found' || error.code == 'unavailable') {
      return copy.cameraUnavailable;
    }
    if (error.code == 'resource-exhausted') return copy.cameraNeedsAccount;
  }
  return copy.cameraFailed;
}

/// The app never holds the Plant.id key. `identifyMushroom` does, in
/// us-central1, and it counts the name before Plant.id is called.
Future<List<NameGuess>> identifyMushroom(
  Uint8List jpeg,
  String language,
) async {
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final callable = functions.httpsCallable(
    'identifyMushroom',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );
  try {
    final result = await callable.call<Object?>({
      'image': base64Encode(jpeg),
      'language': language,
      'fieldGuide': Purchases.hasFieldGuide(),
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

/// One more monthly name after the rewarded ad. False when the month is full
/// or the account is a guest.
Future<bool> grantPhotoName() async {
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final callable = functions.httpsCallable('grantPhotoName');
  final result = await callable.call<Object?>();
  final data = result.data;
  if (data is! Map) return false;
  Names.applyServer(
    signedIn: true,
    charged: false,
    anonymousFreeUsed: false,
    namesUsed: _countOf(data['namesUsed']),
    adGrants: _countOf(data['adGrants']),
    fromPhoto: false,
  );
  return data['granted'] == true;
}

void _applyQuota(Object? data) {
  if (data is! Map) return;
  if (!data.containsKey('namesUsed') && !data.containsKey('anonymousFreeUsed')) {
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
