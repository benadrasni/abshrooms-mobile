import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/legal.dart';
import 'package:whats_that_mushroom/person/account.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

const signInPlatePath =
    'photos/Agaricales/Amanitaceae/Amanita_muscaria/Amanita_muscaria@1600.webp';

enum _Step { providers, email, phone, code }

enum _Busy { apple, google, email, reset, phone, code }

/// Apple, Google, email, and phone. Email and phone stay on this page.
class SignInPage extends StatefulWidget {
  final bool? showApple;
  final Country? initialCountry;
  final WidgetBuilder? plate;
  final Future<void> Function()? onApple;
  final Future<void> Function()? onGoogle;
  final Future<EmailFollowUp> Function(String email, String password)? onEmail;
  final Future<void> Function(String email)? onResetPassword;
  final Future<void> Function(String phone)? onSendCode;
  final Future<void> Function(String code)? onConfirmCode;

  const SignInPage({
    super.key,
    this.showApple,
    this.initialCountry,
    this.plate,
    this.onApple,
    this.onGoogle,
    this.onEmail,
    this.onResetPassword,
    this.onSendCode,
    this.onConfirmCode,
  });

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();

  _Step _step = _Step.providers;
  _Busy? _busy;
  String? _error;
  String? _sentTo;
  String? _verificationId;
  int? _resendToken;
  Country? _country;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _showApple => widget.showApple ?? defaultTargetPlatform == TargetPlatform.iOS;

  void _leave() {
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _retreat() {
    setState(() {
      _error = null;
      _busy = null;
      _step = _step == _Step.code ? _Step.phone : _Step.providers;
    });
  }

  void _show(_Step step) {
    setState(() {
      _error = null;
      _step = step;
    });
  }

  Future<void> _run(_Busy busy, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() {
      _busy = busy;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      debugPrint('sign-in: $error');
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String _messageFor(Object error) {
    final copy = GuideScope.of(context).copy;
    if (error is FirebaseAuthException) {
      switch (phoneFailure(error.code)) {
        case PhoneFailure.invalidNumber:
          return copy.invalidPhone;
        case PhoneFailure.wrongCode:
          return copy.wrongCode;
        case PhoneFailure.failed:
          return copy.signInFailed;
      }
    }
    return copy.signInFailed;
  }

  Future<void> _apple() {
    return _run(_Busy.apple, () async {
      final custom = widget.onApple;
      if (custom != null) {
        await custom();
        _leave();
        return;
      }
      try {
        final apple = await appleOAuth();
        await Auth.signInWithCredential(apple.credential);
        if (apple.name.isNotEmpty) {
          await Auth.firebaseAuth.currentUser?.updateDisplayName(apple.name);
          Auth.publish();
        }
        _leave();
      } on SignInWithAppleAuthorizationException catch (error) {
        if (error.code == AuthorizationErrorCode.canceled) return;
        rethrow;
      }
    });
  }

  Future<void> _google() {
    return _run(_Busy.google, () async {
      final custom = widget.onGoogle;
      if (custom != null) {
        await custom();
        _leave();
        return;
      }
      try {
        await prepareGoogleSignIn();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null) return;
        await Auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
        _leave();
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) return;
        rethrow;
      }
    });
  }

  Future<void> _submitEmail() async {
    final copy = GuideScope.of(context).copy;
    final email = _email.text.trim();
    final password = _password.text;
    if (!emailLooksValid(email)) {
      setState(() => _error = copy.invalidEmail);
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = copy.emptyPassword);
      return;
    }
    if (password.length < 6) {
      setState(() => _error = copy.signInShortPassword);
      return;
    }
    EmailFollowUp? follow;
    await _run(_Busy.email, () async {
      follow = widget.onEmail == null
          ? await signInWithEmail(email, password)
          : await widget.onEmail!(email, password);
    });
    if (!mounted || follow == null) return;
    switch (follow!) {
      case EmailFollowUp.signedIn:
        _leave();
      case EmailFollowUp.needsVerification:
        await _showVerify();
        if (widget.onEmail == null && mounted) await Auth.signOut();
      case EmailFollowUp.wrongPassword:
        setState(() => _error = copy.signInWrongPassword);
      case EmailFollowUp.shortPassword:
        setState(() => _error = copy.signInShortPassword);
      case EmailFollowUp.tryCreate:
      case EmailFollowUp.failed:
        setState(() => _error = copy.signInFailed);
    }
  }

  Future<void> _reset() async {
    final copy = GuideScope.of(context).copy;
    final email = _email.text.trim();
    if (!emailLooksValid(email)) {
      setState(() => _error = copy.invalidEmail);
      return;
    }
    var sent = false;
    await _run(_Busy.reset, () async {
      final custom = widget.onResetPassword;
      if (custom != null) {
        await custom(email);
      } else {
        await Auth.resetPassword(email);
      }
      sent = true;
    });
    if (sent && mounted) await _showReset(email);
  }

  Future<void> _submitPhone() async {
    final copy = GuideScope.of(context).copy;
    final phone = phoneNumber(_selectedCountry(context).phoneCode, _phone.text);
    if (phone.isEmpty) {
      setState(() => _error = copy.invalidPhone);
      return;
    }
    await _run(_Busy.phone, () async {
      if (!await _send(phone)) return;
      if (!mounted) return;
      setState(() {
        _sentTo = phone;
        _code.clear();
        _step = _Step.code;
      });
    });
  }

  Future<void> _resend() async {
    final phone = _sentTo;
    if (phone == null || phone.isEmpty) return;
    await _run(_Busy.phone, () async {
      await _send(phone, resend: true);
    });
  }

  /// Sends the code. Returns false when the phone itself signed in.
  Future<bool> _send(String phone, {bool resend = false}) async {
    final custom = widget.onSendCode;
    if (custom != null) {
      await custom(phone);
      return true;
    }
    final signedIn = await _verifyPhone(phone, resend: resend);
    if (signedIn) {
      _leave();
      return false;
    }
    return true;
  }

  Future<void> _submitCode() async {
    final copy = GuideScope.of(context).copy;
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = copy.invalidCode);
      return;
    }
    await _run(_Busy.code, () async {
      final custom = widget.onConfirmCode;
      if (custom != null) {
        await custom(code);
      } else {
        final verificationId = _verificationId;
        if (verificationId == null) {
          throw FirebaseAuthException(code: 'session-expired');
        }
        await Auth.signInWithCredential(
          PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code),
        );
      }
      _leave();
    });
  }

  Future<bool> _verifyPhone(String phone, {bool resend = false}) async {
    final done = Completer<void>();
    var signedIn = false;
    await Auth.verifyPhone(
      phoneNumber: phone,
      forceResendingToken: resend ? _resendToken : null,
      verificationCompleted: (credential) async {
        try {
          await Auth.signInWithCredential(credential);
          signedIn = true;
          if (!done.isCompleted) done.complete();
        } catch (error) {
          if (!done.isCompleted) done.completeError(error);
        }
      },
      verificationFailed: (error) {
        if (!done.isCompleted) done.completeError(error);
      },
      codeSent: (verificationId, token) {
        _verificationId = verificationId;
        _resendToken = token;
        if (!done.isCompleted) done.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 60));
    return signedIn;
  }

  Future<void> _showVerify() {
    final copy = GuideScope.of(context).copy;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(copy.verifyEmailTitle),
          content: Text(copy.verifyEmailMessage),
          actions: [
            TextButton(
              onPressed: () {
                if (widget.onEmail == null) {
                  Auth.firebaseAuth.currentUser?.sendEmailVerification();
                }
                Navigator.of(dialogContext).pop();
              },
              child: Text(copy.resendEmail),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(copy.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReset(String email) {
    final copy = GuideScope.of(context).copy;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(copy.resetPasswordTitle),
          content: Text(copy.resetPasswordMessage(email)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(copy.close),
            ),
          ],
        );
      },
    );
  }

  Country _selectedCountry(BuildContext context) {
    final chosen = _country ?? widget.initialCountry;
    if (chosen != null) return chosen;
    final code = Localizations.localeOf(context).countryCode;
    if (code != null && code.isNotEmpty) {
      try {
        return Country.parse(code);
      } catch (_) {}
    }
    return Country.parse('US');
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CallingCodeSheet(),
    );
    if (!mounted || selected == null) return;
    setState(() => _country = selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return PopScope(
      canPop: _step == _Step.providers,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _retreat();
      },
      child: Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          bottom: false,
          child: _step == _Step.providers ? _providers(context) : _form(context),
        ),
      ),
    );
  }

  Widget _providers(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.only(bottom: bottom),
      children: [
        SizedBox(
          height: 206,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 236,
                child: IgnorePointer(child: _Hero(plate: widget.plate)),
              ),
              PositionedDirectional(
                top: 10,
                end: 12,
                child: _CloseButton(
                  label: copy.signInNotNow,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(
            copy.signIn,
            style: TextStyle(
              fontFamily: GuideType.display,
              fontWeight: FontWeight.w500,
              fontSize: 34,
              letterSpacing: -0.68,
              height: 1.05,
              color: colors.ink,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            copy.signInFree,
            style: TextStyle(
              fontFamily: GuideType.sans,
              color: colors.ink2,
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Column(
            children: [
              _Perk(title: copy.signInPerkAccount, note: copy.signInPerkAccountNote),
              _Perk(title: copy.signInPerkHere, note: copy.signInPerkHereNote),
              _Perk(title: copy.signInPerkOut, note: copy.signInPerkOutNote),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showApple) ...[
                _ProviderButton(
                  label: copy.signInApple,
                  icon: _AppleMark(dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF)),
                  background: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
                  foreground: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                  spinning: _busy == _Busy.apple,
                  onPressed: _busy == null ? () => unawaited(_apple()) : null,
                ),
                const SizedBox(height: 10),
              ],
              _ProviderButton(
                label: copy.signInGoogle,
                icon: Image.asset('assets/go-logo.png', width: 20, height: 20),
                background: dark ? const Color(0xFF131314) : const Color(0xFFFFFFFF),
                foreground: dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
                border: dark ? const Color(0xFF8E918F) : const Color(0xFF747775),
                spinning: _busy == _Busy.google,
                onPressed: _busy == null ? () => unawaited(_google()) : null,
              ),
              _OrRule(label: copy.signInOr),
              Row(
                children: [
                  Expanded(
                    child: _ProviderButton(
                      label: copy.signInEmail,
                      icon: Icon(Icons.mail_outline, size: 20, color: colors.ink2),
                      background: colors.cream,
                      foreground: colors.ink,
                      border: colors.rule,
                      fontSize: 15,
                      iconStart: 16,
                      onPressed: _busy == null ? () => _show(_Step.email) : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProviderButton(
                      label: copy.signInPhone,
                      icon: Icon(Icons.smartphone_outlined, size: 20, color: colors.ink2),
                      background: colors.cream,
                      foreground: colors.ink,
                      border: colors.rule,
                      fontSize: 15,
                      iconStart: 16,
                      onPressed: _busy == null ? () => _show(_Step.phone) : null,
                    ),
                  ),
                ],
              ),
              if (_error != null) _ErrorText(_error!),
              _SignInLegal(copy: copy, colors: colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;
    final codeStep = _step == _Step.code;
    return ListView(
      padding: EdgeInsets.only(bottom: bottom),
      children: [
        _FormBack(
          label: codeStep ? copy.back : copy.signIn,
          onPressed: _retreat,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_formTitle(copy), style: GuideType.question(colors)),
              const SizedBox(height: 4),
              Text(
                _formNote(copy),
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  color: colors.ink2,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              ..._formFields(context, copy, colors),
              const SizedBox(height: 6),
              _PrimaryButton(
                label: _primaryLabel(copy),
                spinning: _busy == _Busy.email ||
                    (_step == _Step.phone && _busy == _Busy.phone) ||
                    _busy == _Busy.code,
                onPressed: _busy == null ? _primary() : null,
              ),
              if (_step == _Step.email)
                _MossButton(
                  label: copy.signInForgot,
                  onPressed: _busy == null ? () => unawaited(_reset()) : null,
                ),
              if (codeStep)
                _MossButton(
                  label: copy.signInResend,
                  onPressed: _busy == null ? () => unawaited(_resend()) : null,
                ),
              if (_error != null) _ErrorText(_error!),
            ],
          ),
        ),
      ],
    );
  }

  String _formTitle(Copy copy) {
    switch (_step) {
      case _Step.email:
        return copy.signInEmailTitle;
      case _Step.phone:
        return copy.signInPhoneTitle;
      case _Step.code:
        return copy.signInCode;
      case _Step.providers:
        return copy.signIn;
    }
  }

  String _formNote(Copy copy) {
    switch (_step) {
      case _Step.email:
        return copy.signInEmailNew;
      case _Step.phone:
        return copy.signInPhoneNote;
      case _Step.code:
        return copy.signInCodeNote(_sentTo ?? '');
      case _Step.providers:
        return copy.signInFree;
    }
  }

  String _primaryLabel(Copy copy) {
    switch (_step) {
      case _Step.phone:
        return copy.signInSendCode;
      case _Step.email:
      case _Step.code:
      case _Step.providers:
        return copy.signInContinue;
    }
  }

  VoidCallback _primary() {
    switch (_step) {
      case _Step.email:
        return () => unawaited(_submitEmail());
      case _Step.phone:
        return () => unawaited(_submitPhone());
      case _Step.code:
        return () => unawaited(_submitCode());
      case _Step.providers:
        return () {};
    }
  }

  List<Widget> _formFields(BuildContext context, Copy copy, GuideColors colors) {
    switch (_step) {
      case _Step.email:
        return [
          _Field(
            fieldKey: const Key('guideSignInEmail'),
            controller: _email,
            hint: copy.emailHint,
            keyboard: TextInputType.emailAddress,
            autofill: const [AutofillHints.email],
          ),
          _Field(
            fieldKey: const Key('guideSignInPassword'),
            controller: _password,
            hint: copy.passwordHint,
            obscure: true,
            autofill: const [AutofillHints.password],
          ),
        ];
      case _Step.phone:
        final country = _selectedCountry(context);
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _CallingCode(
                  code: '+${country.phoneCode}',
                  onPressed: _pickCountry,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    fieldKey: const Key('guideSignInPhone'),
                    controller: _phone,
                    hint: copy.phoneHint,
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    autofill: const [AutofillHints.telephoneNumber],
                    gap: false,
                  ),
                ),
              ],
            ),
          ),
        ];
      case _Step.code:
        return [
          _Field(
            fieldKey: const Key('guideSignInCode'),
            controller: _code,
            hint: copy.codeHint,
            keyboard: TextInputType.number,
            autofill: const [AutofillHints.oneTimeCode],
            maxLength: 6,
          ),
        ];
      case _Step.providers:
        return const [];
    }
  }
}

/// Signs in, or creates the account when Firebase has no user for this email.
Future<EmailFollowUp> signInWithEmail(String email, String password) async {
  User? existing;
  try {
    existing = await Auth.signInWithEmail(email, password);
  } on FirebaseAuthException catch (error) {
    final next = emailFollowUp(creating: false, code: error.code);
    if (next != EmailFollowUp.tryCreate) return next;
  } catch (error) {
    debugPrint('sign-in: $error');
    return EmailFollowUp.failed;
  }
  if (existing != null) {
    if (existing.emailVerified) return EmailFollowUp.signedIn;
    try {
      await existing.sendEmailVerification();
    } catch (error) {
      debugPrint('sign-in: $error');
    }
    return EmailFollowUp.needsVerification;
  }
  try {
    final user = await Auth.signUpWithEmail(email, password);
    if (user == null) return EmailFollowUp.failed;
    await user.sendEmailVerification();
    return EmailFollowUp.needsVerification;
  } on FirebaseAuthException catch (error) {
    final next = emailFollowUp(creating: true, code: error.code);
    if (next == EmailFollowUp.tryCreate) return EmailFollowUp.failed;
    return next;
  } catch (error) {
    debugPrint('sign-in: $error');
    return EmailFollowUp.failed;
  }
}

class _Hero extends StatelessWidget {
  final WidgetBuilder? plate;

  const _Hero({this.plate});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.plateWell),
          plate?.call(context) ?? const _Plate(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.paper.withValues(alpha: 0),
                  colors.paper.withValues(alpha: 0),
                  colors.paper,
                ],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate();

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final placeholder = ColoredBox(color: colors.plateWell);
    return CachedNetworkImage(
      imageUrl: mediaUrl(signInPlatePath),
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.2),
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) => placeholder,
    );
  }
}

class _CloseButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _CloseButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: colors.cream,
          shape: CircleBorder(side: BorderSide(color: colors.rule)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(Icons.close, size: 20, color: colors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormBack extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _FormBack({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: IconTheme(
          data: IconThemeData(color: colors.moss, size: 20),
          child: const BackButtonIcon(),
        ),
        label: Text(label),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  final String title;
  final String note;

  const _Perk({required this.title, required this.note});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check, size: 18, color: colors.moss),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                Text(
                  note,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    color: colors.ink2,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final double fontSize;
  final double iconStart;
  final VoidCallback? onPressed;
  final bool spinning;

  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.border,
    this.fontSize = 16,
    this.iconStart = 20,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: StadiumBorder(
        side: border == null ? BorderSide.none : BorderSide(color: border!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: spinning ? null : onPressed,
        child: SizedBox(
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: spinning
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                      )
                    : Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          color: foreground,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
              ),
              if (!spinning) PositionedDirectional(start: iconStart, child: icon),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrRule extends StatelessWidget {
  final String label;

  const _OrRule({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        children: [
          Expanded(child: DecoratedBox(decoration: BoxDecoration(color: colors.rule), child: const SizedBox(height: 1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(fontFamily: GuideType.sans, fontSize: 13, color: colors.ink2),
            ),
          ),
          Expanded(child: DecoratedBox(decoration: BoxDecoration(color: colors.rule), child: const SizedBox(height: 1))),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool spinning;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final enabled = onPressed != null;
    return Material(
      color: enabled || spinning ? colors.moss : colors.paper2,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: spinning ? null : onPressed,
        child: SizedBox(
          height: 44,
          child: Center(
            child: spinning
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.onMoss),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      color: enabled ? colors.onMoss : colors.ink2,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MossButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _MossButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: GuideColors.of(context).moss,
        minimumSize: const Size.fromHeight(44),
        textStyle: const TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

class _Field extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final bool obscure;
  final List<String>? autofill;
  final int? maxLength;
  final bool gap;

  const _Field({
    required this.controller,
    required this.hint,
    this.fieldKey,
    this.keyboard,
    this.formatters,
    this.obscure = false,
    this.autofill,
    this.maxLength,
    this.gap = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.rule),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: gap ? 10 : 0),
      child: SizedBox(
        height: 48,
        child: TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: formatters,
          obscureText: obscure,
          autofillHints: autofill,
          maxLength: maxLength,
          autocorrect: false,
          enableSuggestions: !obscure,
          cursorColor: colors.moss,
          style: TextStyle(fontFamily: GuideType.sans, color: colors.ink, fontSize: 16),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: GuideType.sans, color: colors.ink2, fontSize: 16),
            filled: true,
            fillColor: colors.cream,
            isDense: false,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.moss, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallingCode extends StatelessWidget {
  final String code;
  final VoidCallback onPressed;

  const _CallingCode({required this.code, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Material(
      color: colors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('guideSignInCallingCode'),
        onTap: onPressed,
        child: SizedBox(
          width: 88,
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                code,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontFamily: GuideType.sans, color: colors.ink, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInLegal extends StatelessWidget {
  final Copy copy;
  final GuideColors colors;

  const _SignInLegal({required this.copy, required this.colors});

  @override
  Widget build(BuildContext context) {
    final terms = copy.termsOfUse;
    final privacy = copy.privacyPolicy;
    final sentence = copy.signInLegal(terms, privacy);
    final body = TextStyle(
      fontFamily: GuideType.sans,
      fontSize: 12,
      height: 1.45,
      color: colors.ink3,
    );
    final link = body.copyWith(
      color: colors.moss,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: colors.moss,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text.rich(
        TextSpan(style: body, children: _spans(sentence, terms, privacy, link)),
        textAlign: TextAlign.center,
      ),
    );
  }

  List<InlineSpan> _spans(
    String sentence,
    String terms,
    String privacy,
    TextStyle link,
  ) {
    final termsAt = sentence.indexOf(terms);
    final privacyAt = sentence.indexOf(privacy);
    if (termsAt < 0 || privacyAt < 0) return [TextSpan(text: sentence)];
    final marks = <(int, String, String)>[
      (termsAt, terms, termsOfUseUrl),
      (privacyAt, privacy, privacyPolicyUrl),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final mark in marks) {
      if (mark.$1 > cursor) {
        spans.add(TextSpan(text: sentence.substring(cursor, mark.$1)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => openLegal(mark.$3),
            child: Text(mark.$2, style: link),
          ),
        ),
      );
      cursor = mark.$1 + mark.$2.length;
    }
    if (cursor < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(cursor)));
    }
    return spans;
  }
}

class _ErrorText extends StatelessWidget {
  final String text;

  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: GuideType.sans,
          color: GuideColors.of(context).madder,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }
}

class _AppleMark extends StatelessWidget {
  final Color color;

  const _AppleMark(this.color);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 20), painter: _ApplePainter(color));
  }
}

class _ApplePainter extends CustomPainter {
  final Color color;

  _ApplePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(_body(), paint);
    canvas.drawPath(_leaf(), paint);
  }

  Path _body() {
    return Path()
      ..moveTo(16.4, 12.6)
      ..relativeCubicTo(0, -2.5, 2, -3.6, 2.1, -3.7)
      ..relativeCubicTo(-1.2, -1.7, -3, -1.9, -3.6, -2)
      ..relativeCubicTo(-1.5, -0.2, -3, 0.9, -3.8, 0.9)
      ..relativeCubicTo(-0.8, 0, -2, -0.9, -3.3, -0.8)
      ..relativeCubicTo(-1.7, 0, -3.3, 1, -4.1, 2.5)
      ..relativeCubicTo(-1.8, 3.1, -0.5, 7.6, 1.3, 10.1)
      ..relativeCubicTo(0.8, 1.2, 1.8, 2.6, 3.1, 2.5)
      ..relativeCubicTo(1.3, 0, 1.7, -0.8, 3.3, -0.8)
      ..relativeCubicTo(1.5, 0, 1.9, 0.8, 3.3, 0.8)
      ..relativeCubicTo(1.4, 0, 2.2, -1.2, 3, -2.5)
      ..relativeCubicTo(1, -1.4, 1.3, -2.7, 1.4, -2.8)
      ..relativeCubicTo(-0.1, 0, -2.7, -1, -2.7, -4.2)
      ..close();
  }

  Path _leaf() {
    return Path()
      ..moveTo(13.9, 5.2)
      ..relativeCubicTo(0.7, -0.8, 1.2, -2, 1, -3.2)
      ..relativeCubicTo(-1, 0, -2.2, 0.7, -3, 1.5)
      ..relativeCubicTo(-0.6, 0.7, -1.2, 1.9, -1, 3.1)
      ..relativeCubicTo(1.1, 0.1, 2.3, -0.6, 3, -1.4)
      ..close();
  }

  @override
  bool shouldRepaint(_ApplePainter oldDelegate) => oldDelegate.color != color;
}

class _CallingCodeSheet extends StatefulWidget {
  const _CallingCodeSheet();

  @override
  State<_CallingCodeSheet> createState() => _CallingCodeSheetState();
}

class _CallingCodeSheetState extends State<_CallingCodeSheet> {
  final TextEditingController _query = TextEditingController();
  final List<Country> _all = CountryService().getAll();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final query = _query.text.trim().toLowerCase();
    final countries = _all.where((country) {
      if (query.isEmpty) return true;
      return country.name.toLowerCase().contains(query) ||
          country.phoneCode.contains(query.replaceAll('+', '')) ||
          country.countryCode.toLowerCase().contains(query);
    }).toList();
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  cursorColor: colors.moss,
                  style: TextStyle(fontFamily: GuideType.sans, color: colors.ink),
                  decoration: InputDecoration(
                    hintText: GuideScope.of(context).copy.signInCountry,
                    filled: true,
                    fillColor: colors.cream,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: countries.length,
                  itemBuilder: (context, index) {
                    final country = countries[index];
                    return ListTile(
                      title: Text(
                        country.name,
                        style: TextStyle(fontFamily: GuideType.sans, color: colors.ink),
                      ),
                      trailing: Text(
                        '+${country.phoneCode}',
                        style: TextStyle(fontFamily: GuideType.sans, color: colors.ink2),
                      ),
                      onTap: () => Navigator.of(context).pop(country),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
