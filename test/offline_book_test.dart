import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/offline/offline_book.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('mushroom-offline');
    OfflineBook.resetForTest();
    OfflineBook.rootOverride = directory.path;
  });

  tearDown(() {
    OfflineBook.resetForTest();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test(
    'a finished download keeps pictures and skips a missing family icon',
    () async {
      var finished = false;
      final started = await startOfflineDownload(
        request: const OfflineRequest(
          title: 'Everything',
          species: 1,
          pending: ['photos/a.webp', 'families/Amanitaceae.webp'],
          alreadyDone: 0,
          totalFiles: 2,
          markStored: true,
          update: false,
        ),
        wifi: () async => true,
        fetch: (path) async => path.startsWith('families/') ? null : [9, 8, 7],
        onProgress: (_, _) {},
        onFinished: () => finished = true,
        onFailed: () => fail('download failed'),
      );
      expect(started, OfflineStart.started);
      await OfflineBook.idle;

      expect(finished, isTrue);
      expect(OfflineBook.stored, isTrue);
      expect(OfflineBook.speciesSaved, 1);
      expect(OfflineBook.saved, {'photos/a.webp'});
      expect(OfflineBook.skipped, {'families/Amanitaceae.webp'});
      expect(
        File('${directory.path}/offline/photos/a.webp').readAsBytesSync(),
        [9, 8, 7],
      );
      expect(
        OfflineBook.localFile('${storageRoot}photos/a.webp')?.path,
        endsWith('offline/photos/a.webp'),
      );
      expect(
        OfflineBook.localFile('https://evil.example/photos/a.webp'),
        isNull,
      );

      OfflineBook.saved.clear();
      OfflineBook.skipped.clear();
      OfflineBook.stored = false;
      await OfflineBook.restore();
      expect(OfflineBook.stored, isTrue);
      expect(OfflineBook.saved, {'photos/a.webp'});
      expect(OfflineBook.skipped, {'families/Amanitaceae.webp'});
    },
  );

  test('a missing plate fails the book and a pause can resume', () async {
    var failed = false;
    await startOfflineDownload(
      request: const OfflineRequest(
        title: 'Everything',
        species: 1,
        pending: ['photos/a.webp'],
        alreadyDone: 0,
        totalFiles: 1,
        markStored: true,
        update: false,
      ),
      wifi: () async => true,
      fetch: (_) async => null,
      onProgress: (_, _) {},
      onFinished: () => fail('finished'),
      onFailed: () => failed = true,
    );
    await OfflineBook.idle;
    expect(failed, isTrue);
    expect(OfflineBook.stored, isFalse);

    await startOfflineDownload(
      request: const OfflineRequest(
        title: 'Everything',
        species: 1,
        pending: ['photos/a.webp', 'photos/b.webp'],
        alreadyDone: 0,
        totalFiles: 2,
        markStored: true,
        update: false,
      ),
      wifi: () async => true,
      fetch: (path) async {
        if (path == 'photos/b.webp') OfflineBook.pause();
        return [1];
      },
      onProgress: (_, _) {},
      onFinished: () => fail('paused download finished'),
      onFailed: () => fail('paused download failed'),
    );
    await OfflineBook.idle;
    expect(OfflineBook.stored, isFalse);
    expect(OfflineBook.saved, {'photos/a.webp'});

    var resumed = false;
    await startOfflineDownload(
      request: const OfflineRequest(
        title: 'Everything',
        species: 1,
        pending: ['photos/b.webp'],
        alreadyDone: 1,
        totalFiles: 2,
        markStored: true,
        update: false,
      ),
      wifi: () async => true,
      fetch: (_) async => [2],
      onProgress: (_, _) {},
      onFinished: () => resumed = true,
      onFailed: () => fail('resume failed'),
    );
    await OfflineBook.idle;
    expect(resumed, isTrue);
    expect(OfflineBook.stored, isTrue);
    expect(OfflineBook.saved, {'photos/a.webp', 'photos/b.webp'});
  });

  test('Wi-Fi is required and remove deletes the book', () async {
    final started = await startOfflineDownload(
      request: const OfflineRequest(
        title: 'Everything',
        species: 1,
        pending: ['photos/a.webp'],
        alreadyDone: 0,
        totalFiles: 1,
        markStored: true,
        update: false,
      ),
      wifi: () async => false,
      fetch: (_) async => [1],
      onProgress: (_, _) {},
      onFinished: () {},
      onFailed: () {},
    );
    expect(started, OfflineStart.needsWifi);
    expect(OfflineBook.saved, isEmpty);

    await startOfflineDownload(
      request: const OfflineRequest(
        title: 'Everything',
        species: 1,
        pending: ['photos/a.webp'],
        alreadyDone: 0,
        totalFiles: 1,
        markStored: true,
        update: false,
      ),
      wifi: () async => true,
      fetch: (_) async => [4],
      onProgress: (_, _) {},
      onFinished: () {},
      onFailed: () => fail('download failed'),
    );
    await OfflineBook.idle;
    expect(Directory('${directory.path}/offline').existsSync(), isTrue);

    await OfflineBook.clear();
    expect(OfflineBook.stored, isFalse);
    expect(OfflineBook.saved, isEmpty);
    expect(Directory('${directory.path}/offline').existsSync(), isFalse);
  });

  testWidgets('GuidePhoto prefers the file saved with the book', (
    tester,
  ) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    Directory('${directory.path}/offline/photos').createSync(recursive: true);
    File('${directory.path}/offline/photos/a.webp').writeAsBytesSync(png);
    OfflineBook.saved.add('photos/a.webp');

    await tester.pumpWidget(
      MaterialApp(
        theme: guideTheme(Brightness.light),
        home: const SizedBox(
          width: 40,
          height: 40,
          child: GuidePhoto(url: '${storageRoot}photos/a.webp'),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: guideTheme(Brightness.light),
        home: const SizedBox(
          width: 40,
          height: 40,
          child: GuidePhoto(url: '${storageRoot}photos/missing.webp'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
