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

const monthsCs = [
  'leden',
  'únor',
  'březen',
  'duben',
  'květen',
  'červen',
  'červenec',
  'srpen',
  'září',
  'říjen',
  'listopad',
  'prosinec',
];

const monthsDe = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

const monthsFr = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

const monthsPl = [
  'styczeń',
  'luty',
  'marzec',
  'kwiecień',
  'maj',
  'czerwiec',
  'lipiec',
  'sierpień',
  'wrzesień',
  'październik',
  'listopad',
  'grudzień',
];

const monthsHu = [
  'január',
  'február',
  'március',
  'április',
  'május',
  'június',
  'július',
  'augusztus',
  'szeptember',
  'október',
  'november',
  'december',
];

const monthsUk = [
  'січень',
  'лютий',
  'березень',
  'квітень',
  'травень',
  'червень',
  'липень',
  'серпень',
  'вересень',
  'жовтень',
  'листопад',
  'грудень',
];

const monthsRu = [
  'январь',
  'февраль',
  'март',
  'апрель',
  'май',
  'июнь',
  'июль',
  'август',
  'сентябрь',
  'октябрь',
  'ноябрь',
  'декабрь',
];

const monthsEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const monthsPt = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

const monthsNl = [
  'januari',
  'februari',
  'maart',
  'april',
  'mei',
  'juni',
  'juli',
  'augustus',
  'september',
  'oktober',
  'november',
  'december',
];

const monthsDa = [
  'januar',
  'februar',
  'marts',
  'april',
  'maj',
  'juni',
  'juli',
  'august',
  'september',
  'oktober',
  'november',
  'december',
];

const monthsSv = [
  'januari',
  'februari',
  'mars',
  'april',
  'maj',
  'juni',
  'juli',
  'augusti',
  'september',
  'oktober',
  'november',
  'december',
];

const monthsNo = [
  'januar',
  'februar',
  'mars',
  'april',
  'mai',
  'juni',
  'juli',
  'august',
  'september',
  'oktober',
  'november',
  'desember',
];

const monthsFi = [
  'tammikuu',
  'helmikuu',
  'maaliskuu',
  'huhtikuu',
  'toukokuu',
  'kesäkuu',
  'heinäkuu',
  'elokuu',
  'syyskuu',
  'lokakuu',
  'marraskuu',
  'joulukuu',
];

const monthsEt = [
  'jaanuar',
  'veebruar',
  'märts',
  'aprill',
  'mai',
  'juuni',
  'juuli',
  'august',
  'september',
  'oktoober',
  'november',
  'detsember',
];

const monthsLv = [
  'janvāris',
  'februāris',
  'marts',
  'aprīlis',
  'maijs',
  'jūnijs',
  'jūlijs',
  'augusts',
  'septembris',
  'oktobris',
  'novembris',
  'decembris',
];

const monthsLt = [
  'sausis',
  'vasaris',
  'kovas',
  'balandis',
  'gegužė',
  'birželis',
  'liepa',
  'rugpjūtis',
  'rugsėjis',
  'spalis',
  'lapkritis',
  'gruodis',
];

const monthsIt = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

const monthsHr = [
  'siječanj',
  'veljača',
  'ožujak',
  'travanj',
  'svibanj',
  'lipanj',
  'srpanj',
  'kolovoz',
  'rujan',
  'listopad',
  'studeni',
  'prosinac',
];

const monthsSl = [
  'januar',
  'februar',
  'marec',
  'april',
  'maj',
  'junij',
  'julij',
  'avgust',
  'september',
  'oktober',
  'november',
  'december',
];

const monthsSr = [
  'јануар',
  'фебруар',
  'март',
  'април',
  'мај',
  'јун',
  'јул',
  'август',
  'септембар',
  'октобар',
  'новембар',
  'децембар',
];

const monthsRo = [
  'ianuarie',
  'februarie',
  'martie',
  'aprilie',
  'mai',
  'iunie',
  'iulie',
  'august',
  'septembrie',
  'octombrie',
  'noiembrie',
  'decembrie',
];

const monthsBg = [
  'януари',
  'февруари',
  'март',
  'април',
  'май',
  'юни',
  'юли',
  'август',
  'септември',
  'октомври',
  'ноември',
  'декември',
];

const monthsTr = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const monthsId = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const monthsJa = [
  '1月',
  '2月',
  '3月',
  '4月',
  '5月',
  '6月',
  '7月',
  '8月',
  '9月',
  '10月',
  '11月',
  '12月',
];

const monthsKo = [
  '1월',
  '2월',
  '3월',
  '4월',
  '5월',
  '6월',
  '7월',
  '8월',
  '9월',
  '10월',
  '11월',
  '12월',
];

const monthsZh = [
  '1月',
  '2月',
  '3月',
  '4月',
  '5月',
  '6月',
  '7月',
  '8月',
  '9月',
  '10月',
  '11月',
  '12月',
];

const monthsHi = [
  'जनवरी',
  'फ़रवरी',
  'मार्च',
  'अप्रैल',
  'मई',
  'जून',
  'जुलाई',
  'अगस्त',
  'सितंबर',
  'अक्टूबर',
  'नवंबर',
  'दिसंबर',
];

const monthsHe = [
  'ינואר',
  'פברואר',
  'מרץ',
  'אפריל',
  'מאי',
  'יוני',
  'יולי',
  'אוגוסט',
  'ספטמבר',
  'אוקטובר',
  'נובמבר',
  'דצמבר',
];

const monthsFa = [
  'ژانویه',
  'فوریه',
  'مارس',
  'آوریل',
  'مه',
  'ژوئن',
  'ژوئیه',
  'اوت',
  'سپتامبر',
  'اکتبر',
  'نوامبر',
  'دسامبر',
];

const monthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
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

/// Slovak, Czech, Polish, Ukrainian, and Russian labels lose a capital first letter. A missing label stays Latin.
String displayName(String? label, String language) {
  final value = label?.trim() ?? '';
  if (value.isEmpty) return '';
  if (language != 'sk' &&
      language != 'cs' &&
      language != 'pl' &&
      language != 'uk' &&
      language != 'ru') {
    return value;
  }
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
  final months = switch (language) {
    'sk' => monthsSk,
    'cs' => monthsCs,
    'de' => monthsDe,
    'fr' => monthsFr,
    'pl' => monthsPl,
    'hu' => monthsHu,
    'uk' => monthsUk,
    'ru' => monthsRu,
    'es' => monthsEs,
    'pt' => monthsPt,
    'nl' => monthsNl,
    'da' => monthsDa,
    'sv' => monthsSv,
    'no' => monthsNo,
    'fi' => monthsFi,
    'et' => monthsEt,
    'lv' => monthsLv,
    'lt' => monthsLt,
    'it' => monthsIt,
    'hr' => monthsHr,
    'sl' => monthsSl,
    'sr' => monthsSr,
    'ro' => monthsRo,
    'bg' => monthsBg,
    'tr' => monthsTr,
    'id' => monthsId,
    'ja' => monthsJa,
    'ko' => monthsKo,
    'zh' => monthsZh,
    'hi' => monthsHi,
    'he' => monthsHe,
    'fa' => monthsFa,
    'ar' => monthsAr,
    _ => monthsEn,
  };
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
