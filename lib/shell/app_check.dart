/// App Check activation shared by the catalog load and a rewarded grant.
///
/// [ensure] is the only once-gate. A failed activation is tried once more.
/// A later callable error does not reset that gate.
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

  static Future<void> ensure() async {
    if (_done) return;
    final existing = _pending;
    if (existing != null) {
      await existing;
      return;
    }
    final start = _start;
    if (start == null) return;
    final flight = _activate(start);
    _pending = flight;
    try {
      await flight;
      _done = true;
    } catch (error) {
      if (identical(_pending, flight)) _pending = null;
      rethrow;
    }
  }

  static Future<void> _activate(Future<void> Function() start) async {
    try {
      await start();
    } catch (_) {
      await start();
    }
  }
}
