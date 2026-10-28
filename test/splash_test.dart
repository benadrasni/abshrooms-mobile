import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

  test('Android 12 splash shows the plate on cream, including night', () {
    const icon =
        'android:windowSplashScreenAnimatedIcon">@drawable/android12splash';
    const ground = 'android:windowSplashScreenBackground">@color/splash_color';
    for (final path in const [
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      final xml = File(path).readAsStringSync();
      expect(xml, contains(icon), reason: path);
      expect(xml, contains(ground), reason: path);
      expect(
        xml,
        contains(
          'android:windowSplashScreenIconBackgroundColor">@color/splash_color',
        ),
        reason: path,
      );
      expect(xml, contains('android:forceDarkAllowed">false'), reason: path);
      expect(xml, contains('Theme.Light.NoTitleBar'), reason: path);
      expect(xml.contains('ic_launcher'), isFalse, reason: path);
      expect(xml.contains('Theme.Black'), isFalse, reason: path);
    }
    expect(
      File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
      contains('<color name="splash_color">#F7E7CD</color>'),
    );

    final plate = img.decodePng(
      File('android/app/src/main/res/drawable-nodpi-v31/android12splash.png')
          .readAsBytesSync(),
    );
    expect(plate, isNotNull);
    expect(plate!.width, 1152);
    expect(plate.height, 1152);
    expect(_cream(plate.getPixel(0, 0)), isTrue);
    expect(_cream(plate.getPixel(1151, 1151)), isTrue);
    // Outside the inner circle the mask shows the cream window.
    expect(_cream(plate.getPixel(8, 8)), isTrue);
    expect(_cream(plate.getPixel(576, 576)), isFalse);
  });
}

bool _cream(img.Pixel pixel) {
  return (pixel.r.toInt() - 247).abs() <= 2 &&
      (pixel.g.toInt() - 231).abs() <= 2 &&
      (pixel.b.toInt() - 205).abs() <= 2;
}
