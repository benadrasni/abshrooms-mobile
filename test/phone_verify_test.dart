import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/person/phone_verify.dart';

void main() {
  test('only codeSent arrives when auto-retrieval will not call back', () async {
    final result = await runPhoneVerification(
      phoneNumber: '+421900000000',
      autoRetrieval: false,
      onCredential: (_) async {},
      verify: ({
        required phoneNumber,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
        forceResendingToken,
      }) async {
        codeSent('verify-ios', 3);
      },
    );
    expect(result.signedIn, isFalse);
    expect(result.verificationId, 'verify-ios');
    expect(result.resendToken, 3);
    expect(result.error, isNull);
  });

  test('Android codeSent waits for the auto-retrieval timeout', () async {
    late void Function(String id) timeout;
    final pending = runPhoneVerification(
      phoneNumber: '+421900000000',
      autoRetrieval: true,
      onCredential: (_) async {},
      verify: ({
        required phoneNumber,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
        forceResendingToken,
      }) async {
        timeout = codeAutoRetrievalTimeout;
        codeSent('verify-android', 4);
      },
    );
    var finished = false;
    final result = pending.then((value) {
      finished = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    timeout('verify-android');
    final settled = await result;
    expect(settled.signedIn, isFalse);
    expect(settled.verificationId, 'verify-android');
    expect(settled.resendToken, 4);
    expect(settled.error, isNull);
  });

  test('codeSent is ignored while automatic sign-in is in flight', () async {
    final release = Completer<void>();
    final pending = runPhoneVerification(
      phoneNumber: '+421900000000',
      autoRetrieval: true,
      onCredential: (_) => release.future,
      verify: ({
        required phoneNumber,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
        forceResendingToken,
      }) async {
        verificationCompleted(
          PhoneAuthProvider.credential(
            verificationId: 'auto',
            smsCode: '123456',
          ),
        );
        codeSent('verify-android', 4);
        codeAutoRetrievalTimeout('verify-android');
      },
    );
    var finished = false;
    final result = pending.then((value) {
      finished = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    release.complete();
    final settled = await result;
    expect(settled.signedIn, isTrue);
    expect(settled.error, isNull);
  });

  test('a failure before sign-in starts is the result', () async {
    final error = FirebaseAuthException(code: 'invalid-phone-number');
    final result = await runPhoneVerification(
      phoneNumber: '+421900000000',
      autoRetrieval: true,
      onCredential: (_) async {},
      verify: ({
        required phoneNumber,
        required verificationCompleted,
        required verificationFailed,
        required codeSent,
        required codeAutoRetrievalTimeout,
        forceResendingToken,
      }) async {
        verificationFailed(error);
      },
    );
    expect(result.error, error);
    expect(result.signedIn, isFalse);
  });
}
