import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/purchase/billing.dart';
import 'package:whats_that_mushroom/shell/app_check.dart';

void main() {
  tearDown(GuideAppCheck.resetForTest);

  test('activation retries once and then stays done', () async {
    var starts = 0;
    GuideAppCheck.bind(() async {
      starts += 1;
      if (starts == 1) throw StateError('token');
    });
    await GuideAppCheck.ensure();
    expect(starts, 2);
    await GuideAppCheck.ensure();
    expect(starts, 2);
  });

  test('a callable error does not activate App Check again', () async {
    var starts = 0;
    GuideAppCheck.bind(() async {
      starts += 1;
    });
    await GuideAppCheck.ensure();
    expect(starts, 1);
    try {
      throw StateError('callable');
    } catch (_) {}
    await GuideAppCheck.ensure();
    expect(starts, 1);
  });

  test('a thrown restore still marks the first launch done', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    await restoreOnFirstLaunch(
      preferences: () async => prefs,
      restorePurchases: () async {
        calls += 1;
        throw StateError('store');
      },
    );
    expect(calls, 1);
    expect(prefs.getBool(storeRestoreKey), isTrue);

    await restoreOnFirstLaunch(
      preferences: () async => prefs,
      restorePurchases: () async {
        calls += 1;
      },
    );
    expect(calls, 1);
  });
}
