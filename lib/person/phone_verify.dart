import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/person/auth.dart';

/// What one phone-verification wait ended with.
class PhoneVerifyResult {
  final bool signedIn;
  final String? verificationId;
  final int? resendToken;
  final Object? error;

  const PhoneVerifyResult({
    required this.signedIn,
    this.verificationId,
    this.resendToken,
    this.error,
  });
}

typedef PhoneVerifyDispatch = Future<void> Function({
  required String phoneNumber,
  required PhoneVerificationCompleted verificationCompleted,
  required PhoneVerificationFailed verificationFailed,
  required PhoneCodeSent codeSent,
  required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  int? forceResendingToken,
});

/// Waits out one phone verification for sign-in and for account deletion.
///
/// iOS never emits [codeAutoRetrievalTimeout], so [codeSent] ends the wait
/// there. Android ignores [codeSent] only while [verificationCompleted] is
/// still signing in, and otherwise ends on the 5-second auto-retrieval
/// timeout already passed to [Auth.verifyPhone].
Future<PhoneVerifyResult> runPhoneVerification({
  required String phoneNumber,
  required Future<void> Function(PhoneAuthCredential credential) onCredential,
  int? forceResendingToken,
  bool? autoRetrieval,
  PhoneVerifyDispatch? verify,
}) async {
  final retrieval =
      autoRetrieval ?? defaultTargetPlatform == TargetPlatform.android;
  final done = Completer<PhoneVerifyResult>();
  var signedIn = false;
  String? verificationId;
  int? resendToken;
  Object? error;
  var inFlight = false;
  var settled = false;

  void finish() {
    if (settled) return;
    settled = true;
    done.complete(
      PhoneVerifyResult(
        signedIn: signedIn,
        verificationId: verificationId,
        resendToken: resendToken,
        error: error,
      ),
    );
  }

  try {
    await (verify ?? Auth.verifyPhone)(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      verificationCompleted: (credential) async {
        if (settled) return;
        inFlight = true;
        try {
          await onCredential(credential);
          signedIn = true;
        } catch (caught) {
          error = caught;
        }
        finish();
      },
      verificationFailed: (caught) {
        if (settled || inFlight) return;
        error = caught;
        finish();
      },
      codeSent: (id, token) {
        verificationId = id;
        resendToken = token;
        if (inFlight || retrieval) return;
        finish();
      },
      codeAutoRetrievalTimeout: (id) {
        if (id.isNotEmpty) verificationId = id;
        if (settled || inFlight) return;
        finish();
      },
    );
  } catch (caught) {
    error = caught;
    finish();
  }
  return done.future;
}
