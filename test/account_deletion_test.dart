import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:whats_that_mushroom/person/account_deletion.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/seen/sighting_storage.dart';

void main() {
  test('a reauth failure is shown and a cancel stays quiet', () {
    expect(
      reauthResultOf(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      DeleteAccountResult.canceled,
    );
    expect(
      reauthResultOf(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
        ),
      ),
      DeleteAccountResult.failed,
    );
    expect(
      reauthResultOf(
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'canceled',
        ),
      ),
      DeleteAccountResult.canceled,
    );
    expect(
      reauthResultOf(StateError('network')),
      DeleteAccountResult.failed,
    );
  });

  test('sign-out starts a guest when the user is gone', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    var signedIn = 0;
    var published = 0;
    Future<void> signIn() async {
      signedIn += 1;
    }

    void notify() {
      published += 1;
    }

    await Auth.startGuest(
      firebaseReady: false,
      signInAnonymously: signIn,
      notify: notify,
    );
    expect(signedIn, 0);
    expect(published, 0);

    await Auth.startGuest(
      firebaseReady: true,
      hasCurrentUser: true,
      signInAnonymously: signIn,
      notify: notify,
    );
    expect(signedIn, 0);
    expect(published, 1);

    await Auth.startGuest(
      firebaseReady: true,
      hasCurrentUser: false,
      signInAnonymously: signIn,
      notify: notify,
    );
    expect(signedIn, 1);
    expect(published, 2);

    await Auth.startGuest(
      firebaseReady: true,
      hasCurrentUser: false,
      signInAnonymously: () async {
        throw StateError('offline');
      },
      notify: notify,
    );
    expect(published, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('guest_created'), isNull);
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
