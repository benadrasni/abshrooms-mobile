import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Boletus reticulatus plate shown after the launcher icon.
///
/// The mushrooms sit on flat paper. The plate's dark edge is not
/// part of the picture, so it does not show as a frame. Android 12
/// shows the app icon on this paper first. iOS opens on this sheet.
class SplashPlate extends StatelessWidget {
  const SplashPlate({super.key, this.image});

  static const paper = Color(0xFFF7E7CD);
  static const asset = 'assets/splash_plate.jpg';

  /// Already decoded, so the first frame can paint the plate.
  final ui.Image? image;

  static Future<ui.Image?> load() async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (error) {
      debugPrint('splash: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: paper,
        child: image == null
            ? null
            : RawImage(
                image: image,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
      ),
    );
  }
}
