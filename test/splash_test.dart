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
}
