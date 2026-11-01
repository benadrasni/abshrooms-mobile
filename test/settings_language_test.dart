import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/language.dart';
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
      'en_US',
    );
  });

  test('British English is en_GB and every other English locale is en_US', () {
    expect(guideLanguageCode('en'), 'en_US');
    expect(guideLanguageCode('en_US'), 'en_US');
    expect(guideLanguageCode('en-AU'), 'en_US');
    expect(guideLanguageCode('en_GB'), 'en_GB');
    expect(guideLanguageCode('en-GB'), 'en_GB');
    expect(guideLanguageCode('en_UK'), 'en_GB');
    expect(guideLanguageCode('en-UK'), 'en_GB');
    expect(languageForDevice(const [Locale('en', 'GB')]), 'en_GB');
    expect(languageForDevice(const [Locale('en')]), 'en_US');
    expect(languageForDevice(const [Locale('en', 'US')]), 'en_US');
    expect(languageForDevice(const [Locale('en', 'AU')]), 'en_US');
    expect(
      languageForDevice(const [], platformLocaleName: 'en_GB.UTF-8'),
      'en_GB',
    );
    expect(contentLanguage('en_GB'), 'en');
    expect(contentLanguage('en_US'), 'en');
    expect(contentLanguage('en'), 'en');
    expect(contentLanguage('sk'), 'sk');
    expect(materialLocale('en_GB'), const Locale('en', 'GB'));
    expect(materialLocale('en_US'), const Locale('en', 'US'));
    expect(materialLocale('en'), const Locale('en', 'US'));
    expect(materialLocale('sk'), const Locale('sk'));
  });

  test('only the colour strings differ between American and British English', () {
    const us = Copy('en_US');
    const gb = Copy('en_GB');
    const plain = Copy('en');
    expect(plain.colorQuestion, 'What color is the cap?');
    expect(us.colorQuestion, 'What color is the cap?');
    expect(gb.colorQuestion, 'What colour is the cap?');
    expect(us.colorBack, 'Color');
    expect(gb.colorBack, 'Colour');
    expect(us.anyColor, 'Any color');
    expect(gb.anyColor, 'Any colour');
    expect(us.cameraKeyNote, 'Underside, place, color, season. Free, always.');
    expect(gb.cameraKeyNote, 'Underside, place, colour, season. Free, always.');
    expect(gb.underQuestion, us.underQuestion);
    expect(plain.en, isTrue);
    expect(us.en, isTrue);
    expect(gb.en, isTrue);
    expect(Copy('sk').en, isFalse);
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

  testWidgets('a saved English choice is American even on a British phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final settings = GuideSettings();
    await settings.restore();

    expect(settings.language, 'en_US');
  });

  testWidgets('a British phone uses British English until a language is picked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final settings = GuideSettings();
    await settings.restore();

    expect(settings.language, 'en_GB');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), isNull);

    await settings.setLanguage('en');
    expect(settings.language, 'en_US');
    expect(prefs.getString('language'), 'en_US');
  });
}
