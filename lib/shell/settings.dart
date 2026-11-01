import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';

/// A guide language code, or null when [raw] is missing or unsupported.
///
/// Norwegian Bokmål and Nynorsk (`nb`, `nn`) use `no`. Legacy Android codes
/// `iw` and `in` use Hebrew and Indonesian. English with a region is `en_GB`
/// for the United Kingdom (`gb` or `uk`) and `en_US` otherwise. A bare `en`
/// is `en_US` here. A saved legacy `en` follows the device; see
/// [storedGuideLanguage].
String? guideLanguageCode(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.toLowerCase().split('.').first.split(RegExp('[-_]'));
  if (parts.isEmpty || parts.first.isEmpty) return null;
  final base = parts.first;
  if (base == 'en') {
    final region = parts.length > 1 ? parts[1] : '';
    if (region == 'gb' || region == 'uk') return 'en_GB';
    return 'en_US';
  }
  final code = switch (base) {
    'nb' || 'nn' => 'no',
    'iw' => 'he',
    'in' => 'id',
    _ => base,
  };
  return _supportedLanguages.contains(code) ? code : null;
}

/// First language in [locales] the guide can show.
///
/// The phone's preferred list is tried in order, including the country, so
/// British English can be told from other English. [Platform.localeName] is
/// only the fallback: on Android it often stays `en_US` while
/// [WidgetsBinding.platformDispatcher] has the real list. An unsupported
/// phone language uses [platformLocaleName], then American English.
String languageForDevice(
  Iterable<Locale> locales, {
  String platformLocaleName = '',
}) {
  for (final locale in locales) {
    final country = locale.countryCode;
    final tag = country == null || country.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_$country';
    final code = guideLanguageCode(tag);
    if (code != null) return code;
  }
  final fallback = platformLocaleName.split('.').first;
  return guideLanguageCode(fallback) ?? 'en_US';
}

/// English spelling for this device. British English and `en_UK` stay `en_GB`.
/// Every other English region, and a phone that is not English, is `en_US`.
String englishRegionForDevice(
  Iterable<Locale> locales, {
  String platformLocaleName = '',
}) {
  for (final locale in locales) {
    if (locale.languageCode.toLowerCase() != 'en') continue;
    final region = (locale.countryCode ?? '').toLowerCase();
    if (region == 'gb' || region == 'uk') return 'en_GB';
    if (region.isNotEmpty) return 'en_US';
  }
  final platform = guideLanguageCode(platformLocaleName);
  if (platform == 'en_GB' || platform == 'en_US') return platform!;
  return 'en_US';
}

/// A saved language. A legacy bare `en` follows the device's English region
/// and is not rewritten to `en_US`. An explicit `en_GB` or `en_US` stays.
String? storedGuideLanguage(
  String? raw, {
  required Iterable<Locale> locales,
  String platformLocaleName = '',
}) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parts = raw.toLowerCase().split('.').first.split(RegExp('[-_]'));
  final bareEnglish =
      parts.isNotEmpty &&
      parts.first == 'en' &&
      (parts.length == 1 || parts[1].isEmpty);
  if (bareEnglish) {
    return englishRegionForDevice(
      locales,
      platformLocaleName: platformLocaleName,
    );
  }
  return guideLanguageCode(raw);
}

/// The English spelling kept when the person picks English on this phone.
String deviceEnglishChoice() {
  return englishRegionForDevice(
    WidgetsBinding.instance.platformDispatcher.locales,
    platformLocaleName: Platform.localeName,
  );
}

/// Widget locale. `Locale('en_US')` would treat the whole tag as a language
/// code, so English uses a language plus a country.
Locale materialLocale(String code) {
  return switch (code) {
    'en_GB' => const Locale('en', 'GB'),
    'en_US' || 'en' => const Locale('en', 'US'),
    _ => Locale(code),
  };
}

const _supportedLanguages = {
  'en',
  'sk',
  'cs',
  'de',
  'fr',
  'pl',
  'hu',
  'uk',
  'ru',
  'es',
  'pt',
  'nl',
  'da',
  'sv',
  'no',
  'fi',
  'et',
  'lv',
  'lt',
  'it',
  'hr',
  'sl',
  'sr',
  'ro',
  'bg',
  'tr',
  'id',
  'ja',
  'ko',
  'zh',
  'hi',
  'he',
  'fa',
  'ar',
};

class GuideSettings extends ChangeNotifier {
  String language = 'en';
  ThemeMode themeMode = ThemeMode.system;
  SharedPreferences? _prefs;

  Future<void> restore() async {
    _prefs = await SharedPreferences.getInstance();
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    final platformLocaleName = Platform.localeName;
    final stored = storedGuideLanguage(
      _prefs!.getString('language'),
      locales: locales,
      platformLocaleName: platformLocaleName,
    );
    // A saved choice wins. The phone language is not written here, so a
    // later change of the device language still applies until the user
    // picks a language. A legacy stored `en` keeps following that region.
    language =
        stored ??
        languageForDevice(locales, platformLocaleName: platformLocaleName);
    themeMode = switch (_prefs!.getString('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    language =
        storedGuideLanguage(
          code,
          locales: WidgetsBinding.instance.platformDispatcher.locales,
          platformLocaleName: Platform.localeName,
        ) ??
        'en_US';
    await _prefs?.setString('language', language);
    notifyListeners();
    unawaited(GuideAnalytics.language(language));
    unawaited(GuideAnalytics.setLanguage(language));
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    final stored = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    };
    if (stored == null) {
      await _prefs?.remove('theme');
    } else {
      await _prefs?.setString('theme', stored);
    }
    notifyListeners();
  }
}
