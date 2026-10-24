import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

class PersonPage extends StatelessWidget {
  const PersonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final settings = scope.settings;
    final platform = MediaQuery.platformBrightnessOf(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _BackButton(),
            _LanguageRow(
              name: settings.language == 'sk' ? copy.slovak : copy.english,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LanguagePage())),
            ),
            _ThemeRow(
              mode: settings.themeMode,
              detail: _themeDetail(copy, settings.themeMode, platform),
              onChoose: settings.setTheme,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Text(copy.aboutHeadline, style: GuideType.section(colors)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(
                copy.aboutBody,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 14,
                  height: 1.4,
                  color: colors.ink2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                copy.noCustomLists,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 13,
                  height: 1.3,
                  color: colors.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _themeDetail(Copy copy, ThemeMode mode, Brightness platform) {
  return switch (mode) {
    ThemeMode.light => copy.themeAlwaysLight,
    ThemeMode.dark => copy.themeAlwaysDark,
    ThemeMode.system =>
      platform == Brightness.dark
          ? copy.themeLikePhoneDark
          : copy.themeLikePhoneLight,
  };
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final selected = scope.settings.language;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _BackButton(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(copy.language, style: GuideType.question(colors)),
                  const SizedBox(height: 6),
                  Text(
                    copy.languageNote,
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 14,
                      height: 1.35,
                      color: colors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            _LanguageChoice(
              name: copy.english,
              selected: selected == 'en',
              onTap: () => _choose(context, 'en'),
            ),
            _LanguageChoice(
              name: copy.slovak,
              english: copy.sk ? null : copy.slovakInEnglish,
              selected: selected == 'sk',
              onTap: () => _choose(context, 'sk'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, String code) async {
    await GuideScope.of(context).settings.setLanguage(code);
    if (context.mounted) Navigator.maybePop(context);
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        onTap: () => Navigator.maybePop(context),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: IconThemeData(color: colors.moss, size: 20),
                  child: const BackButtonIcon(),
                ),
                const SizedBox(width: 8),
                Text(
                  GuideScope.of(context).copy.back,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    color: colors.moss,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _LanguageRow({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final forward = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 8, 14),
          child: Row(
            children: [
              Icon(Icons.language, size: 22, color: colors.moss),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  copy.language,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.ink2,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(forward, size: 22, color: colors.ink2),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final ThemeMode mode;
  final String detail;
  final ValueChanged<ThemeMode> onChoose;

  const _ThemeRow({
    required this.mode,
    required this.detail,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 12, 10),
        child: Row(
          children: [
            Icon(Icons.contrast, size: 22, color: colors.moss),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.theme,
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    detail,
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 13,
                      color: colors.ink2,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ThemeSegment(mode: mode, onChoose: onChoose),
          ],
        ),
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChoose;

  const _ThemeSegment({required this.mode, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final copy = GuideScope.of(context).copy;
    final colors = GuideColors.of(context);
    final choices = [
      (ThemeMode.light, copy.themeLight),
      (ThemeMode.dark, copy.themeDark),
      (ThemeMode.system, copy.themeSystem),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final choice in choices)
            _ThemeChoice(
              label: choice.$2,
              selected: mode == choice.$1,
              onPressed: () => onChoose(choice.$1),
            ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _ThemeChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final onInk = Theme.of(context).brightness == Brightness.dark
        ? colors.paper
        : Colors.white;
    return Material(
      color: selected ? colors.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            height: 28,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? onInk : colors.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  final String name;
  final String? english;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageChoice({
    required this.name,
    required this.selected,
    required this.onTap,
    this.english,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? colors.moss.withValues(alpha: 0.12) : null,
        border: BorderDirectional(
          bottom: BorderSide(color: colors.rule),
          start: BorderSide(
            color: selected ? colors.moss : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(17, 11, 20, 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                          height: 1.2,
                        ),
                      ),
                      if (english != null)
                        Text(
                          english!,
                          style: TextStyle(
                            fontFamily: GuideType.sans,
                            fontSize: 13,
                            height: 1.3,
                            color: colors.ink2,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 18, color: colors.moss),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
