import 'package:flutter/material.dart';

class GuideColors extends ThemeExtension<GuideColors> {
  final Color paper;
  final Color paper2;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color rule;
  final Color madder;
  final Color moss;
  final Color mossFill;
  final Color gold;
  final Color cream;
  final Color body;
  final Color plateWell;
  final Color onMoss;
  final Color onInk;

  const GuideColors({
    required this.paper,
    required this.paper2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.rule,
    required this.madder,
    required this.moss,
    required this.mossFill,
    required this.gold,
    required this.cream,
    required this.body,
    required this.plateWell,
    required this.onMoss,
    required this.onInk,
  });

  static const light = GuideColors(
    paper: Color(0xFFF3EEE4),
    paper2: Color(0xFFE9E2D3),
    ink: Color(0xFF1A1612),
    ink2: Color(0xFF5A5248),
    ink3: Color(0xFF6E6659),
    rule: Color(0xFFD0C6B2),
    madder: Color(0xFF8E3B2A),
    moss: Color(0xFF3E5344),
    mossFill: Color(0xFF3E5344),
    gold: Color(0xFF85603C),
    cream: Color(0xFFFFFDF8),
    body: Color(0xFF2C261F),
    plateWell: Color(0xFFEFE6D3),
    onMoss: Color(0xFFF3EEE4),
    onInk: Color(0xFFFFFFFF),
  );

  static const dark = GuideColors(
    paper: Color(0xFF15120E),
    paper2: Color(0xFF211C16),
    ink: Color(0xFFEEE6D6),
    ink2: Color(0xFFC2B7A3),
    ink3: Color(0xFF9C9180),
    rule: Color(0xFF3A332A),
    madder: Color(0xFFE08A70),
    moss: Color(0xFF9FBEA5),
    mossFill: Color(0xFF4A6652),
    gold: Color(0xFFD0A57A),
    cream: Color(0xFF1F1A15),
    body: Color(0xFFDED5C4),
    plateWell: Color(0xFF332D25),
    onMoss: Color(0xFF15120E),
    onInk: Color(0xFF15120E),
  );

  static GuideColors of(BuildContext context) {
    return Theme.of(context).extension<GuideColors>() ?? light;
  }

  static GuideColors forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  @override
  GuideColors copyWith() => this;

  @override
  GuideColors lerp(GuideColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

class GuideType {
  static const sans = 'Source Sans 3';
  static const display = 'Fraunces';

  static TextStyle wordmark(GuideColors colors) => TextStyle(
    fontFamily: display,
    fontSize: 28,
    height: 1.05,
    color: colors.ink,
  );

  static TextStyle latin(GuideColors colors, {double size = 18}) => TextStyle(
    fontFamily: display,
    fontStyle: FontStyle.italic,
    fontSize: size,
    height: 1.15,
    color: colors.ink,
  );

  static TextStyle spoken(GuideColors colors, {double size = 26}) => TextStyle(
    fontFamily: display,
    fontSize: size,
    height: 1.1,
    color: colors.ink,
  );

  static TextStyle section(GuideColors colors) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w500,
    fontSize: 18,
    height: 1.15,
    color: colors.ink,
  );

  static TextStyle question(GuideColors colors) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w500,
    fontSize: 25,
    letterSpacing: -0.4,
    height: 1.1,
    color: colors.ink,
  );

  static TextStyle eyebrow(GuideColors colors) => TextStyle(
    fontFamily: sans,
    fontSize: 11,
    letterSpacing: 1,
    fontWeight: FontWeight.w600,
    color: colors.ink2,
  );

  static TextStyle body(GuideColors colors) => TextStyle(
    fontFamily: sans,
    fontSize: 16.5,
    height: 1.4,
    color: colors.body,
  );

  static TextStyle muted(GuideColors colors, {double size = 14}) => TextStyle(
    fontFamily: sans,
    fontSize: size,
    height: 1.3,
    color: colors.ink2,
  );
}

ThemeData guideTheme(Brightness brightness) {
  final colors = GuideColors.forBrightness(brightness);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: colors.moss,
        brightness: brightness,
      ).copyWith(
        primary: colors.moss,
        onPrimary: colors.onMoss,
        surface: colors.paper,
        onSurface: colors.ink,
        error: colors.madder,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.paper,
    fontFamily: GuideType.sans,
    extensions: [colors],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.paper,
      foregroundColor: colors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerColor: colors.rule,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: colors.paper2,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: GuideType.sans, fontSize: 12, color: colors.ink),
      ),
    ),
  );
}

Color colorSwatch(String id) => switch (id) {
  'white' => const Color(0xFFF8F5EE),
  'yellow' => const Color(0xFFE4BB3B),
  'red' => const Color(0xFFC4566B),
  'brown' => const Color(0xFF8A5A3A),
  'green' => const Color(0xFF6F7D4C),
  'purple' => const Color(0xFF7A5B8A),
  'dark' => const Color(0xFF2C261F),
  _ => const Color(0xFFFFFDF8),
};
