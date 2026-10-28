/// Hosts that share a species page. www is a different site.
const Set<String> sharedLinkHosts = {
  'whatsthatmushroom.app',
  'abshrooms-a9d4c.web.app',
};

const String webUrl = 'https://whatsthatmushroom.app/';

/// Website path prefixes. English is unprefixed. Keep in sync with
/// web/catalog.js PATH_LANGS.
const List<String> webPathLanguages = [
  'ar',
  'bg',
  'zh',
  'hr',
  'cs',
  'da',
  'nl',
  'et',
  'fi',
  'fr',
  'de',
  'he',
  'hi',
  'hu',
  'id',
  'it',
  'ja',
  'ko',
  'lv',
  'lt',
  'no',
  'fa',
  'pl',
  'pt',
  'ro',
  'ru',
  'sr',
  'sk',
  'sl',
  'es',
  'sv',
  'tr',
  'uk',
];

/// Encyclopedia URL for one species. Indexed languages use /sk/mushroom/…;
/// English is unprefixed.
String webMushroomUrl(String latinName, String languageCode) {
  final name = Uri.encodeComponent(latinName);
  final origin = webUrl.substring(0, webUrl.length - 1);
  final prefix =
      webPathLanguages.contains(languageCode) ? '/$languageCode' : '';
  return '$origin$prefix/mushroom/$name/';
}

/// Latin name from a shared encyclopedia URL, or null when the URL is not
/// a species page.
///
/// English is `/mushroom/Boletus%20edulis/`. An indexed language is
/// `/sk/mushroom/Boletus%20edulis/`. `?lang=` does not change the name.
String? mushroomNameFromSharedUrl(Uri uri) {
  if (uri.scheme != 'https') return null;
  if (!sharedLinkHosts.contains(uri.host.toLowerCase())) return null;
  final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  final String raw;
  if (parts.length == 2 && parts[0] == 'mushroom') {
    raw = parts[1];
  } else if (parts.length == 3 &&
      parts[1] == 'mushroom' &&
      _sharedLinkLanguage(parts[0])) {
    raw = parts[2];
  } else {
    return null;
  }
  final name = raw.trim();
  if (name.isEmpty || name.length > 200) return null;
  if (name.contains('/') || name.contains('\\') || name.contains('#')) {
    return null;
  }
  return name;
}

bool _sharedLinkLanguage(String code) {
  return code == 'en' || webPathLanguages.contains(code);
}
