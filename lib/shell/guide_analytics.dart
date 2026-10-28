import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/crash_reporting.dart';

/// Where a species page was opened. Values are analytics parameters.
class GuideMushroomSource {
  static const search = 'search';
  static const key = 'key';
  static const list = 'list';
  static const photo = 'photo';
  static const favorite = 'favorite';
  static const seen = 'seen';
  static const outside = 'outside';
  static const notification = 'notification';
}

const guideScreenFind = 'Find';
const guideScreenBook = 'Book';
const guideScreenSeen = 'Seen';
const guideScreenSearch = 'Search';
const guideScreenSpecies = 'Species';
const guideScreenCamera = 'Camera';
const guideScreenPerson = 'Person';
const guideScreenSignIn = 'SignIn';
const guideScreenFieldGuide = 'FieldGuide';
const guideScreenOffline = 'Offline';
const guideScreenLanguage = 'Language';
const guideScreenWhere = 'Where';
const guideScreenColour = 'Colour';
const guideScreenResults = 'Results';
const guideScreenOutside = 'Outside';
const guideScreenNew = 'New';
const guideScreenFavorites = 'Favorites';
const guideScreenFamily = 'Family';
const guideScreenGenus = 'Genus';
const guideScreenStatistics = 'Statistics';

/// Find, Book, and Seen stay on one route, so each tab is its own screen.
String guideAnalyticsTab(int index) {
  switch (index) {
    case 1:
      return guideScreenBook;
    case 2:
      return guideScreenSeen;
    default:
      return guideScreenFind;
  }
}

String guideTaxonScreen(String kind) {
  switch (kind) {
    case 'family':
      return guideScreenFamily;
    case 'genus':
      return guideScreenGenus;
    case 'favorites':
      return guideScreenFavorites;
    default:
      return 'Taxon';
  }
}

/// Consent to send to Firebase after the ads form and the tracking prompt.
class GuideAnalyticsConsent {
  final bool analyticsStorage;
  final bool adStorage;
  final bool adUserData;
  final bool adPersonalization;

  const GuideAnalyticsConsent({
    required this.analyticsStorage,
    required this.adStorage,
    required this.adUserData,
    required this.adPersonalization,
  });
}

/// A failed consent request denies collection. A required choice that was
/// refused or not given denies storage. Ad personalization also needs
/// permission to track.
GuideAnalyticsConsent guideAnalyticsConsent({
  required bool umpFailed,
  required bool consentKnown,
  required bool consentRequired,
  required bool canRequestAds,
  required bool trackingAuthorized,
}) {
  final storage =
      !umpFailed && consentKnown && (!consentRequired || canRequestAds);
  final ads = storage && trackingAuthorized;
  return GuideAnalyticsConsent(
    analyticsStorage: storage,
    adStorage: storage,
    adUserData: ads,
    adPersonalization: ads,
  );
}

/// Last segment of a list id, safe to put in a screen name.
String guideAnalyticsListId(String raw) {
  var value = raw.trim();
  if (value.startsWith('/')) value = value.substring(1);
  final parts = value.split('/').where((part) => part.isNotEmpty);
  final last = parts.isEmpty ? '' : parts.last;
  final safe = last.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  if (safe.isEmpty) return '';
  return safe.length <= 36 ? safe : safe.substring(0, 36);
}

/// `List/deadly-poisonous`. An empty id stays `List`.
String guideListScreen(String id) {
  final safe = guideAnalyticsListId(id);
  return safe.isEmpty ? 'List' : 'List/$safe';
}

String? guideAnalyticsText(String? value, {int max = 100}) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= max ? trimmed : trimmed.substring(0, max);
}

String guideAnalyticsAuthMethod(String providerId) {
  switch (providerId) {
    case 'google.com':
      return 'google';
    case 'apple.com':
      return 'apple';
    case 'password':
      return 'email';
    case 'phone':
      return 'phone';
    default:
      return 'other';
  }
}

String guideAnalyticsProductCategory(String productId) {
  if (FieldGuideIds.isFieldGuide(productId)) return 'subscription';
  return 'other';
}

/// A named page, so the navigator observer can record the screen.
MaterialPageRoute<T> guideRoute<T>(String name, WidgetBuilder builder) {
  return MaterialPageRoute<T>(
    settings: RouteSettings(name: name),
    builder: builder,
  );
}

/// Records named routes. The shell has no route name, so a pop back to it
/// uses [shellName], which is the Find, Book, or Seen tab.
class GuideAnalyticsObserver extends NavigatorObserver {
  final String Function()? shellName;

  GuideAnalyticsObserver({this.shellName});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _named(route.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _named(newRoute?.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) return;
    final name = previousRoute?.settings.name;
    if (name != null && name.isNotEmpty) {
      _named(name);
      return;
    }
    _named(shellName?.call());
  }

  void _named(String? name) {
    if (name == null || name.isEmpty) return;
    unawaited(GuideAnalytics.screen(name));
  }
}

/// Firebase Analytics for the field guide.
///
/// Debug builds send nothing. A debug install also turns collection off,
/// because that switch is stored on the phone and would otherwise keep a
/// later release build quiet. Release builds keep collection off until
/// [applyConsent] records a grant. A failed consent request stays off.
class GuideAnalytics {
  static bool _trackingAuthorized = false;

  static Future<void> start() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final analytics = FirebaseAnalytics.instance;
      if (kDebugMode) {
        await analytics.setAnalyticsCollectionEnabled(false);
        return;
      }
      await analytics.setAnalyticsCollectionEnabled(false);
      await _consent(
        analytics,
        const GuideAnalyticsConsent(
          analyticsStorage: false,
          adStorage: false,
          adUserData: false,
          adPersonalization: false,
        ),
      );
    } catch (error) {
      debugPrint('analytics: $error');
    }
  }

  static Future<void> applyConsent({
    bool umpFailed = false,
    bool? trackingAuthorized,
    bool consentKnown = false,
    bool consentRequired = false,
    bool canRequestAds = false,
  }) async {
    if (trackingAuthorized != null) _trackingAuthorized = trackingAuthorized;
    if (kDebugMode || Firebase.apps.isEmpty) return;
    try {
      final consent = guideAnalyticsConsent(
        umpFailed: umpFailed,
        consentKnown: consentKnown,
        consentRequired: consentRequired,
        canRequestAds: canRequestAds,
        trackingAuthorized: _trackingAuthorized,
      );
      final analytics = FirebaseAnalytics.instance;
      await _consent(analytics, consent);
      await analytics.setAnalyticsCollectionEnabled(consent.analyticsStorage);
      await setCrashCollectionEnabled(consent.analyticsStorage);
    } catch (error) {
      debugPrint('analytics: $error');
    }
  }

  static Future<void> _consent(
    FirebaseAnalytics analytics,
    GuideAnalyticsConsent consent,
  ) {
    return analytics.setConsent(
      analyticsStorageConsentGranted: consent.analyticsStorage,
      adStorageConsentGranted: consent.adStorage,
      adUserDataConsentGranted: consent.adUserData,
      adPersonalizationSignalsConsentGranted: consent.adPersonalization,
    );
  }

  static Future<void> screen(String name) {
    final clean = guideAnalyticsText(name, max: 100);
    if (clean == null) return Future<void>.value();
    return _run((analytics) => analytics.logScreenView(screenName: clean));
  }

  static Future<void> mushroom(String name, {String source = ''}) {
    return _event('select_content', {
      'content_type': 'mushroom',
      'item_id': guideAnalyticsText(name),
      'source': guideAnalyticsText(source, max: 24),
    });
  }

  static Future<void> notificationOpen({
    required String action,
    required bool accepted,
  }) {
    return _event('notification_open', {
      'action': guideAnalyticsText(action, max: 24),
      'accepted': accepted ? 'true' : 'false',
    });
  }

  static Future<void> searchPhoto({
    required String source,
    required String outcome,
    bool counted = false,
  }) {
    return _event('search_photo', {
      'source': guideAnalyticsText(source, max: 24),
      'outcome': guideAnalyticsText(outcome, max: 24),
      if (counted) 'counted': 'true',
    });
  }

  static Future<void> search({required String term, required int resultCount}) {
    final clean = guideAnalyticsText(term);
    if (clean == null) return Future<void>.value();
    return _event('search', {
      'search_term': clean,
      'result_count': resultCount < 0 ? 0 : resultCount,
    });
  }

  static Future<void> filterResult({
    required String under,
    required String where,
    required String color,
    required int count,
  }) {
    return _event('filter_result', {
      'under': guideAnalyticsText(under.isEmpty ? 'any' : under, max: 40),
      'where': guideAnalyticsText(where.isEmpty ? 'any' : where, max: 40),
      'color': guideAnalyticsText(color.isEmpty ? 'any' : color, max: 40),
      'count': count < 0 ? 0 : count,
    });
  }

  static Future<void> language(String tag) {
    return _event('setting', {
      'type': 'preferred_language',
      'language': guideAnalyticsText(tag.isEmpty ? 'default' : tag, max: 36),
    });
  }

  static Future<void> setLanguage(String code) {
    final clean = guideAnalyticsText(code.toLowerCase(), max: 8);
    if (clean == null) return Future<void>.value();
    return _run(
      (analytics) => analytics.setUserProperty(name: 'language', value: clean),
    );
  }

  static Future<void> login(String method, {String? userId}) {
    return _run((analytics) async {
      final id = guideAnalyticsText(userId, max: 256);
      if (id != null) await analytics.setUserId(id: id);
      await analytics.logLogin(loginMethod: method);
    });
  }

  static Future<void> signUp(String method, {String? userId}) {
    return _run((analytics) async {
      final id = guideAnalyticsText(userId, max: 256);
      if (id != null) await analytics.setUserId(id: id);
      await analytics.logSignUp(signUpMethod: method);
    });
  }

  /// A null [userId] clears the id. Null properties clear those properties.
  static Future<void> syncAccount({
    String? userId,
    String? account,
    String? plan,
    String? ads,
  }) {
    return _run((analytics) async {
      await analytics.setUserId(id: guideAnalyticsText(userId, max: 256));
      await analytics.setUserProperty(
        name: 'account',
        value: guideAnalyticsText(account, max: 24),
      );
      await analytics.setUserProperty(
        name: 'plan',
        value: guideAnalyticsText(plan, max: 24),
      );
      await analytics.setUserProperty(
        name: 'ads',
        value: guideAnalyticsText(ads, max: 24),
      );
    });
  }

  static Future<void> purchase(String productId) {
    final id = guideAnalyticsText(productId);
    if (id == null) return Future<void>.value();
    final category = guideAnalyticsProductCategory(id);
    return _run(
      (analytics) => analytics.logPurchase(
        items: [
          AnalyticsEventItem(itemId: id, itemName: id, itemCategory: category),
        ],
        parameters: const {'confirmed': 'true'},
      ),
    );
  }

  static Future<void> purchaseFailed({
    String? productId,
    required String reason,
  }) {
    return _event('purchase_failed', {
      'product_id': guideAnalyticsText(productId),
      'reason': guideAnalyticsText(reason, max: 24),
    });
  }

  static Future<void> offlinePack({
    required String scope,
    required String result,
  }) {
    return _event('offline_pack', {
      'scope': guideAnalyticsText(scope, max: 24),
      'result': guideAnalyticsText(result, max: 24),
    });
  }

  static Future<void> seenSave({required String source, required bool shared}) {
    return _event('seen_save', {
      'source': guideAnalyticsText(source, max: 24),
      'shared': shared ? 'true' : 'false',
    });
  }

  static Future<void> favorite({required bool on}) {
    return _event('favorite', {'action': on ? 'add' : 'remove'});
  }

  static Future<void> viewItem(List<String> productIds) {
    final items = <AnalyticsEventItem>[];
    for (final productId in productIds) {
      final id = guideAnalyticsText(productId);
      if (id == null) continue;
      items.add(
        AnalyticsEventItem(
          itemId: id,
          itemName: id,
          itemCategory: guideAnalyticsProductCategory(id),
        ),
      );
    }
    if (items.isEmpty) return Future<void>.value();
    return _run((analytics) => analytics.logViewItem(items: items));
  }

  static Future<void> adReward({required bool earned}) {
    return _event('ad_reward', {'result': earned ? 'earned' : 'dismissed'});
  }

  static Future<void> _event(String name, Map<String, Object?> parameters) {
    return _run(
      (analytics) =>
          analytics.logEvent(name: name, parameters: _parameters(parameters)),
    );
  }

  static Map<String, Object> _parameters(Map<String, Object?> raw) {
    final out = <String, Object>{};
    raw.forEach((key, value) {
      if (value == null) return;
      if (value is String) {
        final text = guideAnalyticsText(value);
        if (text == null) return;
        out[key] = text;
      } else if (value is num) {
        out[key] = value;
      }
    });
    return out;
  }

  static Future<void> _run(
    Future<void> Function(FirebaseAnalytics analytics) write,
  ) async {
    if (kDebugMode || Firebase.apps.isEmpty) return;
    try {
      await write(FirebaseAnalytics.instance);
    } catch (error) {
      debugPrint('analytics: $error');
    }
  }
}
