import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/person/phone_verify.dart';

void main() {
  test('codeSent does not finish ahead of automatic sign-in', () {
    final gate = PhoneVerifyGate();
    gate.codeSent('verify-1', 4);
    expect(gate.settled, isFalse);
    expect(gate.verificationId, 'verify-1');
    expect(gate.resendToken, 4);

    gate.autoStarted();
    expect(gate.autoTimedOut('verify-1'), isFalse);
    expect(gate.failed(StateError('late')), isFalse);
    expect(gate.settled, isFalse);

    expect(gate.autoFinished(signedIn: true), isTrue);
    expect(gate.signedIn, isTrue);
    expect(gate.settled, isTrue);
    expect(gate.autoTimedOut('other'), isFalse);
    expect(gate.signedIn, isTrue);
  });

  test('auto-retrieval timeout asks for the code', () {
    final gate = PhoneVerifyGate();
    gate.codeSent('verify-2', null);
    expect(gate.autoTimedOut('verify-2'), isTrue);
    expect(gate.settled, isTrue);
    expect(gate.signedIn, isFalse);
    expect(gate.verificationId, 'verify-2');
  });

  test('a failure before sign-in starts is the result', () {
    final gate = PhoneVerifyGate();
    final error = StateError('invalid');
    expect(gate.failed(error), isTrue);
    expect(gate.error, error);
    expect(gate.autoFinished(signedIn: true), isTrue);
  });
}
