import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_links/app_links.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:whats_that_mushroom/shell/app_version.dart';
import 'package:whats_that_mushroom/shell/app_version_check.dart';
import 'package:whats_that_mushroom/shell/crash_reporting.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/guide_links.dart';
import 'package:whats_that_mushroom/shell/push.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/shell.dart';
import 'package:whats_that_mushroom/shell/splash_plate.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/version_gate.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      if (Platform.isAndroid) {
        // Keeps the plate under the system bars on Android 10–14.
        unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      }
      unawaited(_boot());
    },
    (error, stack) {
      if (isIgnorableGuideError(error)) return;
      debugPrint('uncaught: $error');
      recordGuideError(error, stack);
    },
  );
}

Future<void> _boot() async {
  final plate = await SplashPlate.load();
  runApp(_Startup(plate: plate));
}

/// Android 12 shows the launcher icon first. This plate is the next frame.
/// The landing is drawn underneath, and the plate fades only after it loads.
class _Startup extends StatefulWidget {
  const _Startup({required this.plate});

  final ui.Image? plate;

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cover;
  late final CurvedAnimation _coverOpacity;
  GuideSettings? _settings;
  Notebook? _notebook;
  CatalogRepository? _catalog;
  var _coverOn = true;

  @override
  void initState() {
    super.initState();
    _cover = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 800),
    );
    _coverOpacity = CurvedAnimation(parent: _cover, curve: Curves.easeOut);
    _open();
  }

  Future<void> _open() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await startCrashReporting();
      await GuideAnalytics.start();
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      await applyRememberedVersionBlock();
      await Auth.startGuest();
      Entitlements.start();
      Auth.syncAnalytics();
      final settings = GuideSettings();
      await settings.restore();
      if (!mounted) return;
      unawaited(GuideAnalytics.setLanguage(settings.language));
      final notebook = Notebook();
      await notebook.load();
      if (!mounted) return;
      try {
        await OfflineBook.restore();
      } catch (error, stack) {
        debugPrint('offline: $error');
        recordGuideError(error, stack, reason: 'offline restore');
      }
      if (!mounted) return;
      // Find and Book paint a spinner until this read finishes. Do it under
      // the plate, then draw the landing before the fade starts.
      final catalog = CatalogRepository();
      final lists = catalog.loadCuratedLists();
      await catalog.load(settings.language);
      await lists;
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _notebook = notebook;
        _catalog = catalog;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _cover.reverse();
      if (!mounted) return;
      setState(() => _coverOn = false);
    } catch (error, stack) {
      if (isIgnorableGuideError(error)) return;
      debugPrint('startup: $error');
      recordGuideError(error, stack);
    }
  }

  @override
  void dispose() {
    _coverOpacity.dispose();
    _cover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final notebook = _notebook;
    final catalog = _catalog;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          if (settings != null && notebook != null && catalog != null)
            GuideApp(settings: settings, notebook: notebook, catalog: catalog),
          if (_coverOn)
            Positioned.fill(
              child: FadeTransition(
                opacity: _coverOpacity,
                child: SplashPlate(image: widget.plate),
              ),
            ),
        ],
      ),
    );
  }
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

class _GuideAppState extends State<GuideApp> with WidgetsBindingObserver {
  var _tab = 0;
  VersionPrompt _versionPrompt = VersionPrompt.none;
  int? _storeBuild;
  var _dismissedStore = 0;
  var _versionBusy = false;
  Future<void>? _curatedLists;
  final _billing = FieldGuideBilling();
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final GuidePush _push;
  StreamSubscription<Uri>? _sharedLinks;
  String? _pendingSharedMushroom;
  String? _openedSharedLink;
  DateTime? _openedSharedAt;
  var _sharedLinkFrames = 0;

  @override
  void initState() {
    super.initState();
    _push = GuidePush(
      navigatorKey: _navigatorKey,
      catalog: widget.catalog,
      language: widget.settings.language,
    );
    widget.settings.addListener(_onSettings);
    widget.notebook.addListener(_onNotebook);
    Purchases.revision.addListener(_syncAnalytics);
    GuideAppCheck.bind(_activateAppCheck);
    // Startup already read the catalog under the plate. A second read would
    // not block the fade, but it would fetch the book twice.
    if (widget.catalog.data == null && widget.catalog.error == null) {
      _load();
    } else {
      unawaited(_armAppCheck());
    }
    unawaited(GuideAnalytics.screen(guideAnalyticsTab(0)));
    unawaited(_billing.start());
    unawaited(_startAds());
    unawaited(_push.start());
    _listenForSharedLinks();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkVersion());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_checkVersion());
    Entitlements.applyIfLoaded();
    unawaited(Entitlements.recheckIfDue(force: true));
  }

  /// A failed read keeps a remembered floor closed. The shell only shows
  /// the soft banner. The hard page is drawn over the navigator.
  Future<void> _checkVersion() async {
    if (_versionBusy) return;
    _versionBusy = true;
    try {
      final build = await readAppBuildNumber();
      if (!mounted) return;
      final facts = await readFreshVersionFacts(build);
      final fresh = decideVersion(facts);
      await persistVersionDecision(fresh, cacheFloor: facts.fetchedFloor);
      VersionGateController.instance.apply(
        fresh.prompt == VersionPrompt.block
            ? VersionPrompt.block
            : VersionPrompt.none,
      );
      if (!mounted) return;
      var prompt = fresh.prompt == VersionPrompt.block
          ? VersionPrompt.none
          : fresh.prompt;
      final store = fresh.storeBuild;
      if (prompt == VersionPrompt.banner &&
          store != null &&
          store == _dismissedStore) {
        prompt = VersionPrompt.none;
      }
      setState(() {
        _versionPrompt = prompt;
        _storeBuild = store;
      });
    } catch (error) {
      debugPrint('version check: $error');
    } finally {
      _versionBusy = false;
    }
  }

  void _dismissVersionBanner() {
    final store = _storeBuild;
    if (store != null) {
      _dismissedStore = store;
      unawaited(rememberDismissedStore(store));
    }
    setState(() => _versionPrompt = VersionPrompt.none);
  }

  /// A shared encyclopedia URL opens that species. Cold start is the initial
  /// link. A link opened while the guide is already running arrives on the
  /// stream. The same URL twice in a moment is one open.
  void _listenForSharedLinks() {
    final links = AppLinks();
    _sharedLinks = links.uriLinkStream.listen(
      _onSharedLink,
      onError: (Object error) {
        debugPrint('guide link: $error');
      },
    );
    unawaited(_openInitialSharedLink(links));
  }

  Future<void> _openInitialSharedLink(AppLinks links) async {
    try {
      final uri = await links.getInitialLink();
      if (uri != null) _onSharedLink(uri);
    } catch (error) {
      debugPrint('guide link: $error');
    }
  }

  void _onSharedLink(Uri uri) {
    final name = mushroomNameFromSharedUrl(uri);
    if (name == null) return;
    final key = uri.toString();
    final now = DateTime.now();
    if (_openedSharedLink == key &&
        _openedSharedAt != null &&
        now.difference(_openedSharedAt!) < const Duration(seconds: 2)) {
      return;
    }
    _openedSharedLink = key;
    _openedSharedAt = now;
    final context = _navigatorKey.currentContext;
    if (!mounted || context == null) {
      _pendingSharedMushroom = name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openPendingSharedMushroom();
      });
      return;
    }
    _openSharedMushroom(context, name);
  }

  void _openPendingSharedMushroom() {
    final name = _pendingSharedMushroom;
    final context = _navigatorKey.currentContext;
    if (name == null) return;
    if (context == null) {
      if (_sharedLinkFrames >= 8) return;
      _sharedLinkFrames++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openPendingSharedMushroom();
      });
      return;
    }
    _pendingSharedMushroom = null;
    _sharedLinkFrames = 0;
    _openSharedMushroom(context, name);
  }

  void _openSharedMushroom(BuildContext context, String name) {
    openSpecies(context, name, source: GuideMushroomSource.link);
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
    WidgetsBinding.instance.removeObserver(this);
    _push.dispose();
    _sharedLinks?.cancel();
    unawaited(_billing.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    // The list documents do not depend on the catalog or the language.
    final lists = _curatedLists ??= widget.catalog.loadCuratedLists();
    await widget.catalog.load(widget.settings.language);
    await lists;
    if (mounted) setState(() {});
    unawaited(_armAppCheck());
  }

  /// App Check stays off until the catalog has been read. Activating it
  /// first makes Firestore wait on a debug token, and a failed exchange
  /// must not block these screens.
  Future<void> _armAppCheck() async {
    try {
      await GuideAppCheck.ensure();
    } catch (_) {
      // A failed debug token must not block the catalog screens.
    }
  }

  Future<void> _activateAppCheck() async {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
    );
    await Entitlements.afterAppCheck();
  }

  void _onSettings() {
    unawaited(_push.setLanguage(widget.settings.language));
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
        navigatorKey: _navigatorKey,
        title: copy.app,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return ListenableBuilder(
            listenable: VersionGateController.instance,
            builder: (context, navigator) {
              final blocked =
                  VersionGateController.instance.prompt == VersionPrompt.block;
              return Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    ignoring: blocked,
                    child: ExcludeFocus(
                      excluding: blocked,
                      child: ExcludeSemantics(
                        excluding: blocked,
                        child: navigator ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  if (blocked)
                    Positioned.fill(
                      child: VersionRequiredPage(
                        copy: GuideScope.of(context).copy,
                        onUpdate: () => openAppUpdate(requiredUpdate: true),
                      ),
                    ),
                ],
              );
            },
            child: child,
          );
        },
        theme: guideTheme(Brightness.light),
        darkTheme: guideTheme(Brightness.dark),
        themeMode: widget.settings.themeMode,
        locale: Locale(widget.settings.language),
        supportedLocales: const [
          Locale('en'),
          Locale('sk'),
          Locale('cs'),
          Locale('de'),
          Locale('fr'),
          Locale('pl'),
          Locale('hu'),
          Locale('uk'),
          Locale('ru'),
          Locale('es'),
          Locale('pt'),
          Locale('nl'),
          Locale('da'),
          Locale('sv'),
          Locale('no'),
          Locale('fi'),
          Locale('et'),
          Locale('lv'),
          Locale('lt'),
          Locale('it'),
          Locale('hr'),
          Locale('sl'),
          Locale('sr'),
          Locale('ro'),
          Locale('bg'),
          Locale('tr'),
          Locale('id'),
          Locale('ja'),
          Locale('ko'),
          Locale('zh'),
          Locale('hi'),
          Locale('he'),
          Locale('fa'),
          Locale('ar'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          CountryLocalizations.delegate,
        ],
        navigatorObservers: [
          GuideAnalyticsObserver(shellName: () => guideAnalyticsTab(_tab)),
        ],
        home: GuideShell(
          index: _tab,
          onSelect: _selectTab,
          versionPrompt: _versionPrompt,
          onVersionUpdate: () =>
              unawaited(openAppUpdate(requiredUpdate: false)),
          onVersionDismiss: _dismissVersionBanner,
        ),
      ),
    );
  }
}
