import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// A dropped plugin channel or a lost connection is not a bug to file.
bool isIgnorableGuideError(Object error) {
  final text = error.toString();
  if (text.contains('MissingPluginException') && text.contains('method cancel')) {
    return true;
  }
  return text.contains('Failed host lookup') ||
      text.contains('No address associated with hostname') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset') ||
      text.contains('Connection closed') ||
      text.contains('Connection timed out') ||
      text.contains('Software caused connection abort') ||
      text.contains('ClientException') ||
      text.contains('SocketException');
}

bool isIgnorableFlutterError(FlutterErrorDetails details) {
  if (details.library == 'image resource service') return true;
  return isIgnorableGuideError(details.exception);
}

/// Sends [error] when Crashlytics is on. A debug install and a test stay quiet.
void recordGuideError(
  Object error,
  StackTrace? stack, {
  bool fatal = false,
  String? reason,
}) {
  if (Firebase.apps.isEmpty) return;
  try {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      printDetails: false,
      fatal: fatal,
    );
  } catch (reportError) {
    debugPrint('crashlytics: $reportError');
  }
}

/// Collection stays off until this runs, and a debug install turns it off.
///
/// The switch is stored on the phone. Leaving a debug session enabled would
/// keep the next release build from reporting.
Future<void> startCrashReporting() async {
  if (Firebase.apps.isEmpty) return;
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  } catch (error) {
    debugPrint('crashlytics: $error');
  }
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (isIgnorableFlutterError(details)) {
      previous?.call(details);
      return;
    }
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (isIgnorableGuideError(error)) return true;
    recordGuideError(error, stack, fatal: true);
    return true;
  };
}
