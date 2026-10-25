import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// A photo chosen for Seen. [bytes] have no location metadata. [when] is the
/// photo's date when the file had one, and the moment of the add otherwise.
class SeenPhoto {
  final Uint8List bytes;
  final DateTime when;
  final double latitude;
  final double longitude;
  final bool fromPhoto;

  const SeenPhoto({
    required this.bytes,
    required this.when,
    required this.latitude,
    required this.longitude,
    required this.fromPhoto,
  });
}

const seenPhotoEdge = 2048;

@visibleForTesting
const MethodChannel seenPhotoChannel = MethodChannel('sk.ab.shrooms/photo');

/// Gallery photo for Add to Seen. Android asks the system picker to keep the
/// picture's location. The picker still lets the person leave it out.
/// Anywhere else, the image picker is used. Cancel returns null.
Future<String?> pickDevicePhoto({
  bool? android,
  Future<String?> Function(double maxWidth)? imagePicker,
  Future<String?> Function(double maxWidth)? androidPicker,
}) async {
  final useAndroid = android ?? Platform.isAndroid;
  if (useAndroid) {
    try {
      final pick = androidPicker ?? _androidPick;
      final path = await pick(seenPhotoEdge.toDouble());
      if (path == null || path.isEmpty) return null;
      return path;
    } on PlatformException catch (error) {
      if (error.code != 'unavailable') rethrow;
    }
  }
  final pick = imagePicker ?? _imagePickerPath;
  return pick(seenPhotoEdge.toDouble());
}

Future<String?> _androidPick(double maxWidth) {
  return seenPhotoChannel.invokeMethod<String>('pick', {'maxWidth': maxWidth});
}

Future<String?> _imagePickerPath(double maxWidth) async {
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxWidth,
  );
  return image?.path;
}

/// Reads [path], keeps the date and place, and returns a JPEG without them.
/// A file that cannot be read returns null. The caller must not keep the
/// original bytes.
Future<SeenPhoto?> seenPhotoFromPath(String path) async {
  final bytes = await File(path).readAsBytes();
  return seenPhotoFromBytes(bytes);
}

/// Picks a gallery photo and returns the notebook JPEG. Cancel returns null.
Future<SeenPhoto?> pickSeenPhoto() async {
  final path = await pickDevicePhoto();
  if (path == null || path.isEmpty) return null;
  try {
    return await seenPhotoFromPath(path);
  } finally {
    await deleteSeenPickCache(path);
  }
}

/// The Android picker cache. Other photo files stay where they are.
bool seenPickCachePath(String path) {
  final parts = path.replaceAll('\\', '/').split('/');
  return parts.length >= 2 && parts[parts.length - 2] == 'guide-pick';
}

Future<void> deleteSeenPickCache(String path) async {
  if (!seenPickCachePath(path)) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}

/// Date and place from [bytes], plus a JPEG that no longer carries them.
/// Returns null when the file is not a picture.
SeenPhoto? seenPhotoFromBytes(
  Uint8List bytes, {
  DateTime? now,
  int edge = seenPhotoEdge,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final exif = decoded.exif;
  final dateTag =
      _text(exif.exifIfd['DateTimeOriginal']) ??
      _text(exif.imageIfd['DateTime']);
  final when = _exifDate(dateTag);
  final latitude = _gps(
    exif.gpsIfd['GPSLatitude'],
    _text(exif.gpsIfd['GPSLatitudeRef']),
    positive: 'N',
  );
  final longitude = _gps(
    exif.gpsIfd['GPSLongitude'],
    _text(exif.gpsIfd['GPSLongitudeRef']),
    positive: 'E',
  );
  decoded.exif = img.ExifData();
  final sized = _limit(decoded, edge);
  return SeenPhoto(
    bytes: Uint8List.fromList(img.encodeJpg(sized, quality: 85)),
    when: when ?? now ?? DateTime.now(),
    latitude: latitude,
    longitude: longitude,
    fromPhoto: when != null || latitude != 0 || longitude != 0,
  );
}

String? _text(img.IfdValue? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return text;
}

/// `YYYY:MM:DD HH:MM:SS` from the photo. Anything else is no date.
DateTime? _exifDate(String? raw) {
  if (raw == null) return null;
  final parts = raw.split(' ');
  if (parts.length < 2) return null;
  final date = parts[0].split(':');
  final time = parts[1].split(':');
  if (date.length < 3 || time.length < 3) return null;
  final year = int.tryParse(date[0]);
  final month = int.tryParse(date[1]);
  final day = int.tryParse(date[2]);
  final hour = int.tryParse(time[0]);
  final minute = int.tryParse(time[1]);
  final second = int.tryParse(time[2]);
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;
  return DateTime(year, month, day, hour, minute, second);
}

/// Degrees from a GPS rational. [positive] is `N` or `E`. No value is 0.
double _gps(img.IfdValue? value, String? ref, {required String positive}) {
  if (value == null || value.length == 0) return 0;
  final degrees = value.toDouble(0);
  final minutes = value.length > 1 ? value.toDouble(1) : 0;
  final seconds = value.length > 2 ? value.toDouble(2) : 0;
  final magnitude = degrees.abs() + minutes.abs() / 60 + seconds.abs() / 3600;
  if (ref == null || ref.isEmpty) return magnitude;
  final sign = ref.toUpperCase() == positive ? 1.0 : -1.0;
  return sign * magnitude;
}

img.Image _limit(img.Image decoded, int edge) {
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (edge <= 0 || longest <= edge) return decoded;
  final wide = decoded.width >= decoded.height;
  return img.copyResize(
    decoded,
    width: wide ? edge : null,
    height: wide ? null : edge,
  );
}
