import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/shell/guide_links.dart';

void main() {
  const name = 'Boletus edulis';

  test('a shared species url round-trips to the Latin name', () {
    final languages = <String>['en', ...webPathLanguages];
    for (final lang in languages) {
      final uri = Uri.parse(webMushroomUrl(name, lang));
      expect(mushroomNameFromSharedUrl(uri), name, reason: lang);
    }
  });

  test('a hybrid name keeps its multiplication sign', () {
    const hybrid = 'Amanita × regalis';
    expect(
      mushroomNameFromSharedUrl(Uri.parse(webMushroomUrl(hybrid, 'en'))),
      hybrid,
    );
  });

  test('the firebase host and a query language still open the species', () {
    expect(
      mushroomNameFromSharedUrl(Uri.parse(
        'https://abshrooms-a9d4c.web.app/mushroom/Boletus%20edulis/?lang=de',
      )),
      name,
    );
    expect(
      mushroomNameFromSharedUrl(Uri.parse(
        'https://whatsthatmushroom.app/en/mushroom/Boletus%20edulis/',
      )),
      name,
    );
  });

  test('other pages and hosts stay in the browser', () {
    expect(
      mushroomNameFromSharedUrl(
        Uri.parse('https://whatsthatmushroom.app/family/Boletaceae/'),
      ),
      isNull,
    );
    expect(
      mushroomNameFromSharedUrl(Uri.parse('https://whatsthatmushroom.app/sk/')),
      isNull,
    );
    expect(
      mushroomNameFromSharedUrl(
        Uri.parse('https://whatsthatmushroom.app/mushroom/'),
      ),
      isNull,
    );
    expect(
      mushroomNameFromSharedUrl(
        Uri.parse(
          'https://www.whatsthatmushroom.app/mushroom/Boletus%20edulis/',
        ),
      ),
      isNull,
    );
    expect(
      mushroomNameFromSharedUrl(
        Uri.parse('https://example.com/mushroom/Boletus%20edulis/'),
      ),
      isNull,
    );
    expect(
      mushroomNameFromSharedUrl(
        Uri.parse('http://whatsthatmushroom.app/mushroom/Boletus%20edulis/'),
      ),
      isNull,
    );
  });

  test('android claims every indexed species path', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('android:pathPrefix="/mushroom/"'), isTrue);
    expect(manifest.contains('android:pathPrefix="/en/mushroom/"'), isTrue);
    expect(
      RegExp(
        'android:name="flutter_deeplinking_enabled"'
        '\\s+android:value="false"',
      ).hasMatch(manifest),
      isTrue,
    );
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist.contains('<key>FlutterDeepLinkingEnabled</key>'), isTrue);
    expect(
      plist.contains('<key>FlutterDeepLinkingEnabled</key>\n\t<false/>'),
      isTrue,
    );
    for (final lang in webPathLanguages) {
      expect(
        manifest.contains('android:pathPrefix="/$lang/mushroom/"'),
        isTrue,
        reason: lang,
      );
    }
    for (final entitlements in [
      'ios/Runner/Runner.entitlements',
      'ios/Runner/RunnerRelease.entitlements',
    ]) {
      final text = File(entitlements).readAsStringSync();
      expect(text.contains('applinks:whatsthatmushroom.app'), isTrue);
      expect(text.contains('applinks:abshrooms-a9d4c.web.app'), isTrue);
    }
  });
}
