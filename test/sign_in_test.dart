import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/person/account.dart';
import 'package:whats_that_mushroom/person/sign_in_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  test(
    'email follow-up creates a missing account and keeps a wrong password',
    () {
      expect(emailLooksValid('ada@example.com'), isTrue);
      expect(emailLooksValid('ada+mushroom@gmail.com'), isTrue);
      expect(emailLooksValid('ada@example.online'), isTrue);
      expect(emailLooksValid('ada'), isFalse);
      expect(emailLooksValid('ada@example'), isFalse);
      expect(
        emailFollowUp(creating: false, code: null),
        EmailFollowUp.signedIn,
      );
      expect(
        emailFollowUp(creating: false, code: null, verified: false),
        EmailFollowUp.needsVerification,
      );
      expect(
        emailFollowUp(creating: false, code: 'user-not-found'),
        EmailFollowUp.tryCreate,
      );
      expect(
        emailFollowUp(creating: false, code: 'invalid-credential'),
        EmailFollowUp.tryCreate,
      );
      expect(
        emailFollowUp(creating: true, code: 'email-already-in-use'),
        EmailFollowUp.wrongPassword,
      );
      expect(
        emailFollowUp(creating: true, code: 'invalid-credential'),
        EmailFollowUp.wrongPassword,
      );
      expect(
        emailFollowUp(creating: true, code: 'weak-password'),
        EmailFollowUp.shortPassword,
      );
      expect(phoneNumber('421', '905 123 456'), '+421905123456');
      expect(phoneNumber('421', '0905 123 456'), '+421905123456');
      expect(phoneNumber('421', '+421 905 123 456'), '+421905123456');
      expect(phoneNumber('421', '00421905123456'), '+421905123456');
      expect(phoneNumber('421', '   '), '');
      expect(callingCountry(null), isNull);
      expect(callingCountry(''), isNull);
      expect(callingCountry('SK')?.phoneCode, '421');
      expect(callingCountry('not-a-country'), isNull);
      expect(phoneFailure('invalid-phone-number'), PhoneFailure.invalidNumber);
      expect(phoneFailure('invalid-verification-code'), PhoneFailure.wrongCode);
    },
  );

  test('the account line names the person and how they signed in', () {
    final google = accountLines(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      provider: AccountProvider.google,
      yourAccount: 'Your account',
      signedIn: 'Signed in',
      google: 'Google',
      apple: 'Apple',
      emailPassword: 'Email and password',
      phoneLabel: 'Phone',
      appleHidden: 'Email hidden by Apple',
    );
    expect(google.title, 'Ada Lovelace');
    expect(google.detail, 'ada@example.com · Google');
    expect(google.initial, 'A');

    final hidden = accountLines(
      email: 'hide@privaterelay.appleid.com',
      provider: AccountProvider.apple,
      yourAccount: 'Your account',
      signedIn: 'Signed in',
      google: 'Google',
      apple: 'Apple',
      emailPassword: 'Email and password',
      phoneLabel: 'Phone',
      appleHidden: 'Email hidden by Apple',
    );
    expect(hidden.title, 'Your account');
    expect(hidden.detail, 'Email hidden by Apple');

    final phone = accountLines(
      phone: '+421905123456',
      provider: AccountProvider.phone,
      yourAccount: 'Your account',
      signedIn: 'Signed in',
      google: 'Google',
      apple: 'Apple',
      emailPassword: 'Email and password',
      phoneLabel: 'Phone',
      appleHidden: 'Email hidden by Apple',
    );
    expect(phone.title, '+421905123456');
    expect(phone.phoneAvatar, isTrue);
    expect(phone.detail, 'Phone');
  });

  testWidgets('Sign in offers the four ways in', (tester) async {
    await _open(tester, const SignInPage(showApple: true, plate: _plate));
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      find.text('The key and the book stay free without an account.'),
      findsOneWidget,
    );
    expect(find.text('One account'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.byKey(const Key('plate')), findsOneWidget);
  });

  testWidgets('apple is hidden when this phone cannot use it', (tester) async {
    await _open(tester, const SignInPage(showApple: false, plate: _plate));
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('a short password stays on the email form', (tester) async {
    await _open(tester, const SignInPage(showApple: true, plate: _plate));
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('guideSignInEmail')),
      'ada@example.com',
    );
    await tester.enterText(find.byKey(const Key('guideSignInPassword')), 'no');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Use at least 6 characters.'), findsOneWidget);
  });

  testWidgets('phone sends a code and the code signs in', (tester) async {
    final sent = <String>[];
    final codes = <String>[];
    await _open(
      tester,
      SignInPage(
        showApple: false,
        plate: _plate,
        initialCountry: Country.parse('SK'),
        onSendCode: (phone) async => sent.add(phone),
        onConfirmCode: (code) async => codes.add(code),
      ),
    );
    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    expect(find.text('+421'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('guideSignInPhone')),
      '0905123456',
    );
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(sent, ['+421905123456']);
    await tester.enterText(find.byKey(const Key('guideSignInCode')), '123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(codes, ['123456']);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('phone does not assume +1 when the locale has no country', (
    tester,
  ) async {
    await _open(
      tester,
      const SignInPage(showApple: false, plate: _plate),
      locale: const Locale('en'),
    );
    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    expect(find.text('+1'), findsNothing);
    expect(find.text('+'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('guideSignInPhone')),
      '905123456',
    );
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('Enter a valid phone number'), findsOneWidget);
  });
}

Widget _plate(BuildContext context) => const SizedBox.shrink(key: Key('plate'));

Future<void> _open(WidgetTester tester, Widget page, {Locale? locale}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    GuideScope(
      catalog: CatalogRepository(),
      notebook: Notebook(),
      settings: GuideSettings(),
      reload: () async {},
      selectTab: (_) {},
      child: MaterialApp(
        theme: guideTheme(Brightness.light),
        locale: locale ?? const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('sk')],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => page));
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
