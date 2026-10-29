import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';

/// A guide language code, or null when [raw] is missing or unsupported.
///
/// Norwegian Bokmål and Nynorsk (`nb`, `nn`) use `no`. Legacy Android codes
/// `iw` and `in` use Hebrew and Indonesian.
String? guideLanguageCode(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final base = raw.toLowerCase().split(RegExp('[-_]')).first;
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
/// The phone's preferred list is tried in order. [Platform.localeName] is
/// only the fallback: on Android it often stays `en_US` while
/// [WidgetsBinding.platformDispatcher] has the real list. An unsupported
/// phone language uses [platformLocaleName], then English.
String languageForDevice(
  Iterable<Locale> locales, {
  String platformLocaleName = '',
}) {
  for (final locale in locales) {
    final code = guideLanguageCode(locale.languageCode);
    if (code != null) return code;
  }
  final fallback = platformLocaleName.split(RegExp(r'[_.]')).first;
  return guideLanguageCode(fallback) ?? 'en';
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
    final stored = guideLanguageCode(_prefs!.getString('language'));
    // A saved choice wins. The phone language is not written here, so a
    // later change of the device language still applies until the user
    // picks a language.
    language =
        stored ??
        languageForDevice(
          WidgetsBinding.instance.platformDispatcher.locales,
          platformLocaleName: Platform.localeName,
        );
    themeMode = switch (_prefs!.getString('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    language = guideLanguageCode(code) ?? 'en';
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
