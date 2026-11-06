import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:image/image.dart' as img;
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/language.dart';
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

  /// Plant.id taxonomic rank, when the reply includes one.
  final String? rank;

  const NameGuess({
    required this.scientificName,
    required this.probability,
    required this.commonNames,
    this.rank,
  });
}

/// Plant.id named a genus, not a species.
/// `Boletus edulis` is a species. `Boletus` and `Boletus sp.` are a genus.
bool genusLevelName(String scientificName, {String? rank}) {
  if (rank?.trim().toLowerCase() == 'genus') return true;
  final parts = scientificName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length == 1) return true;
  if (parts.length != 2) return false;
  final bare = parts[1].toLowerCase().replaceAll('.', '');
  return bare == 'sp' || bare == 'spp' || bare == 'spec' || bare == 'species';
}

/// The genus word in a Plant.id name. Empty when [scientificName] is blank.
String genusToken(String scientificName) {
  final parts = scientificName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) return '';
  return parts.first;
}

/// Longest side becomes [edge] pixels. The bytes stay a JPEG.
/// The date and the place written on the file are not copied across.
/// Null when [bytes] is not a JPEG.
Uint8List? jpegMaxEdge(Uint8List bytes, {int edge = 1280}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return _jpegWithoutMetadata(bytes);
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

/// `identifyMushroom` rejects a base64 image longer than this and never
/// calls Plant.id.
const identifyMaxImageChars = 8 * 1024 * 1024;

/// A JPEG Plant.id can accept. The long edge is at most [edge], and the
/// date and the place are not in the file.
///
/// A gallery photo is already scaled by the picker. An iPhone shutter photo
/// is the sensor's full still. Decoding that still in Dart builds the whole
/// picture in memory and can be killed before the upload, and a still the
/// Dart decoder cannot read is sent unchanged and then refused. The platform
/// codec scales while it decodes. [maxChars] is the base64 ceiling.
Future<Uint8List?> jpegForIdentify(
  Uint8List bytes, {
  int edge = 1280,
  int maxChars = identifyMaxImageChars,
}) async {
  if (edge < 1 || maxChars < 1) return null;
  try {
    if (_isJpeg(bytes) && _jpegFitsIdentify(bytes, edge, maxChars)) {
      final fitted = jpegMaxEdge(bytes, edge: edge);
      if (fitted != null && _base64Chars(fitted) <= maxChars) return fitted;
    }
    final coded = await _jpegFromCodec(bytes, edge: edge);
    if (coded == null || _base64Chars(coded) > maxChars) return null;
    return coded;
  } catch (_) {
    return null;
  }
}

bool _isJpeg(Uint8List bytes) {
  return bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8;
}

int _base64Chars(Uint8List bytes) => ((bytes.length + 2) ~/ 3) * 4;

/// True when the main frame is already within [edge] and the file's base64
/// is within [maxChars]. A missing frame is not small: the codec has to
/// scale it, or the photo is not sent.
bool _jpegFitsIdentify(Uint8List bytes, int edge, int maxChars) {
  final size = _jpegSize(bytes);
  if (size == null) return false;
  final longest = size.$1 > size.$2 ? size.$1 : size.$2;
  if (longest > edge) return false;
  return _base64Chars(bytes) <= maxChars;
}

/// SOF size of the main frame, or null when this JPEG has no readable frame.
(int, int)? _jpegSize(Uint8List bytes) {
  if (!_isJpeg(bytes)) return null;
  var i = 2;
  while (i + 8 < bytes.length) {
    if (bytes[i] != 0xFF) return null;
    while (i < bytes.length && bytes[i] == 0xFF) {
      i++;
    }
    if (i >= bytes.length) return null;
    final marker = bytes[i];
    i++;
    if (marker == 0xD9 || marker == 0xDA) return null;
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) continue;
    if (i + 2 > bytes.length) return null;
    final length = (bytes[i] << 8) | bytes[i + 1];
    if (length < 2 || i + length > bytes.length) return null;
    final sof =
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC &&
        marker >= 0xC0 &&
        marker <= 0xCF;
    if (sof) {
      if (length < 7) return null;
      final height = (bytes[i + 3] << 8) | bytes[i + 4];
      final width = (bytes[i + 5] << 8) | bytes[i + 6];
      if (width == 0 || height == 0) return null;
      return (width, height);
    }
    i += length;
  }
  return null;
}

/// Pixels only, long edge at most [edge]. A picture the codec cannot read
/// is refused. Smaller pictures stay as they are.
Future<Uint8List?> _jpegFromCodec(Uint8List bytes, {required int edge}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (int width, int height) {
      if (width <= edge && height <= edge) return const ui.TargetImageSize();
      if (width >= height) return ui.TargetImageSize(width: edge);
      return ui.TargetImageSize(height: edge);
    },
  );
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      if (image.width <= 0 || image.height <= 0) return null;
      final raw = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (raw == null) return null;
      final pixels = raw.buffer.asUint8List(
        raw.offsetInBytes,
        raw.lengthInBytes,
      );
      final picture = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: pixels.buffer,
        bytesOffset: pixels.offsetInBytes,
        numChannels: 4,
      );
      final encoded = img.encodeJpg(picture, quality: 85);
      if (encoded.length < 4 || encoded[0] != 0xFF || encoded[1] != 0xD8) {
        return null;
      }
      return encoded;
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// Drops APPn (0xE1-0xEF) and COM segments up to the first end of image.
/// APP0, tables, the frame, the restart interval, and the scan stay.
/// A broken marker is null, and nothing after the first end of image is sent.
/// Null when [bytes] has no JPEG start.
Uint8List? _jpegWithoutMetadata(Uint8List bytes) {
  if (bytes.length < 2 || bytes[0] != 0xff || bytes[1] != 0xd8) return null;
  final kept = BytesBuilder(copy: false)
    ..addByte(0xff)
    ..addByte(0xd8);
  var i = 2;
  while (i + 1 < bytes.length) {
    if (bytes[i] != 0xff) return null;
    if (bytes[i + 1] == 0xff) {
      kept.addByte(0xff);
      i++;
      continue;
    }
    final marker = bytes[i + 1];
    if (marker == 0xd9) {
      kept
        ..addByte(0xff)
        ..addByte(0xd9);
      return kept.takeBytes();
    }
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd8)) {
      kept
        ..addByte(0xff)
        ..addByte(marker);
      i += 2;
      continue;
    }
    if (i + 3 >= bytes.length) return null;
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    if (length < 2 || i + 2 + length > bytes.length) return null;
    final end = i + 2 + length;
    if (marker == 0xe0) {
      final app0 = _app0WithoutThumbnail(bytes, i, end);
      if (app0 != null) kept.add(app0);
    } else {
      final metadata = marker == 0xfe || (marker >= 0xe1 && marker <= 0xef);
      if (!metadata) kept.add(bytes.sublist(i, end));
    }
    i = end;
    if (marker == 0xda) {
      final next = _copyJpegScan(bytes, i, kept);
      if (next == null) return null;
      i = next;
    }
  }
  if (i < bytes.length) return null;
  return kept.takeBytes();
}

/// APP0 is kept only as a JFIF header with no thumbnail.
/// JFXX and any other APP0, including a JPEG thumbnail, are dropped.
/// A short JFIF that has no thumbnail fields is kept as it is.
Uint8List? _app0WithoutThumbnail(Uint8List bytes, int start, int end) {
  final payload = start + 4;
  final payloadLength = end - payload;
  if (payloadLength >= 5 && _markerName(bytes, payload, 'JFXX\x00')) {
    return null;
  }
  if (payloadLength < 5 || !_markerName(bytes, payload, 'JFIF\x00')) {
    return null;
  }
  if (payloadLength < 14) return bytes.sublist(start, end);
  final xThumb = bytes[payload + 12];
  final yThumb = bytes[payload + 13];
  if (xThumb == 0 && yThumb == 0 && payloadLength == 14) {
    return bytes.sublist(start, end);
  }
  final minimal = Uint8List(18);
  minimal[0] = 0xff;
  minimal[1] = 0xe0;
  minimal[2] = 0x00;
  minimal[3] = 16;
  minimal.setRange(4, 16, bytes, payload);
  return minimal;
}

bool _markerName(Uint8List bytes, int offset, String name) {
  for (var i = 0; i < name.length; i++) {
    if (bytes[offset + i] != name.codeUnitAt(i)) return false;
  }
  return true;
}

/// Copies entropy-coded bytes from [i] until the next marker.
/// A stuffed 0xFF and restart markers stay in the scan.
/// Null when a marker byte has no partner.
int? _copyJpegScan(Uint8List bytes, int i, BytesBuilder kept) {
  while (i < bytes.length) {
    if (bytes[i] != 0xff) {
      kept.addByte(bytes[i]);
      i++;
      continue;
    }
    if (i + 1 >= bytes.length) return null;
    final marker = bytes[i + 1];
    if (marker == 0x00 || (marker >= 0xd0 && marker <= 0xd7)) {
      kept
        ..addByte(0xff)
        ..addByte(marker);
      i += 2;
      continue;
    }
    if (marker == 0xff) {
      kept.addByte(0xff);
      i++;
      continue;
    }
    return i;
  }
  return i;
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
    final rank = item['rank']?.toString().trim() ?? '';
    guesses.add(
      NameGuess(
        scientificName: name,
        probability: probability is num ? probability.toDouble() : 0,
        commonNames: [
          for (final entry in names is List ? names : const [])
            if (entry.toString().trim().isNotEmpty) entry.toString(),
        ],
        rank: rank.isEmpty ? null : rank,
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
      'language': contentLanguage(language),
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
