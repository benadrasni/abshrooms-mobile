import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/firebase_options.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/shell.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } on Object {
    // Anonymous sign-in is only required when a photo is named.
  }
  final settings = GuideSettings();
  await settings.restore();
  final notebook = Notebook();
  await notebook.load();
  runApp(
    GuideApp(
      settings: settings,
      notebook: notebook,
      catalog: CatalogRepository(),
    ),
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

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettings);
    widget.notebook.addListener(_onNotebook);
    _load();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    widget.notebook.removeListener(_onNotebook);
    super.dispose();
  }

  Future<void> _load() async {
    await widget.catalog.load(widget.settings.language);
    if (mounted) setState(() {});
    // App Check stays off until the catalog has arrived. Activating it
    // first makes Firestore wait on a debug token, and a failed exchange
    // must not block these screens.
    if (_appCheckStarted) return;
    _appCheckStarted = true;
    unawaited(_activateAppCheck());
  }

  Future<void> _activateAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    } on Object {
      // A failed debug token must not block the catalog screens.
    }
  }

  void _onSettings() {
    if (widget.settings.language != widget.catalog.language ||
        widget.catalog.data == null) {
      _load();
    }
    setState(() {});
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
      selectTab: (index) => setState(() => _tab = index),
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
        ],
        home: GuideShell(
          index: _tab,
          onSelect: (index) => setState(() => _tab = index),
        ),
      ),
    );
  }
}
