import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whats_that_mushroom/ads/ad_consent.dart';
import 'package:whats_that_mushroom/ads/ad_units.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/firebase_options.dart';
import 'package:whats_that_mushroom/offline/offline_book.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/purchase/billing.dart';
import 'package:whats_that_mushroom/purchase/entitlements.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/app_check.dart';
import 'package:whats_that_mushroom/shell/crash_reporting.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/shell.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await startCrashReporting();
      await GuideAnalytics.start();
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      await Auth.startGuest();
      Entitlements.start();
      Auth.syncAnalytics();
      final settings = GuideSettings();
      await settings.restore();
      unawaited(GuideAnalytics.setLanguage(settings.language));
      final notebook = Notebook();
      await notebook.load();
      try {
        await OfflineBook.restore();
      } catch (error, stack) {
        debugPrint('offline: $error');
        recordGuideError(error, stack, reason: 'offline restore');
      }
      runApp(
        GuideApp(
          settings: settings,
          notebook: notebook,
          catalog: CatalogRepository(),
        ),
      );
    },
    (error, stack) {
      if (isIgnorableGuideError(error)) return;
      debugPrint('uncaught: $error');
      recordGuideError(error, stack);
    },
  );
}

class GuideApp extends StatefulWidget {
  final GuideSettings settings;
  final Notebook notebook;
  final CatalogRepository catalog;

  const GuideApp({
    super.key,
    required this.settings,
    required this.notebook,
    required this.catalog,
  });

  @override
  State<GuideApp> createState() => _GuideAppState();
}

class _GuideAppState extends State<GuideApp> {
  var _tab = 0;
  var _appCheckStarted = false;
  Future<void>? _curatedLists;
  final _billing = FieldGuideBilling();

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettings);
    widget.notebook.addListener(_onNotebook);
    Purchases.revision.addListener(_syncAnalytics);
    GuideAppCheck.bind(_activateAppCheck);
    _load();
    unawaited(GuideAnalytics.screen(guideAnalyticsTab(0)));
    unawaited(_billing.start());
    unawaited(_startAds());
  }

  void _syncAnalytics() {
    Auth.syncAnalytics();
  }

  void _selectTab(int index) {
    if (index != _tab) {
      unawaited(GuideAnalytics.screen(guideAnalyticsTab(index)));
    }
    setState(() => _tab = index);
  }

  Future<void> _startAds() async {
    var umpFailed = false;
    try {
      umpFailed = await gatherAdConsent();
    } catch (error) {
      umpFailed = true;
      debugPrint('ads consent: $error');
    }
    var trackingAuthorized = !Platform.isIOS;
    if (Platform.isIOS) {
      try {
        final status =
            await AppTrackingTransparency.requestTrackingAuthorization();
        trackingAuthorized = status == TrackingStatus.authorized;
      } catch (error) {
        debugPrint('tracking: $error');
      }
    }
    try {
      await applyAnalyticsConsent(
        umpFailed: umpFailed,
        trackingAuthorized: trackingAuthorized,
      );
    } catch (error) {
      debugPrint('analytics consent: $error');
    }
    try {
      await MobileAds.instance.initialize();
      Ads.markReady();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('ads: $error');
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    widget.notebook.removeListener(_onNotebook);
    Purchases.revision.removeListener(_syncAnalytics);
    unawaited(_billing.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    // The list documents do not depend on the catalog or the language.
    final lists = _curatedLists ??= widget.catalog.loadCuratedLists();
    await widget.catalog.load(widget.settings.language);
    await lists;
    if (mounted) setState(() {});
    // App Check stays off until the catalog has arrived. Activating it
    // first makes Firestore wait on a debug token, and a failed exchange
    // must not block these screens.
    unawaited(() async {
      try {
        await GuideAppCheck.ensure();
      } catch (_) {
        // A failed debug token must not block the catalog screens.
      }
    }());
  }

  Future<void> _activateAppCheck() async {
    if (_appCheckStarted) return;
    _appCheckStarted = true;
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
      await Entitlements.afterAppCheck();
    } on Object {
      _appCheckStarted = false;
      rethrow;
    }
  }

  void _onSettings() {
    if (widget.settings.language != widget.catalog.language ||
        widget.catalog.data == null) {
      _load();
    }
    setState(() {});
  }

  Future<void> _reloadLists() async {
    final lists = widget.catalog.loadCuratedLists();
    _curatedLists = lists;
    await lists;
    if (mounted) setState(() {});
  }

  void _onNotebook() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final copy = Copy(widget.settings.language);
    return GuideScope(
      catalog: widget.catalog,
      notebook: widget.notebook,
      settings: widget.settings,
      reload: _load,
      reloadLists: _reloadLists,
      selectTab: _selectTab,
      child: MaterialApp(
        title: copy.app,
        debugShowCheckedModeBanner: false,
        theme: guideTheme(Brightness.light),
        darkTheme: guideTheme(Brightness.dark),
        themeMode: widget.settings.themeMode,
        locale: Locale(widget.settings.language),
        supportedLocales: const [Locale('en'), Locale('sk')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          CountryLocalizations.delegate,
        ],
        navigatorObservers: [
          GuideAnalyticsObserver(shellName: () => guideAnalyticsTab(_tab)),
        ],
        home: GuideShell(index: _tab, onSelect: _selectTab),
      ),
    );
  }
}
