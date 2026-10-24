import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuideSettings extends ChangeNotifier {
  String language = 'en';
  ThemeMode themeMode = ThemeMode.system;
  SharedPreferences? _prefs;

  Future<void> restore() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs!.getString('language');
    language = stored == 'sk' || stored == 'en' ? stored! : _deviceLanguage();
    themeMode = switch (_prefs!.getString('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  String _deviceLanguage() {
    final code = Platform.localeName.split(RegExp('[_\\.]')).first;
    return code == 'sk' ? 'sk' : 'en';
  }

  Future<void> setLanguage(String code) async {
    language = code == 'sk' ? 'sk' : 'en';
    await _prefs?.setString('language', language);
    notifyListeners();
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
