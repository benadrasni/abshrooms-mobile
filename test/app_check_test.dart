import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/purchase/billing.dart';
import 'package:whats_that_mushroom/shell/app_check.dart';

void main() {
  tearDown(GuideAppCheck.resetForTest);

  test('a reward waits for App Check and retries the grant', () async {
    var starts = 0;
    var grants = 0;
    GuideAppCheck.bind(() async {
      starts += 1;
    });
    final granted = await grantPhotoNameWhenReady(() async {
      grants += 1;
      if (grants == 1) throw StateError('app check');
      return true;
    });
    expect(granted, isTrue);
    expect(starts, 2);
    expect(grants, 2);
  });

  test('restore runs on the first launch and when asked', () {
    expect(restoreOnLaunch(explicit: false, alreadyRestored: false), isTrue);
    expect(restoreOnLaunch(explicit: false, alreadyRestored: true), isFalse);
    expect(restoreOnLaunch(explicit: true, alreadyRestored: true), isTrue);
  });
}
