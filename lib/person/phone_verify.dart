/// Waits out phone verification without letting `codeSent` win over
/// `verificationCompleted`.
///
/// Android often reports the code and then signs in by itself. Completing
/// the wait on `codeSent` returns "enter the code" while that sign-in is
/// still running.
class PhoneVerifyGate {
  var _autoStarted = false;
  var _settled = false;
  var signedIn = false;
  String? verificationId;
  int? resendToken;
  Object? error;

  bool get settled => _settled;

  void codeSent(String id, int? token) {
    verificationId = id;
    resendToken = token;
  }

  void autoStarted() {
    _autoStarted = true;
  }

  /// The automatic sign-in finished. This ends the wait.
  bool autoFinished({required bool signedIn, Object? error}) {
    this.signedIn = signedIn;
    this.error = error;
    _settled = true;
    return true;
  }

  /// Auto-retrieval gave up. Ignored once sign-in has started or finished.
  bool autoTimedOut(String id) {
    if (id.isNotEmpty) verificationId = id;
    if (_settled || _autoStarted) return false;
    _settled = true;
    return true;
  }

  /// A failure before automatic sign-in starts. Ignored once that sign-in
  /// has begun, so a late error cannot drop a credential that is in flight.
  bool failed(Object error) {
    if (_settled || _autoStarted) return false;
    this.error = error;
    _settled = true;
    return true;
  }
}
