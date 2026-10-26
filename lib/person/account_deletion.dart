import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/purchase/store_proof.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

enum DeleteAccountResult { success, canceled, failed }

Future<DeleteAccountResult> confirmAndDeleteAccount(BuildContext context) async {
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
  if (confirmed != true || !context.mounted) return DeleteAccountResult.canceled;

  final reauthed = await reauthenticateCurrentUser(context);
  if (!reauthed || !context.mounted) return DeleteAccountResult.canceled;

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
    if (!again || !context.mounted) return DeleteAccountResult.canceled;
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

Future<bool> reauthenticateCurrentUser(BuildContext context) async {
  final user = Auth.firebaseAuth.currentUser;
  if (user == null) return false;
  final providers = user.providerData.map((info) => info.providerId).toList();
  try {
    if (providers.contains('google.com')) {
      await prepareGoogleSignIn();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) return false;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return true;
    }
    if (providers.contains('apple.com')) {
      final apple = await appleOAuth();
      await user.reauthenticateWithCredential(apple.credential);
      return true;
    }
    if (providers.contains('password')) {
      final email = user.email;
      if (email == null || !context.mounted) return false;
      final password = await _askPassword(context);
      if (password == null || password.isEmpty) return false;
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return true;
    }
    if (providers.contains('phone')) {
      final phone = user.phoneNumber;
      if (phone == null || !context.mounted) return false;
      return await _reauthenticatePhone(context, user, phone);
    }
  } on GoogleSignInException catch (error) {
    if (error.code == GoogleSignInExceptionCode.canceled) return false;
    return false;
  } on SignInWithAppleAuthorizationException catch (error) {
    if (error.code == AuthorizationErrorCode.canceled) return false;
    return false;
  } catch (_) {
    return false;
  }
  return false;
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

Future<bool> _reauthenticatePhone(BuildContext context, User user, String phone) async {
  final copy = GuideScope.of(context).copy;
  final done = Completer<String?>();
  String? verificationId;
  await Auth.verifyPhone(
    phoneNumber: phone,
    verificationCompleted: (credential) async {
      try {
        await user.reauthenticateWithCredential(credential);
        if (!done.isCompleted) done.complete('signed');
      } catch (error) {
        if (!done.isCompleted) done.completeError(error);
      }
    },
    verificationFailed: (error) {
      if (!done.isCompleted) done.completeError(error);
    },
    codeSent: (id, _) {
      verificationId = id;
      if (!done.isCompleted) done.complete(null);
    },
    codeAutoRetrievalTimeout: (id) {
      verificationId = id;
      if (!done.isCompleted) done.complete(null);
    },
  );
  final automatic = await done.future.timeout(const Duration(seconds: 60));
  if (automatic == 'signed') return true;
  if (!context.mounted || verificationId == null) return false;
  final code = await _askCode(context, copy, phone);
  if (code == null || code.length != 6) return false;
  await user.reauthenticateWithCredential(
    PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: code),
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
            Text(copy.signInCodeNote(phone), style: GuideType.muted(GuideColors.of(dialogContext))),
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
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(copy.signInContinue),
          ),
        ],
      );
    },
  );
}
