import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:image/image.dart' as img;
import 'package:whats_that_mushroom/copy.dart';

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
  if (error is FirebaseFunctionsException) {
    if (error.code == 'unauthenticated') return copy.cameraNeedsAccount;
    if (error.code == 'not-found' || error.code == 'unavailable') {
      return copy.cameraUnavailable;
    }
  }
  return copy.cameraFailed;
}

/// The app never holds the Plant.id key. `identifyMushroom` does, in us-central1.
Future<List<NameGuess>> identifyMushroom(
  Uint8List jpeg,
  String language,
) async {
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final callable = functions.httpsCallable('identifyMushroom');
  final result = await callable.call<Object?>({
    'image': base64Encode(jpeg),
    'language': language,
  });
  return guessesFrom(result.data);
}
