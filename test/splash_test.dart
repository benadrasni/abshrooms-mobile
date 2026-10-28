import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/shell/splash_plate.dart';

void main() {
  testWidgets('splash fits the Boletus reticulatus plate on its paper', (
    tester,
  ) async {
    final image = await tester.runAsync(SplashPlate.load);
    expect(image, isNotNull);
    expect(image!.width, 1600);
    expect(image.height, 2400);

    await tester.pumpWidget(SplashPlate(image: image));

    expect(
      tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
      SplashPlate.paper,
    );
    final raw = tester.widget<RawImage>(find.byType(RawImage));
    expect(raw.fit, BoxFit.contain);
    expect(raw.filterQuality, FilterQuality.high);
    expect(raw.image, same(image));
  });

  test(
    'Android 12 splash shows the launcher icon on cream, including night',
    () {
      const ground =
          'android:windowSplashScreenBackground">@color/splash_color';
      for (final path in const [
        'android/app/src/main/res/values-v31/styles.xml',
        'android/app/src/main/res/values-night-v31/styles.xml',
      ]) {
        final xml = File(path).readAsStringSync();
        // Omitting the animated icon leaves the launcher icon in that slot.
        expect(
          xml.contains('windowSplashScreenAnimatedIcon'),
          isFalse,
          reason: path,
        );
        expect(xml.contains('android12splash'), isFalse, reason: path);
        expect(
          xml.contains('windowSplashScreenIconBackgroundColor'),
          isFalse,
          reason: path,
        );
        expect(xml, contains(ground), reason: path);
        expect(xml, contains('android:forceDarkAllowed">false'), reason: path);
        expect(xml, contains('Theme.Light.NoTitleBar'), reason: path);
        expect(xml.contains('Theme.Black'), isFalse, reason: path);
      }
      expect(
        File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        contains('<color name="splash_color">#F7E7CD</color>'),
      );
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:icon="@mipmap/ic_launcher"'),
      );
      expect(
        File('android/app/src/main/res/drawable-nodpi-v31/android12splash.png')
            .existsSync(),
        isFalse,
      );
    },
  );
}
