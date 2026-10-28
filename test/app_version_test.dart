import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/shell/app_version.dart';
import 'package:whats_that_mushroom/shell/app_version_check.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/version_gate.dart';

VersionFacts facts({
  int build = 101,
  int? fetchedFloor = 0,
  int cachedFloor = 0,
  int rememberedFloor = 0,
  int? storeBuild,
  int dismissedStore = 0,
}) {
  return VersionFacts(
    build: build,
    fetchedFloor: fetchedFloor,
    cachedFloor: cachedFloor,
    rememberedFloor: rememberedFloor,
    storeBuild: storeBuild,
    dismissedStore: dismissedStore,
  );
}

void main() {
  test('the gate controller notifies once when the prompt changes', () {
    final controller = VersionGateController.instance;
    var notices = 0;
    void listener() => notices++;
    controller.addListener(listener);
    addTearDown(() {
      controller.removeListener(listener);
      controller.resetForTest();
    });

    controller.apply(VersionPrompt.block);
    controller.apply(VersionPrompt.block);
    expect(controller.prompt, VersionPrompt.block);
    expect(notices, 1);

    controller.apply(VersionPrompt.none);
    expect(notices, 2);
  });

  test('a floor of zero leaves the current build open', () {
    final decision = decideVersion(facts());
    expect(decision.prompt, VersionPrompt.none);
    expect(decision.persistFloor, isNull);
    expect(decision.clearFloor, isFalse);
  });

  test('a build below the fetched floor is blocked and remembered', () {
    final decision = decideVersion(facts(build: 101, fetchedFloor: 120));
    expect(decision.prompt, VersionPrompt.block);
    expect(decision.persistFloor, 120);
    expect(decision.clearFloor, isFalse);
  });

  test('a finished fetch below the build clears a remembered floor', () {
    final decision = decideVersion(
      facts(build: 120, fetchedFloor: 0, rememberedFloor: 120),
    );
    expect(decision.prompt, VersionPrompt.none);
    expect(decision.clearFloor, isTrue);
    expect(decision.persistFloor, isNull);
  });

  test('a failed fetch keeps a build closed when a floor was remembered', () {
    final decision = decideVersion(
      facts(build: 101, fetchedFloor: null, rememberedFloor: 120),
    );
    expect(decision.prompt, VersionPrompt.block);
    expect(decision.persistFloor, 120);
    expect(decision.clearFloor, isFalse);
  });

  test('a failed fetch with no cache and no memory stays open', () {
    final decision = decideVersion(facts(build: 101, fetchedFloor: null));
    expect(decision.prompt, VersionPrompt.none);
    expect(decision.clearFloor, isFalse);
    expect(decision.persistFloor, isNull);
  });

  test('a cached floor closes the build when the fresh fetch fails', () {
    final decision = decideVersion(
      facts(build: 101, fetchedFloor: null, cachedFloor: 120),
    );
    expect(decision.prompt, VersionPrompt.block);
    expect(decision.persistFloor, 120);
  });

  test('an updated build stays open offline without clearing the memory', () {
    final decision = decideVersion(
      facts(build: 120, fetchedFloor: null, rememberedFloor: 120),
    );
    expect(decision.prompt, VersionPrompt.none);
    expect(decision.clearFloor, isFalse);
  });

  test('a newer store build shows a banner until that build is dismissed', () {
    expect(
      decideVersion(facts(build: 101, storeBuild: 120)).prompt,
      VersionPrompt.banner,
    );
    expect(
      decideVersion(facts(build: 101, storeBuild: 120, dismissedStore: 101))
          .prompt,
      VersionPrompt.banner,
    );
    expect(
      decideVersion(facts(build: 101, storeBuild: 120, dismissedStore: 120))
          .prompt,
      VersionPrompt.none,
    );
    expect(
      decideVersion(facts(build: 120, storeBuild: 120)).prompt,
      VersionPrompt.none,
    );
  });

  test('the floor wins over the store banner', () {
    final decision = decideVersion(
      facts(build: 101, fetchedFloor: 120, storeBuild: 130),
    );
    expect(decision.prompt, VersionPrompt.block);
  });

  test('an unreadable build number does not lock the guide', () {
    final decision = decideVersion(
      facts(build: 0, fetchedFloor: 120, storeBuild: 120),
    );
    expect(decision.prompt, VersionPrompt.none);
  });

  test('a versions document maps the floor and the store build', () {
    final android = versionRemoteFromMap(<String, dynamic>{
      'minAndroid': 120,
      'minIos': 90,
      'android': 130,
      'ios': 100,
    }, android: true);
    expect(android.floor, 120);
    expect(android.storeBuild, 130);

    final ios = versionRemoteFromMap(<String, dynamic>{
      'minIos': 90.0,
      'ios': '100',
    }, android: false);
    expect(ios.floor, 90);
    expect(ios.storeBuild, 100);

    final missing = versionRemoteFromMap(null, android: true);
    expect(missing.floor, 0);
    expect(missing.storeBuild, isNull);
  });

  testWidgets('the required page has no way past the update button', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: guideTheme(Brightness.light),
        home: VersionRequiredPage(
          copy: const Copy('en'),
          onUpdate: () async => taps++,
        ),
      ),
    );

    expect(
      find.text(
        'This version no longer works. Update to keep using the guide.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.close), findsNothing);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);

    await tester.tap(find.byKey(const Key('version-required-update')));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('the required page is in Slovak', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: guideTheme(Brightness.light),
        home: VersionRequiredPage(
          copy: const Copy('sk'),
          onUpdate: () async {},
        ),
      ),
    );

    expect(
      find.text(
        'Táto verzia už nefunguje. Aktualizujte ju, aby ste mohli sprievodcu ďalej používať.',
      ),
      findsOneWidget,
    );
    expect(find.text('Aktualizovať'), findsOneWidget);
  });

  testWidgets('the banner updates or goes away', (tester) async {
    var updates = 0;
    var dismisses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: guideTheme(Brightness.light),
        home: Scaffold(
          body: VersionBanner(
            copy: const Copy('en'),
            onUpdate: () => updates++,
            onDismiss: () => dismisses++,
          ),
        ),
      ),
    );

    expect(
      find.text('New version is available, please update.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('version-banner-update')));
    await tester.tap(find.byKey(const Key('version-banner-dismiss')));
    await tester.pump();
    expect(updates, 1);
    expect(dismisses, 1);
  });
}
