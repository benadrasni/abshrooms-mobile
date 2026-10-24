// Generated from the abshrooms-a9d4c Android and iOS apps.
// ignore_for_file: lines_longer_than_80_chars
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('This platform is not configured.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAT6noga69gPCATfFvWLO_kg1WqHI5tzoA',
    appId: '1:968595882184:android:2dd55d5fa4bba8413ca5fd',
    messagingSenderId: '968595882184',
    projectId: 'abshrooms-a9d4c',
    storageBucket: 'abshrooms-a9d4c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDKi3OT6070SsjHGbknKGL7p1aK1FfKe2o',
    appId: '1:968595882184:ios:44188a55ff2c58f93ca5fd',
    messagingSenderId: '968595882184',
    projectId: 'abshrooms-a9d4c',
    storageBucket: 'abshrooms-a9d4c.firebasestorage.app',
    iosBundleId: 'sk.ab.shrooms',
  );
}
