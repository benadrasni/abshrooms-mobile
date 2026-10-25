import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:whats_that_mushroom/ads/ad_consent.dart';
import 'package:whats_that_mushroom/ads/ad_units.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/field_guide/catalog.dart';
import 'package:whats_that_mushroom/field_guide/field_guide_page.dart';
import 'package:whats_that_mushroom/offline/offline_book.dart';
import 'package:whats_that_mushroom/offline/offline_page.dart';
import 'package:whats_that_mushroom/offline/offline_plan.dart';
import 'package:whats_that_mushroom/person/account.dart';
import 'package:whats_that_mushroom/person/account_deletion.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/person/sign_in_page.dart';
import 'package:whats_that_mushroom/purchase/billing.dart';
import 'package:whats_that_mushroom/purchase/names.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

class PersonPage extends StatefulWidget {
  final String? versionName;
  final String? buildNumber;
  final AccountView? Function()? accountOf;
  final Future<void> Function()? onSignOut;

  const PersonPage({
    super.key,
    this.versionName,
    this.buildNumber,
    this.accountOf,
    this.onSignOut,
  });

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  String? _versionName;
  String? _buildNumber;
  var _restoring = false;
  var _adPrivacy = false;

  @override
  void initState() {
    super.initState();
    _versionName = widget.versionName;
    _buildNumber = widget.buildNumber;
    Purchases.revision.addListener(_onPlan);
    Names.revision.addListener(_onPlan);
    Auth.revision.addListener(_onPlan);
    OfflineBook.revision.addListener(_onPlan);
    Ads.ready.addListener(_onAdsReady);
    if (Ads.enabled) unawaited(_loadAdPrivacy());
    if (widget.versionName == null && widget.buildNumber == null) {
      unawaited(_loadVersion());
    }
  }

  @override
  void dispose() {
    Purchases.revision.removeListener(_onPlan);
    Names.revision.removeListener(_onPlan);
    Auth.revision.removeListener(_onPlan);
    OfflineBook.revision.removeListener(_onPlan);
    Ads.ready.removeListener(_onAdsReady);
    super.dispose();
  }

  void _onAdsReady() {
    if (Ads.enabled) unawaited(_loadAdPrivacy());
  }

  Future<void> _loadAdPrivacy() async {
    final show = await adPrivacyOptionsRequired();
    if (!mounted || !show || _adPrivacy) return;
    setState(() => _adPrivacy = true);
  }

  void _onPlan() {
    if (mounted) setState(() {});
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionName = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (error) {
      debugPrint('version: $error');
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final copy = GuideScope.of(context).copy;
    try {
      final started = await restoreFieldGuidePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(started ? copy.restoring : copy.restoreFailed)),
      );
    } catch (error) {
      debugPrint('restore: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(copy.restoreFailed)));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final settings = scope.settings;
    final platform = MediaQuery.platformBrightnessOf(context);
    final version = versionLine(
      label: copy.versionLabel,
      version: _versionName ?? '',
      build: _buildNumber ?? '',
    );
    final account = widget.accountOf == null
        ? readSignedInAccount()
        : widget.accountOf!();
    final guide = Purchases.hasFieldGuide();
    final lines = account == null
        ? null
        : accountLines(
            name: account.name,
            email: account.email,
            phone: account.phone,
            provider: account.provider,
            yourAccount: copy.yourAccount,
            signedIn: copy.signedIn,
            google: copy.googleAccount,
            apple: copy.appleAccount,
            emailPassword: copy.emailPassword,
            phoneLabel: copy.phoneAccount,
            appleHidden: copy.appleHidden,
          );
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const _BackButton(),
            if (lines != null) _AccountHeader(lines: lines),
            if (lines != null && !guide)
              _NamesMonthCard(
                month: MonthNames.of(Names.count, DateTime.now()),
              ),
            if (lines == null || guide) ...[
              _PersonCard(
                title: guide ? copy.fieldGuide : copy.signInCardTitle,
                note: guide ? copy.fieldGuidePerks : copy.signInFree,
                onOpen: guide
                    ? () => Navigator.of(context).push(
                        guideRoute<void>(
                          guideScreenFieldGuide,
                          (_) => const FieldGuidePage(),
                        ),
                      )
                    : null,
                onSignIn: lines == null
                    ? () => Navigator.of(context).push(
                        guideRoute<void>(
                          guideScreenSignIn,
                          (_) => const SignInPage(),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 4),
            ],
            if (!guide)
              _MenuRow(
                icon: Icons.eco_outlined,
                title: copy.fieldGuide,
                subtitle: copy.fieldGuideOffer,
                onTap: () => Navigator.of(context).push(
                  guideRoute<void>(
                    guideScreenFieldGuide,
                    (_) => const FieldGuidePage(),
                  ),
                ),
              ),
            _MenuRow(
              icon: Icons.restore,
              title: copy.restore,
              subtitle: _restoring ? copy.restoring : copy.restoreNote,
              onTap: _restore,
            ),
            _LanguageRow(
              name: settings.language == 'sk' ? copy.slovak : copy.english,
              onTap: () => Navigator.of(
                context,
              ).push(
                guideRoute(guideScreenLanguage, (_) => const LanguagePage()),
              ),
            ),
            _ThemeRow(
              mode: settings.themeMode,
              detail: _themeDetail(copy, settings.themeMode, platform),
              onChoose: settings.setTheme,
            ),
            if (_adPrivacy)
              _MenuRow(
                icon: Icons.privacy_tip_outlined,
                title: copy.adPrivacy,
                subtitle: copy.adPrivacyNote,
                onTap: () {
                  unawaited(showAdPrivacyOptions());
                },
              ),
            _MenuRow(
              icon: Icons.cloud_outlined,
              title: copy.offlineTitle,
              subtitle: offlineMenuLine(
                copy,
                canDownload: guide,
                stored: OfflineBook.stored,
                species: scope.catalogData?.species.length,
                updateSpecies: _offlineUpdates(scope.catalogData),
              ),
              onTap: () => Navigator.of(context).push(
                guideRoute<void>(guideScreenOffline, (_) => const OfflinePage()),
              ),
            ),
            _MenuRow(
              icon: Icons.star_outline,
              title: copy.rate,
              subtitle: copy.rateNote,
              onTap: () {
                unawaited(openWriteReview());
              },
            ),
            if (lines != null) ...[
              _MenuRow(
                icon: Icons.person_outline,
                title: copy.signOut,
                subtitle: copy.signOutNote,
                onTap: () {
                  unawaited(
                    widget.onSignOut == null
                        ? Auth.signOut()
                        : widget.onSignOut!(),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 6),
                child: Text(
                  copy.dangerZone,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.ink3,
                    height: 1.2,
                  ),
                ),
              ),
              _MenuRow(
                icon: Icons.delete_outline,
                title: copy.deleteAccount,
                subtitle: copy.deleteAccountNote,
                danger: true,
                onTap: () async {
                  final result = await confirmAndDeleteAccount(context);
                  if (!context.mounted) return;
                  showDeleteAccountResult(context, result);
                },
              ),
            ],
            if (version.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Center(
                  child: TextButton(
                    key: const Key('guide-version'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: version));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(version)));
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colors.ink3,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontFamily: GuideType.sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Text(version),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  final AccountLines lines;

  const _AccountHeader({required this.lines});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final avatar = lines.phoneAvatar
        ? const Icon(Icons.smartphone_outlined, color: Colors.white, size: 24)
        : lines.initial.isEmpty
        ? const Icon(Icons.person, color: Colors.white, size: 26)
        : Text(
            lines.initial,
            style: const TextStyle(
              fontFamily: GuideType.display,
              fontSize: 24,
              color: Colors.white,
              height: 1,
            ),
          );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 14),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.gold,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Center(child: avatar),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lines.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                Text(
                  lines.detail,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 13,
                    color: colors.ink3,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final tone = danger ? colors.madder : colors.moss;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: GuideType.sans,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: danger ? colors.madder : colors.ink,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: GuideType.sans,
                        fontSize: 13,
                        color: colors.ink3,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NamesMonthCard extends StatelessWidget {
  final MonthNames month;

  const _NamesMonthCard({required this.month});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final note = TextStyle(
      fontFamily: GuideType.sans,
      fontSize: 12,
      color: colors.ink3,
      height: 1.35,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
      child: Material(
        color: colors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.rule),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.namesThisMonth,
                      style: TextStyle(
                        fontFamily: GuideType.sans,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                        height: 1.25,
                      ),
                    ),
                  ),
                  Text(copy.namesReset(month.resetsOn), style: note),
                ],
              ),
              const SizedBox(height: 10),
              _NamesBar(month: month),
              const SizedBox(height: 6),
              Text(
                copy.namesMonthDetail(
                  includedUsed: month.includedUsed,
                  extraUsed: month.extraUsed,
                  adsLeft: month.adsLeft,
                ),
                style: note,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NamesBar extends StatelessWidget {
  final MonthNames month;

  const _NamesBar({required this.month});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final parts = <Widget>[
      if (month.includedUsed > 0)
        Expanded(
          flex: month.includedUsed,
          child: ColoredBox(color: colors.mossFill),
        ),
      if (month.extraUsed > 0)
        Expanded(
          flex: month.extraUsed,
          child: ColoredBox(color: colors.gold),
        ),
      if (month.rest > 0)
        Expanded(
          flex: month.rest,
          child: ColoredBox(color: colors.paper2),
        ),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        width: double.infinity,
        child: Row(children: parts),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String title;
  final String note;
  final VoidCallback? onOpen;
  final VoidCallback? onSignIn;

  const _PersonCard({
    required this.title,
    required this.note,
    required this.onOpen,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
      child: Material(
        color: colors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.rule),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 12,
                    color: colors.ink3,
                    height: 1.35,
                  ),
                ),
                if (onSignIn != null) ...[
                  const SizedBox(height: 10),
                  _SignInButton(label: copy.signIn, onPressed: onSignIn),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SignInButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: colors.mossFill,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: SizedBox(
              height: 34,
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int _offlineUpdates(Catalog? catalog) {
  if (catalog == null || !OfflineBook.stored) return 0;
  return offlineMissingSpecies(
    catalog.species,
    saved: OfflineBook.saved,
    skipped: OfflineBook.skipped,
  );
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
              Expanded(
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
              Icon(forward, size: 22, color: colors.ink3),
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
                      color: colors.ink3,
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
                  color: selected ? colors.onInk : colors.ink3,
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
