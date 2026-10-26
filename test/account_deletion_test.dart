import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:whats_that_mushroom/person/account_deletion.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/seen/sighting_storage.dart';

void main() {
  test('a reauth failure is shown and a cancel stays quiet', () {
    expect(
      deleteAccountResultForReauth(
        reauthResultOf(
          const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        ),
      ),
      DeleteAccountResult.canceled,
    );
    expect(
      deleteAccountResultForReauth(
        reauthResultOf(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
          ),
        ),
      ),
      DeleteAccountResult.failed,
    );
    expect(
      deleteAccountResultForReauth(
        reauthResultOf(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'canceled',
          ),
        ),
      ),
      DeleteAccountResult.canceled,
    );
    expect(
      deleteAccountResultForReauth(reauthResultOf(StateError('network'))),
      DeleteAccountResult.failed,
    );
  });

  test('sign-out starts a guest when the user is gone', () {
    expect(
      Auth.createGuest(firebaseReady: true, hasCurrentUser: false),
      isTrue,
    );
    expect(
      Auth.createGuest(firebaseReady: true, hasCurrentUser: true),
      isFalse,
    );
    expect(
      Auth.createGuest(firebaseReady: false, hasCurrentUser: false),
      isFalse,
    );
  });

  test('a guest uid is not an analytics id', () {
    expect(signedInAnalyticsId('guest-1', anonymous: true), isNull);
    expect(signedInAnalyticsId('user-1', anonymous: false), 'user-1');
    expect(signedInAnalyticsId('  ', anonymous: false), isNull);
  });

  test('account deletion removes that uid’s sighting objects', () {
    expect(
      sightingObjectPaths('ada', [
        (id: 'one', photo: 'sightings/ada/one.jpg'),
        (id: 'two', photo: 'sightings/ada/custom.jpg'),
        (id: 'three', photo: 'sightings/other/three.jpg'),
      ]),
      [
        'sightings/ada/custom.jpg',
        'sightings/ada/one.jpg',
        'sightings/ada/three.jpg',
        'sightings/ada/two.jpg',
      ],
    );
  });
}
