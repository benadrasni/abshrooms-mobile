import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/person/phone_verify.dart';
import 'package:whats_that_mushroom/purchase/store_proof.dart';
import 'package:whats_that_mushroom/seen/publish.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

enum DeleteAccountResult { success, canceled, failed }

enum ReauthResult { success, canceled, failed }

/// A dismissed sheet stays [ReauthResult.canceled]. Any other failure is
/// [ReauthResult.failed] so the account screen can say the deletion did not
/// happen.
ReauthResult reauthResultOf(Object error) {
  if (error is GoogleSignInException &&
      error.code == GoogleSignInExceptionCode.canceled) {
    return ReauthResult.canceled;
  }
  if (error is SignInWithAppleAuthorizationException &&
      error.code == AuthorizationErrorCode.canceled) {
    return ReauthResult.canceled;
  }
  return ReauthResult.failed;
}

DeleteAccountResult deleteAccountResultForReauth(ReauthResult result) {
  switch (result) {
    case ReauthResult.success:
      return DeleteAccountResult.success;
    case ReauthResult.canceled:
      return DeleteAccountResult.canceled;
    case ReauthResult.failed:
      return DeleteAccountResult.failed;
  }
}

Future<DeleteAccountResult> confirmAndDeleteAccount(
  BuildContext context,
) async {
  final copy = GuideScope.of(context).copy;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(copy.deleteAccount),
        content: Text(copy.deleteAccountMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(copy.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(copy.deleteAccountConfirm),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return DeleteAccountResult.canceled;
  }

  final reauthed = await reauthenticateCurrentUser(context);
  if (!context.mounted) return DeleteAccountResult.canceled;
  if (reauthed != ReauthResult.success) {
    return deleteAccountResultForReauth(reauthed);
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  Future<void> hideSpinner() async {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  try {
    await _deleteUser();
    await hideSpinner();
    return DeleteAccountResult.success;
  } on FirebaseAuthException catch (error) {
    await hideSpinner();
    if (error.code != 'requires-recent-login' || !context.mounted) {
      return DeleteAccountResult.failed;
    }
    final again = await reauthenticateCurrentUser(context);
    if (!context.mounted) return DeleteAccountResult.canceled;
    if (again != ReauthResult.success) {
      return deleteAccountResultForReauth(again);
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _deleteUser();
      await hideSpinner();
      return DeleteAccountResult.success;
    } catch (_) {
      await hideSpinner();
      return DeleteAccountResult.failed;
    }
  } catch (_) {
    await hideSpinner();
    return DeleteAccountResult.failed;
  }
}

Future<void> _deleteUser() async {
  final user = Auth.firebaseAuth.currentUser;
  if (user == null || user.isAnonymous) {
    throw StateError('not signed in');
  }
  await deleteOwnedSightings(user.uid);
  await releaseStorePurchases();
  await user.delete();
  await Auth.signOut();
}

void showDeleteAccountResult(BuildContext context, DeleteAccountResult result) {
  if (result == DeleteAccountResult.canceled || !context.mounted) return;
  final copy = GuideScope.of(context).copy;
  final message = result == DeleteAccountResult.success
      ? copy.deleteAccountSuccess
      : copy.deleteAccountFailed;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<ReauthResult> reauthenticateCurrentUser(BuildContext context) async {
  final user = Auth.firebaseAuth.currentUser;
  if (user == null) return ReauthResult.canceled;
  final providers = user.providerData.map((info) => info.providerId).toList();
  try {
    if (providers.contains('google.com')) {
      await prepareGoogleSignIn();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) return ReauthResult.failed;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return ReauthResult.success;
    }
    if (providers.contains('apple.com')) {
      final apple = await appleOAuth();
      await user.reauthenticateWithCredential(apple.credential);
      return ReauthResult.success;
    }
    if (providers.contains('password')) {
      final email = user.email;
      if (email == null || !context.mounted) return ReauthResult.canceled;
      final password = await _askPassword(context);
      if (password == null || password.isEmpty) return ReauthResult.canceled;
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return ReauthResult.success;
    }
    if (providers.contains('phone')) {
      final phone = user.phoneNumber;
      if (phone == null || !context.mounted) return ReauthResult.canceled;
      final signed = await _reauthenticatePhone(context, user, phone);
      return signed ? ReauthResult.success : ReauthResult.canceled;
    }
  } on GoogleSignInException catch (error) {
    return reauthResultOf(error);
  } on SignInWithAppleAuthorizationException catch (error) {
    return reauthResultOf(error);
  } catch (error) {
    return reauthResultOf(error);
  }
  return ReauthResult.failed;
}

Future<String?> _askPassword(BuildContext context) async {
  final copy = GuideScope.of(context).copy;
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(copy.deleteAccountReauth),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: copy.passwordHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(copy.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(copy.signInContinue),
          ),
        ],
      );
    },
  );
  return result;
}

Future<bool> _reauthenticatePhone(
  BuildContext context,
  User user,
  String phone,
) async {
  final copy = GuideScope.of(context).copy;
  final gate = PhoneVerifyGate();
  final done = Completer<void>();
  await Auth.verifyPhone(
    phoneNumber: phone,
    verificationCompleted: (credential) async {
      gate.autoStarted();
      try {
        await user.reauthenticateWithCredential(credential);
        if (gate.autoFinished(signedIn: true) && !done.isCompleted) {
          done.complete();
        }
      } catch (error) {
        if (gate.autoFinished(signedIn: false, error: error) &&
            !done.isCompleted) {
          done.completeError(error);
        }
      }
    },
    verificationFailed: (error) {
      if (gate.failed(error) && !done.isCompleted) done.completeError(error);
    },
    codeSent: (id, _) {
      gate.codeSent(id, null);
    },
    codeAutoRetrievalTimeout: (id) {
      if (gate.autoTimedOut(id) && !done.isCompleted) done.complete();
    },
  );
  await done.future.timeout(const Duration(seconds: 60));
  if (gate.signedIn) return true;
  if (gate.error != null) throw gate.error!;
  final verificationId = gate.verificationId;
  if (!context.mounted || verificationId == null) return false;
  final code = await _askCode(context, copy, phone);
  if (code == null || code.length != 6) return false;
  await user.reauthenticateWithCredential(
    PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code),
  );
  return true;
}

Future<String?> _askCode(BuildContext context, Copy copy, String phone) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(copy.signInCode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              copy.signInCodeNote(phone),
              style: GuideType.muted(GuideColors.of(dialogContext)),
            ),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(labelText: copy.codeHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(copy.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(copy.signInContinue),
          ),
        ],
      );
    },
  );
}
