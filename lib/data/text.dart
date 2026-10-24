import 'package:diacritic/diacritic.dart';
import 'package:whats_that_mushroom/copy.dart';

const storageRoot = 'https://storage.googleapis.com/abshrooms-resources/';

const monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const monthsSk = [
  'január',
  'február',
  'marec',
  'apríl',
  'máj',
  'jún',
  'júl',
  'august',
  'september',
  'október',
  'november',
  'december',
];

/// Fold used by catalog search: NFD, drop diacritics, lowercase, trim.
String foldName(String value) {
  return removeDiacritics(value).toLowerCase().trim();
}

/// Book order. Slovak keeps č, ľ, and the ch digraph in alphabet order.
int compareTitle(String a, String b, String language) {
  return _sortKey(a, language).compareTo(_sortKey(b, language));
}

const _slovakOrder = {
  'a': 'a0',
  'á': 'a1',
  'ä': 'a2',
  'b': 'b0',
  'c': 'c0',
  'č': 'c1',
  'd': 'd0',
  'ď': 'd1',
  'e': 'e0',
  'é': 'e1',
  'f': 'f0',
  'g': 'g0',
  'h': 'h0',
  'i': 'i0',
  'í': 'i1',
  'j': 'j0',
  'k': 'k0',
  'l': 'l0',
  'ĺ': 'l1',
  'ľ': 'l2',
  'm': 'm0',
  'n': 'n0',
  'ň': 'n1',
  'o': 'o0',
  'ó': 'o1',
  'ô': 'o2',
  'p': 'p0',
  'q': 'q0',
  'r': 'r0',
  'ŕ': 'r1',
  's': 's0',
  'š': 's1',
  't': 't0',
  'ť': 't1',
  'u': 'u0',
  'ú': 'u1',
  'v': 'v0',
  'w': 'w0',
  'x': 'x0',
  'y': 'y0',
  'ý': 'y1',
  'z': 'z0',
  'ž': 'z1',
};

String _sortKey(String value, String language) {
  final lower = value.toLowerCase();
  if (language != 'sk') return removeDiacritics(lower);
  final buffer = StringBuffer();
  final chars = lower.split('');
  for (var i = 0; i < chars.length; i++) {
    final char = chars[i];
    if (char == 'c' && i + 1 < chars.length && chars[i + 1] == 'h') {
      buffer.write('h1');
      i += 1;
      continue;
    }
    buffer.write(_slovakOrder[char] ?? char);
  }
  return buffer.toString();
}

/// Slovak labels lose a capital first letter. A missing label stays Latin.
String displayName(String? label, String language) {
  final value = label?.trim() ?? '';
  if (value.isEmpty) return '';
  if (language != 'sk') return value;
  return value.substring(0, 1).toLowerCase() + value.substring(1);
}

String titleFor(String? label, String latin, String language) {
  final spoken = displayName(label, language);
  return spoken.isEmpty ? latin : spoken;
}

String cm(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

String mediaUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return '$storageRoot$path';
}

/// Cards use the 400 px plate. The species page uses the stored 1600 px file.
String cardPlate(String illustrationUrl) {
  return mediaUrl(illustrationUrl.replaceAll('@1600.webp', '@400.webp'));
}

String familyIcon(String family) => mediaUrl('families/$family.webp');

List<int> fruitingMonths(int from, int to) {
  final months = <int>[];
  var month = from;
  for (var guard = 0; guard < 12; guard++) {
    months.add(month);
    if (month == to) break;
    month = month == 12 ? 1 : month + 1;
  }
  return months;
}

String seasonSpan(int? from, int? to, String language) {
  if (from == null ||
      to == null ||
      from < 1 ||
      from > 12 ||
      to < 1 ||
      to > 12) {
    return '';
  }
  final months = language == 'sk' ? monthsSk : monthsEn;
  return '${months[from - 1]}–${months[to - 1]}';
}

String capMeasure({
  required double? from,
  required double? to,
  required Copy copy,
}) {
  if (from != null && to != null) return '${cm(from)}–${cm(to)} cm';
  if (to != null) return copy.capUpTo(cm(to));
  if (from != null) return '${cm(from)} cm';
  return '';
}

String stipeMeasure({
  required double? heightFrom,
  required double? heightTo,
  required double? thickFrom,
  required double? thickTo,
}) {
  final height = _span(heightFrom, heightTo);
  final thick = _span(thickFrom, thickTo);
  if (height.isEmpty && thick.isEmpty) return '';
  if (height.isEmpty) return '$thick cm';
  if (thick.isEmpty) return '$height cm';
  return '$height × $thick cm';
}

String _span(double? from, double? to) {
  if (from != null && to != null) return '${cm(from)}–${cm(to)}';
  if (to != null) return cm(to);
  if (from != null) return cm(from);
  return '';
}

double? asDouble(Object? value) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return null;
}

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.round();
  return null;
}

List<String> stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList();
}
