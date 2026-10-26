import 'package:country_picker/country_picker.dart';

/// What the email form does after Firebase answers.
enum EmailFollowUp {
  signedIn,
  needsVerification,
  tryCreate,
  wrongPassword,
  shortPassword,
  failed,
}

/// A phone-auth failure the form can explain.
enum PhoneFailure { invalidNumber, wrongCode, failed }

enum AccountProvider { google, apple, email, phone }

class AccountView {
  final String? name;
  final String? email;
  final String? phone;
  final AccountProvider? provider;

  const AccountView({this.name, this.email, this.phone, this.provider});
}

class AccountLines {
  final String title;
  final String detail;
  final String initial;
  final bool phoneAvatar;

  const AccountLines({
    required this.title,
    required this.detail,
    required this.initial,
    required this.phoneAvatar,
  });
}

/// A blank or broken address stays on the form. `+` and a long ending such
/// as `.online` are allowed; Firebase still rejects an address it cannot use.
final RegExp _emailPattern = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
  r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
);

bool emailLooksValid(String value) {
  return _emailPattern.hasMatch(value.trim());
}

/// Calling country for a locale. A language with no country, such as `en`
/// or `sk`, does not invent `+1`.
Country? callingCountry(String? countryCode) {
  final code = countryCode?.trim() ?? '';
  if (code.isEmpty) return null;
  try {
    return Country.parse(code);
  } catch (_) {
    return null;
  }
}

/// E.164 number from a calling code and whatever the person typed.
///
/// A national trunk `0`, a typed `00`, and the calling code typed again are
/// not part of the number Firebase dials.
String phoneNumber(String callingCode, String local) {
  final code = callingCode.replaceAll(RegExp(r'\D'), '');
  var digits = local.replaceAll(RegExp(r'\D'), '');
  if (code.isEmpty || digits.isEmpty) return '';
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.startsWith(code) && digits.length > code.length) {
    digits = digits.substring(code.length);
  }
  while (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.isEmpty) return '';
  return '+$code$digits';
}

/// [code] is null when Firebase signed in.
///
/// A missing account and a wrong password can both come back as
/// `invalid-credential`. The form tries to create the account, and create
/// then reports `email-already-in-use` when the password was wrong.
EmailFollowUp emailFollowUp({
  required bool creating,
  String? code,
  bool verified = true,
}) {
  if (code == null) {
    return verified ? EmailFollowUp.signedIn : EmailFollowUp.needsVerification;
  }
  switch (code) {
    case 'user-not-found':
      return creating ? EmailFollowUp.failed : EmailFollowUp.tryCreate;
    case 'invalid-credential':
      return creating ? EmailFollowUp.wrongPassword : EmailFollowUp.tryCreate;
    case 'wrong-password':
    case 'ERROR_WRONG_PASSWORD':
    case 'email-already-in-use':
      return EmailFollowUp.wrongPassword;
    case 'weak-password':
      return EmailFollowUp.shortPassword;
    default:
      return EmailFollowUp.failed;
  }
}

PhoneFailure phoneFailure(String code) {
  switch (code) {
    case 'invalid-phone-number':
    case 'invalidCredential':
      return PhoneFailure.invalidNumber;
    case 'invalid-verification-code':
    case 'ERROR_INVALID_VERIFICATION_CODE':
      return PhoneFailure.wrongCode;
    default:
      return PhoneFailure.failed;
  }
}

String? _filled(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Apple’s private relay, or no address at all. A real Apple email is shown.
bool appleHidesEmail(String? email) {
  final mail = email?.trim().toLowerCase() ?? '';
  return mail.isEmpty || mail.endsWith('@privaterelay.appleid.com');
}

/// First line is the display name, then the email, then the phone number.
/// The second line says how they signed in.
AccountLines accountLines({
  String? name,
  String? email,
  String? phone,
  AccountProvider? provider,
  required String yourAccount,
  required String signedIn,
  required String google,
  required String apple,
  required String emailPassword,
  required String phoneLabel,
  required String appleHidden,
}) {
  final named = _filled(name);
  final mail = _filled(email);
  final number = _filled(phone);
  final hidden = provider == AccountProvider.apple && appleHidesEmail(mail);
  final visibleMail = hidden ? null : mail;

  final String title;
  if (named != null) {
    title = named;
  } else if (visibleMail != null) {
    title = visibleMail;
  } else if (number != null) {
    title = number;
  } else {
    title = yourAccount;
  }

  final phoneAvatar = number != null && title == number;
  final initial = phoneAvatar || title == yourAccount
      ? ''
      : String.fromCharCode(title.runes.first).toUpperCase();

  final String detail;
  if (hidden) {
    detail = number != null && number != title ? '$appleHidden · $number' : appleHidden;
  } else {
    final method = switch (provider) {
      AccountProvider.google => google,
      AccountProvider.apple => apple,
      AccountProvider.email => emailPassword,
      AccountProvider.phone => phoneLabel,
      null => null,
    };
    final parts = <String>[
      if (visibleMail != null && visibleMail != title) visibleMail,
      if (number != null && number != title) number,
      ?method,
    ];
    detail = parts.isEmpty ? signedIn : parts.join(' · ');
  }

  return AccountLines(
    title: title,
    detail: detail,
    initial: initial,
    phoneAvatar: phoneAvatar,
  );
}

AccountProvider? accountProvider(Iterable<String> providerIds) {
  if (providerIds.contains('google.com')) return AccountProvider.google;
  if (providerIds.contains('apple.com')) return AccountProvider.apple;
  if (providerIds.contains('password')) return AccountProvider.email;
  if (providerIds.contains('phone')) return AccountProvider.phone;
  return null;
}

AccountView? accountFrom({
  required bool signedIn,
  String? displayName,
  String? email,
  String? phone,
  Iterable<String> providerIds = const [],
}) {
  if (!signedIn) return null;
  return AccountView(
    name: _filled(displayName),
    email: _filled(email),
    phone: _filled(phone),
    provider: accountProvider(providerIds),
  );
}
