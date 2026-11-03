import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/seen/private_sync.dart';

/// The two Macrolepiota procera finds already on the phone. Neither has
/// been shared, and neither has been copied to an account yet.
FindRecord _procera(String id, int millis) {
  return FindRecord(
    id: id,
    millis: millis,
    latin: 'Macrolepiota procera',
    confirmed: true,
    photoPath: '/tmp/$id.jpg',
  );
}

const _now = 1700000000000;

void main() {
  test('two unsynced finds upload and an empty account does not drop them', () {
    final local = [
      _procera('1793722129906610', 1312611572000),
      _procera('1793722108673606', 1189955367000),
    ];
    final plan = planPrivateSync(
      uid: 'ada',
      local: local,
      remote: const {},
      allowDrops: true,
      deletedLocal: const {},
      onPhone: (_) => true,
      now: _now,
    );
    expect(plan.deleteFiles, isEmpty);
    expect(plan.deleteRemote, isEmpty);
    expect(plan.downloads, isEmpty);
    expect(plan.upload.map((find) => find.id), [
      '1793722129906610',
      '1793722108673606',
    ]);
    expect(plan.upload.every((find) => find.syncedUid == null), isTrue);
    expect(plan.upload.every((find) => find.updated == _now), isTrue);
    expect(plan.changed, isTrue);
    expect(plan.finds.map((find) => find.id), [
      '1793722129906610',
      '1793722108673606',
    ]);
    expect(
      plan.finds.every((find) => find.latin == 'Macrolepiota procera'),
      isTrue,
    );
  });

  test('a find already on the account is added to an empty phone', () {
    final plan = planPrivateSync(
      uid: 'ada',
      local: const [],
      remote: {
        '9': {
          'millis': 50,
          'updated': 40,
          'confirmed': true,
          'latin': 'Boletus edulis',
          'photo': 'private/ada/9.jpg',
        },
      },
      allowDrops: true,
      deletedLocal: const {},
      onPhone: (_) => false,
      now: _now,
    );
    expect(plan.upload, isEmpty);
    expect(plan.finds, hasLength(1));
    expect(plan.finds.single.id, '9');
    expect(plan.finds.single.latin, 'Boletus edulis');
    expect(plan.finds.single.syncedUid, 'ada');
    expect(plan.finds.single.photoPath, isNull);
    expect(plan.downloads, [(id: '9', object: 'private/ada/9.jpg')]);
  });

  test(
    'a server snapshot drops a synced find and keeps its file path to delete',
    () {
      const path = '/tmp/finds/1.jpg';
      final plan = planPrivateSync(
        uid: 'ada',
        local: [
          FindRecord(
            id: '1',
            millis: 10,
            latin: 'Boletus edulis',
            updated: 10,
            syncedUid: 'ada',
            photoPath: path,
            confirmed: true,
          ),
        ],
        remote: const {},
        allowDrops: true,
        deletedLocal: const {},
        onPhone: (file) => file == path,
        now: _now,
      );
      expect(plan.finds, isEmpty);
      expect(plan.upload, isEmpty);
      expect(plan.deleteFiles, [path]);
      expect(plan.changed, isTrue);
    },
  );

  test('a cache snapshot does not drop or re-upload a synced find', () {
    final local = FindRecord(
      id: '1',
      millis: 10,
      latin: 'Boletus edulis',
      updated: 10,
      syncedUid: 'ada',
      confirmed: true,
    );
    final plan = planPrivateSync(
      uid: 'ada',
      local: [local],
      remote: const {},
      allowDrops: false,
      deletedLocal: const {},
      onPhone: (_) => false,
      now: _now,
    );
    expect(plan.changed, isFalse);
    expect(plan.finds.single.syncedUid, 'ada');
    expect(plan.finds.single.latin, 'Boletus edulis');
    expect(plan.upload, isEmpty);
    expect(plan.deleteFiles, isEmpty);
  });

  test('a newer account row wins and keeps a photo already on the phone', () {
    const path = '/tmp/finds/1.jpg';
    final plan = planPrivateSync(
      uid: 'ada',
      local: [
        FindRecord(
          id: '1',
          millis: 10,
          latin: 'Boletus edulis',
          updated: 10,
          syncedUid: 'ada',
          photoPath: path,
          confirmed: true,
        ),
      ],
      remote: {
        '1': {
          'millis': 10,
          'updated': 20,
          'confirmed': true,
          'latin': 'Boletus pinophilus',
          'photo': 'private/ada/1.jpg',
        },
      },
      allowDrops: true,
      deletedLocal: const {},
      onPhone: (file) => file == path,
      now: _now,
    );
    expect(plan.upload, isEmpty);
    expect(plan.downloads, isEmpty);
    expect(plan.finds.single.latin, 'Boletus pinophilus');
    expect(plan.finds.single.photoPath, path);
    expect(plan.finds.single.updated, 20);
    expect(plan.finds.single.syncedUid, 'ada');
  });

  test(
    'a newer phone row uploads and an equal stamp with a new share uploads',
    () {
      final newer = planPrivateSync(
        uid: 'ada',
        local: [
          FindRecord(
            id: '1',
            millis: 10,
            latin: 'Boletus edulis',
            updated: 30,
            syncedUid: 'ada',
            confirmed: true,
            share: FindShare.review,
          ),
        ],
        remote: {
          '1': {
            'millis': 10,
            'updated': 10,
            'confirmed': true,
            'latin': 'Boletus edulis',
          },
        },
        allowDrops: true,
        deletedLocal: const {},
        onPhone: (_) => false,
        now: _now,
      );
      expect(newer.upload.single.updated, 30);
      expect(newer.upload.single.share, FindShare.review);
      expect(newer.finds.single.syncedUid, 'ada');

      final share = planPrivateSync(
        uid: 'ada',
        local: [
          FindRecord(
            id: '1',
            millis: 10,
            latin: 'Boletus edulis',
            updated: 10,
            syncedUid: 'ada',
            confirmed: true,
            share: FindShare.shared,
          ),
        ],
        remote: {
          '1': {
            'millis': 10,
            'updated': 10,
            'confirmed': true,
            'latin': 'Boletus edulis',
          },
        },
        allowDrops: true,
        deletedLocal: const {},
        onPhone: (_) => false,
        now: _now,
      );
      expect(share.upload.single.share, FindShare.shared);
      expect(share.upload.single.updated, 10);
    },
  );

  test('a find synced to another account stays on the phone', () {
    final local = FindRecord(
      id: '1',
      millis: 10,
      latin: 'Boletus edulis',
      updated: 10,
      syncedUid: 'other',
      confirmed: true,
    );
    final plan = planPrivateSync(
      uid: 'ada',
      local: [local],
      remote: const {},
      allowDrops: true,
      deletedLocal: const {},
      onPhone: (_) => true,
      now: _now,
    );
    expect(plan.changed, isFalse);
    expect(plan.finds.single.syncedUid, 'other');
    expect(plan.upload, isEmpty);
    expect(plan.deleteFiles, isEmpty);
  });

  test('a find deleted on this phone is not put back', () {
    final plan = planPrivateSync(
      uid: 'ada',
      local: const [],
      remote: {
        '1': {
          'millis': 10,
          'updated': 10,
          'confirmed': true,
          'latin': 'Boletus edulis',
          'photo': 'private/ada/1.jpg',
        },
      },
      allowDrops: true,
      deletedLocal: {'1'},
      onPhone: (_) => false,
      now: _now,
    );
    expect(plan.finds, isEmpty);
    expect(plan.upload, isEmpty);
    expect(plan.downloads, isEmpty);
    expect(plan.deleteRemote, ['1']);
  });

  test('a photo downloads only from this account’s private object', () {
    expect(
      privatePhotoObject('ada', '1793722129906610'),
      'private/ada/1793722129906610.jpg',
    );
    expect(privatePhotoObject('a/b', '1'), '');
    expect(privatePhotoObject('ada', '../1'), '');
    expect(privatePhotoObject('ada', ''), '');

    PrivateSyncPlan planFor(
      String photo, {
      bool onPhone = false,
      String? path,
    }) {
      return planPrivateSync(
        uid: 'ada',
        local: [
          FindRecord(
            id: '1',
            millis: 10,
            updated: 10,
            syncedUid: 'ada',
            latin: 'Boletus edulis',
            confirmed: true,
            photoPath: path,
          ),
        ],
        remote: {
          '1': {
            'millis': 10,
            'updated': 10,
            'confirmed': true,
            'latin': 'Boletus edulis',
            'photo': photo,
          },
        },
        allowDrops: true,
        deletedLocal: const {},
        onPhone: (_) => onPhone,
        now: _now,
      );
    }

    expect(planFor('private/ada/1.jpg').downloads, [
      (id: '1', object: 'private/ada/1.jpg'),
    ]);
    expect(planFor('private/ada/1.jpg', onPhone: true).downloads, isEmpty);
    expect(planFor('private/other/1.jpg').downloads, isEmpty);
    expect(planFor('sightings/ada/1.jpg').downloads, isEmpty);
    expect(
      planFor(
        'private/ada/1.jpg',
        path: 'https://firebasestorage.googleapis.com/v0/b/bucket/o/sightings%2Fpublic%2F1.jpg?alt=media',
      ).downloads,
      isEmpty,
    );
  });

  test('a phone photo uploads when the account row has none', () {
    final plan = planPrivateSync(
      uid: 'ada',
      local: [
        FindRecord(
          id: '1',
          millis: 10,
          latin: 'Boletus edulis',
          updated: 10,
          syncedUid: 'ada',
          confirmed: true,
          photoPath: '/tmp/1.jpg',
        ),
      ],
      remote: {
        '1': {
          'millis': 10,
          'updated': 10,
          'confirmed': true,
          'latin': 'Boletus edulis',
        },
      },
      allowDrops: true,
      deletedLocal: const {},
      onPhone: (path) => path == '/tmp/1.jpg',
      now: _now,
    );
    expect(plan.upload.single.id, '1');
    expect(plan.downloads, isEmpty);
    expect(plan.changed, isFalse);
  });

  test('a stored private find omits the phone path and an empty share', () {
    final data = privateFindData(
      const FindRecord(
        id: '1',
        millis: 10,
        updated: 10,
        latin: 'Macrolepiota procera',
        confirmed: true,
        photoPath: '/tmp/1.jpg',
        syncedUid: 'ada',
        share: FindShare.none,
        latitude: 48.1,
        longitude: 17.1,
        country: 'sk',
      ),
    );
    expect(data.containsKey('photoPath'), isFalse);
    expect(data.containsKey('syncedUid'), isFalse);
    expect(data.containsKey('photo'), isFalse);
    expect(data.containsKey('share'), isFalse);
    expect(data['latin'], 'Macrolepiota procera');
    expect(data['country'], 'sk');
    expect(data['latitude'], 48.1);
    expect(data['longitude'], 17.1);

    final half = privateFindData(
      const FindRecord(
        id: '1',
        millis: 10,
        updated: 10,
        confirmed: true,
        latitude: 48.1,
      ),
    );
    expect(half.containsKey('latitude'), isFalse);
    expect(half.containsKey('longitude'), isFalse);

    final back = findFromPrivate('1', {
      ...data,
      'photo': 'private/ada/1.jpg',
    }, syncedUid: 'ada');
    expect(back.photoPath, isNull);
    expect(back.syncedUid, 'ada');
    expect(back.latin, 'Macrolepiota procera');
  });

  test('a find with no time and an empty id stay on the phone', () {
    final timeless = FindRecord(
      id: '1',
      millis: 0,
      latin: 'Boletus edulis',
      confirmed: true,
    );
    final blank = FindRecord(id: '', millis: 10, confirmed: true);
    final plan = planPrivateSync(
      uid: 'ada',
      local: [timeless, blank],
      remote: const {},
      allowDrops: true,
      deletedLocal: const {},
      onPhone: (_) => false,
      now: _now,
    );
    expect(plan.upload, isEmpty);
    expect(plan.changed, isFalse);
    expect(plan.finds.map((find) => find.id), ['1', '']);
  });
}
