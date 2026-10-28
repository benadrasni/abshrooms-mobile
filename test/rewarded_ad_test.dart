import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/ads/rewarded_ad.dart';
import 'package:whats_that_mushroom/purchase/names.dart';

void main() {
  tearDown(() {
    resetNameGrantWatchForTest();
    Names.resetForTest();
  });

  test('a grant during the wait applies once', () async {
    Names.setForTest(used: 5);
    final snapshots = StreamController<Object?>();
    addTearDown(snapshots.close);
    nameGrantUidForTest = 'account';
    photoQuotaSnapshotsForTest = (_) => snapshots.stream;

    final pending = waitForNameGrant(wait: const Duration(seconds: 2));
    final revision = Names.revision.value;
    snapshots.add(_quota(grants: 1));

    expect(await pending, isTrue);
    expect(Names.count.adGrants, 1);
    expect(Names.count.namesUsed, 5);
    expect(namesRemaining(5, Names.count.adGrants), 1);
    expect(Names.revision.value, revision + 1);

    snapshots.add(_quota(grants: 1));
    await _flush();
    expect(Names.count.adGrants, 1);
    expect(Names.revision.value, revision + 1);
  });

  test('a grant after the wait still applies once', () async {
    Names.setForTest(used: 5);
    final snapshots = StreamController<Object?>();
    addTearDown(snapshots.close);
    nameGrantUidForTest = 'account';
    photoQuotaSnapshotsForTest = (_) => snapshots.stream;

    final pending = waitForNameGrant(wait: const Duration(milliseconds: 40));
    snapshots.add(_quota(grants: 0));
    expect(await pending, isFalse);
    expect(Names.count.adGrants, 0);

    final revision = Names.revision.value;
    snapshots.add(_quota(grants: 1));
    await _flush();
    expect(Names.count.adGrants, 1);
    expect(namesRemaining(5, Names.count.adGrants), 1);
    expect(Names.revision.value, revision + 1);

    snapshots.add(_quota(grants: 1));
    await _flush();
    expect(Names.count.adGrants, 1);
    expect(Names.revision.value, revision + 1);

    snapshots.add(_quota(grants: 2));
    await _flush();
    expect(Names.count.adGrants, 2);
    expect(namesRemaining(5, Names.count.adGrants), 2);
  });

  test('a month rollover and a repeated count are not grants', () async {
    Names.setForTest(used: 5, grants: 4);
    final snapshots = StreamController<Object?>();
    addTearDown(snapshots.close);
    nameGrantUidForTest = 'account';
    photoQuotaSnapshotsForTest = (_) => snapshots.stream;

    final now = DateTime.now().toUtc();
    final previous = quotaMonth(DateTime.utc(now.year, now.month - 1, 1));
    final pending = waitForNameGrant(wait: const Duration(milliseconds: 40));
    snapshots.add(_quota(grants: 5, month: previous));
    expect(await pending, isFalse);
    expect(Names.count.adGrants, 4);

    snapshots.add(_quota(grants: 4));
    await _flush();
    expect(Names.count.adGrants, 4);
  });

  test('a snapshot for another account does not grant', () async {
    Names.setForTest(used: 5);
    final snapshots = StreamController<Object?>();
    addTearDown(snapshots.close);
    nameGrantUidForTest = 'account';
    photoQuotaSnapshotsForTest = (_) => snapshots.stream;

    final pending = waitForNameGrant(wait: const Duration(seconds: 2));
    nameGrantUidForTest = 'someone-else';
    snapshots.add(_quota(grants: 1));
    expect(await pending, isFalse);
    expect(Names.count.adGrants, 0);
  });

  test('there is nothing to listen to without an account', () async {
    expect(
      await waitForNameGrant(wait: const Duration(milliseconds: 5)),
      isFalse,
    );
  });
}

Map<String, Object> _quota({required int grants, int used = 5, String? month}) {
  return {
    'month': month ?? quotaMonth(DateTime.now()),
    'namesUsed': used,
    'adGrants': grants,
  };
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 1));
