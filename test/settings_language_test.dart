import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/shell/settings.dart';

void main() {
  test('a Slovak phone uses Slovak', () {
    expect(languageForDevice(const [Locale('sk', 'SK')]), 'sk');
  });

  test('an unsupported language falls through to the next one', () {
    expect(languageForDevice(const [Locale('gsw'), Locale('de', 'AT')]), 'de');
  });

  test('Norwegian Bokmål and Nynorsk use Norwegian', () {
    expect(languageForDevice(const [Locale('nb', 'NO')]), 'no');
    expect(languageForDevice(const [Locale('nn', 'NO')]), 'no');
  });

  test('legacy Hebrew and Indonesian codes are recognized', () {
    expect(languageForDevice(const [Locale('iw')]), 'he');
    expect(languageForDevice(const [Locale('in')]), 'id');
    expect(guideLanguageCode('iw_IL'), 'he');
    expect(guideLanguageCode('in_ID'), 'id');
  });

  test('an unknown phone language uses the platform name, then English', () {
    expect(
      languageForDevice(const [], platformLocaleName: 'cs_CZ.UTF-8'),
      'cs',
    );
    expect(
      languageForDevice(const [Locale('und')], platformLocaleName: 'xx'),
      'en',
    );
  });

  testWidgets('first launch follows the phone and does not store it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localesTestValue = const [Locale('sk', 'SK')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final settings = GuideSettings();
    await settings.restore();

    expect(settings.language, 'sk');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), isNull);
  });

  testWidgets('a saved language stays when the phone language differs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'de'});
    tester.platformDispatcher.localesTestValue = const [Locale('sk', 'SK')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final settings = GuideSettings();
    await settings.restore();

    expect(settings.language, 'de');
  });

  testWidgets('a language the user picks is kept for the next launch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localesTestValue = const [Locale('sk', 'SK')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final settings = GuideSettings();
    await settings.restore();
    await settings.setLanguage('pl');

    final again = GuideSettings();
    await again.restore();
    expect(again.language, 'pl');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'pl');
  });
}
