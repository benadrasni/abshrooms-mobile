import 'package:flutter/widgets.dart';

/// Field-guide window. A phone stays under a 650-point shortest side. That
/// is every iPhone and the default widget-test surface when it is 800 by
/// 600. An iPad in portrait, including the mini at 744 points, uses the
/// [tablet] layout. A landscape window at least [wideWidth] points across
/// is [wide] and takes the side rail.
class GuideWindow {
  static const double tabletShortestSide = 650;
  static const double wideWidth = 1000;

  final bool tablet;
  final bool wide;

  const GuideWindow({required this.tablet, required this.wide});

  static GuideWindow fromSize(Size size) {
    final tablet = size.shortestSide >= tabletShortestSide;
    final landscape = size.width > size.height;
    return GuideWindow(
      tablet: tablet,
      wide: tablet && landscape && size.width >= wideWidth,
    );
  }

  static GuideWindow of(BuildContext context) {
    return fromSize(MediaQuery.sizeOf(context));
  }

  /// Column count for a grid that grows from the phone to iPad portrait,
  /// then to a wide landscape window.
  int columns({required int phone, required int tablet, required int wide}) {
    if (this.wide) return wide;
    if (this.tablet) return tablet;
    return phone;
  }

  /// Photo grids. A landscape tablet uses [wideCount] even when the window
  /// is short of [wideWidth], so an iPad mini matches a wide iPad.
  static int photoColumns(
    Size size, {
    int phone = 2,
    int portrait = 3,
    int wideCount = 4,
  }) {
    final window = fromSize(size);
    final landscape = size.width > size.height;
    return window.columns(
      phone: phone,
      tablet: landscape ? wideCount : portrait,
      wide: wideCount,
    );
  }
}

/// Where the system status column sits.
///
/// A normal phone and an iPad keep the larger inset on top, so [vertical]
/// stays false. A side inset at least a status-bar tall, and taller than
/// the top inset, is a column. The side is read from the safe area, so a
/// Split View column on the left is handled the same way as the trailing one.
class GuideChrome {
  /// Wider than a hairline inset, and at least a status-bar height.
  static const double sideColumn = 44;

  final bool vertical;
  final bool onRight;
  final double side;

  const GuideChrome({
    required this.vertical,
    required this.onRight,
    required this.side,
  });

  static const GuideChrome horizontal = GuideChrome(
    vertical: false,
    onRight: true,
    side: 0,
  );

  static GuideChrome fromPadding(EdgeInsets padding) {
    final onRight = padding.right >= padding.left;
    final side = onRight ? padding.right : padding.left;
    if (side < sideColumn || side <= padding.top) return horizontal;
    return GuideChrome(vertical: true, onRight: onRight, side: side);
  }

  static GuideChrome of(BuildContext context) {
    return fromPadding(MediaQuery.paddingOf(context));
  }
}

/// Centers a settings column on a tablet. The child gets a tight height, so
/// a [Column] with an [Expanded] still works.
class GuideReadable extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const GuideReadable({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    if (!GuideWindow.of(context).tablet) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < maxWidth
            ? constraints.maxWidth
            : maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}
