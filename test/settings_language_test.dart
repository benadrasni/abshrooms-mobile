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
    expect(englishRegionForDevice(const [Locale('en', 'GB')]), 'en_GB');
    expect(englishRegionForDevice(const [Locale('en', 'UK')]), 'en_GB');
    expect(englishRegionForDevice(const [Locale('en', 'US')]), 'en_US');
    expect(englishRegionForDevice(const [Locale('sk', 'SK')]), 'en_US');
    expect(
      englishRegionForDevice(const [
        Locale('sk', 'SK'),
      ], platformLocaleName: 'en_GB'),
      'en_GB',
    );
    expect(
      storedGuideLanguage('en', locales: const [Locale('en', 'GB')]),
      'en_GB',
    );
    expect(
      storedGuideLanguage('en', locales: const [Locale('en', 'US')]),
      'en_US',
    );
    expect(
      storedGuideLanguage('en_GB', locales: const [Locale('en', 'US')]),
      'en_GB',
    );
    expect(
      storedGuideLanguage('en_US', locales: const [Locale('en', 'GB')]),
      'en_US',
    );
    expect(
      storedGuideLanguage('de', locales: const [Locale('en', 'GB')]),
      'de',
    );
    expect(storedGuideLanguage(null, locales: const []), isNull);
  });

  test('British English keeps colour, grey, and favourite', () {
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
    expect(
      plain.colorNote,
      'Yellow includes orange. Red includes pink. Dark is gray or black. A cap can match more than one color.',
    );
    expect(us.colorNote, plain.colorNote);
    expect(
      gb.colorNote,
      'Yellow includes orange. Red includes pink. Dark is grey or black. A cap can match more than one colour.',
    );
    expect(us.favorites, 'Favorites');
    expect(gb.favorites, 'Favourites');
    expect(us.favoriteAdd, 'Mark as favorite');
    expect(gb.favoriteAdd, 'Mark as favourite');
    expect(us.favoriteRemove, 'Remove from favorites');
    expect(gb.favoriteRemove, 'Remove from favourites');
    expect(us.favoriteAdded, 'Added to Favorite mushrooms.');
    expect(gb.favoriteAdded, 'Added to Favourite mushrooms.');
    expect(us.favoriteRemoved, 'Removed from Favorite mushrooms.');
    expect(gb.favoriteRemoved, 'Removed from Favourite mushrooms.');
    expect(us.favoriteAccount, 'Favorite mushrooms stay with your account.');
    expect(gb.favoriteAccount, 'Favourite mushrooms stay with your account.');
    expect(us.favoriteMushrooms, 'Favorite mushrooms');
    expect(gb.favoriteMushrooms, 'Favourite mushrooms');
    expect(us.favoritesEmpty, 'There are no favorite mushrooms yet.');
    expect(gb.favoritesEmpty, 'There are no favourite mushrooms yet.');
    expect(Copy('sk').favoriteMushrooms, isNot('Favourite mushrooms'));
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

  testWidgets('a saved bare English follows the device region', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final settings = GuideSettings();
    await settings.restore();

    expect(settings.language, 'en_GB');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'en');
  });

  testWidgets(
    'a British phone uses British English until a language is picked',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final settings = GuideSettings();
      await settings.restore();

      expect(settings.language, 'en_GB');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language'), isNull);

      await settings.setLanguage('en');
      expect(settings.language, 'en_GB');
      expect(prefs.getString('language'), 'en_GB');
    },
  );

  testWidgets('choosing English on an American phone stores en_US', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final settings = GuideSettings();
    await settings.restore();
    await settings.setLanguage(deviceEnglishChoice());

    expect(settings.language, 'en_US');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'en_US');
  });

  testWidgets('a saved British English stays on an American phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'en_GB'});
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final settings = GuideSettings();
    await settings.restore();

    expect(settings.language, 'en_GB');
  });
}
