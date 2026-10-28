import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whats_that_mushroom/book/new_page.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/lists/curated_list_page.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/push_message.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

PushNotice noticeFromMessage(RemoteMessage message) {
  return PushNotice.fromData(
    message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );
}

/// Removes the device token from `users/{uid}` before the account is deleted.
///
/// A missing document, or a rules denial while that rule is not published,
/// does not block the deletion. The preferences copy stays, so the next
/// signed-in account on this phone can store the same device token.
Future<void> clearPushToken(String uid) async {
  if (uid.isEmpty) return;
  try {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      pushTokenKey: FieldValue.delete(),
    });
  } on FirebaseException catch (error) {
    if (error.code == 'not-found' || error.code == 'permission-denied') {
      return;
    }
    rethrow;
  }
}

/// Foreground notification. Open continues to the target. Close stays here.
Future<bool> showPushDialog(BuildContext context, PushNotice notice) async {
  final copy = GuideScope.of(context).copy;
  final colors = GuideColors.of(context);
  final heading = (notice.title != null && notice.title!.isNotEmpty)
      ? notice.title!
      : copy.notification;
  final detail =
      (notice.body != null && notice.body!.isNotEmpty && notice.body != heading)
      ? notice.body
      : null;
  final opened = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/app_icon.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      style: TextStyle(fontSize: 14, color: colors.ink2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              copy.notificationOpen,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              copy.notificationClose,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
  return opened == true;
}

/// Permission, the language topic, and the device token. A tap opens the
/// target directly. A message that arrives while the guide is open asks first.
class GuidePush {
  final GlobalKey<NavigatorState> navigatorKey;
  final CatalogRepository catalog;
  String language;

  GuidePush({
    required this.navigatorKey,
    required this.catalog,
    required this.language,
  });

  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  String? _topic;
  String? _token;
  var _started = false;
  var _disposed = false;
  var _topicGeneration = 0;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    Auth.revision.addListener(_onAccount);
    unawaited(setLanguage(language));
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    } catch (error) {
      debugPrint('push permission: $error');
    }
    if (_disposed) return;
    try {
      // register()/onRegistered yields a Firebase Installation ID.
      // The plants sender addresses the FCM registration token.
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      await _persist(token);
    } catch (error) {
      debugPrint('push token: $error');
    }
    if (_disposed) return;
    // ignore: deprecated_member_use
    _refresh = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => unawaited(_persist(token)),
      onError: (Object error) => debugPrint('push token: $error'),
    );
    _foreground = FirebaseMessaging.onMessage.listen(
      (message) => unawaited(_onForeground(message)),
    );
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_openFromTap(message)),
    );
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed) return;
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await _openFromTap(initial);
    } catch (error) {
      debugPrint('push open: $error');
    }
  }

  /// Leaves the previous language topic and joins `notifications-{code}`.
  Future<void> setLanguage(String code) async {
    final next = code.trim().isEmpty ? 'en' : code.trim();
    language = next;
    final topic = 'notifications-$next';
    if (_topic == topic) return;
    final generation = ++_topicGeneration;
    final previous = _topic;
    if (previous != null && previous != topic) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(previous);
      } catch (error) {
        debugPrint('push topic: $error');
      }
    }
    if (_disposed || generation != _topicGeneration) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      if (!_disposed && generation == _topicGeneration) _topic = topic;
    } catch (error) {
      debugPrint('push topic: $error');
    }
  }

  void dispose() {
    _disposed = true;
    Auth.revision.removeListener(_onAccount);
    unawaited(_refresh?.cancel() ?? Future<void>.value());
    unawaited(_foreground?.cancel() ?? Future<void>.value());
    unawaited(_opened?.cancel() ?? Future<void>.value());
  }

  void _onAccount() {
    final token = _token;
    if (token == null || token.isEmpty) return;
    unawaited(_writeUserToken(token));
  }

  Future<void> _persist(String? token) async {
    if (token == null || token.isEmpty || _disposed) return;
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(pushTokenKey, token);
    } catch (error) {
      debugPrint('push token: $error');
    }
    await _writeUserToken(token);
  }

  /// Guests receive the language topic. Only a signed-in account stores the
  /// token. Signing out leaves the stored token in place.
  Future<void> _writeUserToken(String token) async {
    final user = Auth.appUser;
    if (user == null || token.isEmpty || _disposed) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        pushTokenKey: token,
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      debugPrint('push token: $error');
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    if (_disposed) return;
    final notice = noticeFromMessage(message);
    if (notice.action.isEmpty) return;
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final accepted = await showPushDialog(context, notice);
    if (_disposed) return;
    _log(notice.action, accepted);
    if (accepted) await _go(notice);
  }

  Future<void> _openFromTap(RemoteMessage message) async {
    if (_disposed) return;
    final notice = noticeFromMessage(message);
    if (notice.action.isEmpty) return;
    _log(notice.action, true);
    await _go(notice);
  }

  void _log(String action, bool accepted) {
    unawaited(
      GuideAnalytics.notificationOpen(action: action, accepted: accepted),
    );
  }

  Future<void> _go(PushNotice notice) async {
    final destination = pushDestination(notice);
    switch (destination) {
      case PushNowhere():
        return;
      case PushLink(:final uri):
        await _openLink(uri);
      case PushSpecies(:final name):
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        openSpecies(context, name, source: GuideMushroomSource.notification);
      case PushNewInBook():
        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        Navigator.of(context)
            .push(guideRoute(guideScreenNew, (_) => const NewPage()));
      case PushCuratedList(:final id):
        _openList(id);
    }
  }

  void _openList(String id) {
    final data = catalog.data;
    if (data == null) return;
    CuratedListDoc? doc;
    for (final item in catalog.curatedLists.documents) {
      if (item.id == id) {
        doc = item;
        break;
      }
    }
    if (doc == null) return;
    final view = presentCuratedList(doc, data, language);
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final back = GuideScope.of(context).copy.back;
    Navigator.of(context).push(
      guideRoute(
        guideListScreen(view.id),
        (_) => CuratedListPage(list: view, backLabel: back),
      ),
    );
  }

  Future<void> _openLink(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) debugPrint('push link: $uri');
    } catch (error) {
      debugPrint('push link: $error');
    }
  }
}
