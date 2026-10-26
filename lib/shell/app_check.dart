/// App Check activation shared by the catalog load and a rewarded grant.
///
/// The catalog starts activation and does not wait on it. A reward waits
/// until that activation finishes, and retries the grant if it fails.
class GuideAppCheck {
  static Future<void> Function()? _start;
  static Future<void>? _pending;
  static var _done = false;

  static void bind(Future<void> Function() start) {
    _start = start;
  }

  static void resetForTest() {
    _start = null;
    _pending = null;
    _done = false;
  }

  static void invalidate() {
    _done = false;
    _pending = null;
  }

  static Future<void> ensure() async {
    if (_done) return;
    final existing = _pending;
    if (existing != null) {
      await existing;
      return;
    }
    final start = _start;
    if (start == null) return;
    final flight = start();
    _pending = flight;
    try {
      await flight;
      _done = true;
    } catch (error) {
      if (identical(_pending, flight)) _pending = null;
      rethrow;
    }
  }
}

/// Awaits App Check, calls [grant], and tries both once more on failure.
Future<bool> grantPhotoNameWhenReady(Future<bool> Function() grant) async {
  await _appCheckReady();
  try {
    return await grant();
  } catch (_) {
    GuideAppCheck.invalidate();
    await _appCheckReady();
    return await grant();
  }
}

Future<void> _appCheckReady() async {
  try {
    await GuideAppCheck.ensure();
  } catch (_) {
    GuideAppCheck.invalidate();
    await GuideAppCheck.ensure();
  }
}
