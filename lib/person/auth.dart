import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:whats_that_mushroom/person/account.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';

const _guestKey = 'guest_created';

const googleWebClientId =
    '968595882184-rt3pd4sgt9cr8g2qt4j6m7i3396c54bt.apps.googleusercontent.com';
const googleIosClientId =
    '968595882184-5ueoqks0upo9baodegbj2q9o9u7jr0ql.apps.googleusercontent.com';

/// The signed-in account. Anonymous guests are not one. Listen to [revision].
class Auth {
  static FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  static final revision = ValueNotifier<int>(0);
  static User? appUser;

  static User? _signedIn(User? user) =>
      user == null || user.isAnonymous ? null : user;

  /// The anonymous account created at first launch, while no one is signed in.
  static User? get guestUser {
    final user = firebaseAuth.currentUser;
    return user != null && user.isAnonymous ? user : null;
  }

  static void publish() {
    User? user;
    try {
      if (Firebase.apps.isNotEmpty) user = firebaseAuth.currentUser;
    } catch (error) {
      debugPrint('account: $error');
    }
    appUser = _signedIn(user);
    revision.value++;
    syncAnalytics();
  }

  /// The signed-in person, or the guest, and whether Field Guide is on.
  static void syncAnalytics() {
    User? user;
    try {
      if (Firebase.apps.isEmpty) return;
      user = firebaseAuth.currentUser;
    } catch (error) {
      debugPrint('analytics account: $error');
      return;
    }
    final id = signedInAnalyticsId(
      user?.uid,
      anonymous: user == null || user.isAnonymous,
    );
    if (!kDebugMode) {
      unawaited(FirebaseCrashlytics.instance.setUserIdentifier(id ?? ''));
    }
    if (user == null) {
      unawaited(GuideAnalytics.syncAccount());
      return;
    }
    final guide = Purchases.hasFieldGuide();
    unawaited(
      GuideAnalytics.syncAccount(
        userId: id,
        account: user.isAnonymous ? 'guest' : 'signed_in',
        plan: guide ? 'field_guide' : 'free',
        ads: Purchases.showsAds() ? 'shown' : 'hidden',
      ),
    );
  }

  static void _logAuth(UserCredential result, String providerId, bool signUp) {
    final method = guideAnalyticsAuthMethod(providerId);
    final uid = result.user?.uid;
    if (signUp) {
      unawaited(GuideAnalytics.signUp(method, userId: uid));
    } else {
      unawaited(GuideAnalytics.login(method, userId: uid));
    }
  }

  /// A signed-out install needs a guest. [guestCreated] does not matter:
  /// sign-out clears the user and the flag from the first launch would
  /// otherwise leave the phone with no account.
  static bool createGuest({
    required bool firebaseReady,
    required bool hasCurrentUser,
  }) {
    return firebaseReady && !hasCurrentUser;
  }

  /// Creates a guest when nobody is signed in, including after sign-out.
  static Future<void> startGuest() async {
    final ready = Firebase.apps.isNotEmpty;
    final hasUser = ready && firebaseAuth.currentUser != null;
    if (!createGuest(firebaseReady: ready, hasCurrentUser: hasUser)) {
      if (ready) publish();
      return;
    }
    try {
      await firebaseAuth.signInAnonymously();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestKey, true);
      publish();
    } catch (error) {
      debugPrint('guest account: $error');
    }
  }

  /// Links the guest account so its uid carries over. A credential that
  /// already has an account signs in to that account.
  static Future<UserCredential> _linkOrSignIn(AuthCredential credential) async {
    final guest = guestUser;
    if (guest != null) {
      try {
        final linked = await guest.linkWithCredential(credential);
        _logAuth(linked, credential.providerId, true);
        return linked;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use' &&
            error.code != 'email-already-in-use') {
          rethrow;
        }
        final signed = await firebaseAuth.signInWithCredential(
          error.credential ?? credential,
        );
        _logAuth(signed, credential.providerId, false);
        return signed;
      }
    }
    final signed = await firebaseAuth.signInWithCredential(credential);
    _logAuth(signed, credential.providerId, false);
    return signed;
  }

  static Future<void> signInWithCredential(AuthCredential credential) async {
    await _linkOrSignIn(credential);
    publish();
  }

  static Future<User?> signInWithEmail(String email, String password) async {
    final result = await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    _logAuth(result, 'password', false);
    publish();
    return result.user;
  }

  static Future<User?> signUpWithEmail(String email, String password) async {
    final credential = EmailAuthProvider.credential(email: email, password: password);
    final guest = guestUser;
    try {
      final result = guest != null
          ? await guest.linkWithCredential(credential)
          : await firebaseAuth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
      _logAuth(result, 'password', true);
      publish();
      return result.user;
    } on FirebaseAuthException catch (error) {
      if (guest == null ||
          (error.code != 'credential-already-in-use' &&
              error.code != 'email-already-in-use')) {
        rethrow;
      }
    }
    return signInWithEmail(email, password);
  }

  static Future<void> resetPassword(String email) {
    return firebaseAuth.sendPasswordResetEmail(email: email);
  }

  static Future<void> verifyPhone({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) {
    return firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 5),
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
    );
  }

  static Future<void> signOut() async {
    appUser = null;
    if (Firebase.apps.isEmpty) {
      publish();
      return;
    }
    await firebaseAuth.signOut();
    await startGuest();
  }
}

/// Crashlytics and Analytics user id. A guest uid is not one.
String? signedInAnalyticsId(String? uid, {required bool anonymous}) {
  if (anonymous) return null;
  final id = uid?.trim() ?? '';
  return id.isEmpty ? null : id;
}

AccountView? readSignedInAccount() {
  try {
    if (Firebase.apps.isEmpty) return null;
  } catch (_) {
    return null;
  }
  final user = Auth.firebaseAuth.currentUser;
  if (user == null || user.isAnonymous) return null;
  return accountFrom(
    signedIn: true,
    displayName: user.displayName,
    email: user.email,
    phone: user.phoneNumber,
    providerIds: user.providerData.map((info) => info.providerId),
  );
}

Future<void> prepareGoogleSignIn() async {
  try {
    final apple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    await GoogleSignIn.instance.initialize(
      clientId: apple ? googleIosClientId : null,
      serverClientId: googleWebClientId,
    );
  } catch (error) {
    debugPrint('google sign-in: $error');
  }
}

/// Apple sends the person's name only the first time they agree.
Future<({OAuthCredential credential, String name})> appleOAuth() async {
  final rawNonce = createNonce(32);
  final apple = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: sha256ofString(rawNonce),
  );
  final given = apple.givenName?.trim() ?? '';
  final family = apple.familyName?.trim() ?? '';
  return (
    credential: OAuthCredential(
      providerId: 'apple.com',
      signInMethod: 'oauth',
      accessToken: apple.authorizationCode,
      idToken: apple.identityToken,
      rawNonce: rawNonce,
    ),
    name: [given, family].where((part) => part.isNotEmpty).join(' '),
  );
}

String sha256ofString(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}

String createNonce(int length) {
  final random = Random.secure();
  final codes = List<int>.generate(length, (_) {
    switch (random.nextInt(3)) {
      case 0:
        return random.nextInt(10) + 48;
      case 1:
        return random.nextInt(26) + 65;
      default:
        return random.nextInt(26) + 97;
    }
  });
  return String.fromCharCodes(codes);
}
