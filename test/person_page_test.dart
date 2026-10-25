import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/person/account.dart';
import 'package:whats_that_mushroom/person/person_page.dart';
import 'package:whats_that_mushroom/purchase/names.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

void main() {
  testWidgets('Person matches the plant language and theme rows', (
    tester,
  ) async {
    final settings = GuideSettings();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_Host(settings: settings));

    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Sign in to name a photo'), findsOneWidget);
    expect(
      find.text('The key and the book stay free without an account.'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Names this month'), findsNothing);
    expect(find.text('Field Guide'), findsOneWidget);
    expect(
      find.text('7 days free • Unlimited • No ads • Seen sync • Offline'),
      findsOneWidget,
    );
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Rate this app'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Light, like the phone'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('With Field Guide'), findsOneWidget);
    expect(find.text('Person'), findsNothing);

    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(settings.themeMode, ThemeMode.dark);
    expect(find.text('Always dark'), findsOneWidget);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.text('The app follows this language.'), findsOneWidget);
    expect(find.text('Slovenčina'), findsOneWidget);
    expect(find.text('Slovak'), findsOneWidget);

    await tester.tap(find.text('Slovenčina'));
    await tester.pumpAndSettle();
    expect(settings.language, 'sk');
    expect(find.text('Jazyk'), findsOneWidget);
    expect(find.text('Slovenčina'), findsOneWidget);
    expect(find.text('Motív'), findsOneWidget);
    expect(find.text('Terénny sprievodca'), findsOneWidget);
    expect(find.text('Prihlás sa na určenie z fotografie'), findsOneWidget);
    expect(find.text('Určenia tento mesiac'), findsNothing);
    expect(find.text('Prihlásiť sa'), findsOneWidget);
    expect(find.text('Obnoviť nákupy'), findsOneWidget);
    expect(find.text('Ohodnotiť aplikáciu'), findsOneWidget);
    expect(find.text('Režim offline'), findsOneWidget);
    expect(find.text('S Terénnym sprievodcom'), findsOneWidget);
  });

  testWidgets('a signed-in person shows the account and sign out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var signedOut = false;
    Names.setForTest(used: 2, grants: 1);
    addTearDown(Names.resetForTest);
    final month = MonthNames.of(Names.count, DateTime.now());
    const copy = Copy('en');
    await tester.pumpWidget(
      _Host(
        settings: GuideSettings(),
        accountOf: () => const AccountView(
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          provider: AccountProvider.google,
        ),
        onSignOut: () async {
          signedOut = true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada@example.com · Google'), findsOneWidget);
    expect(find.text('Sign in to name a photo'), findsNothing);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Names this month'), findsOneWidget);
    expect(find.text(copy.namesReset(month.resetsOn)), findsOneWidget);
    expect(
      find.text(
        copy.namesMonthDetail(includedUsed: 2, extraUsed: 1, adsLeft: 4),
      ),
      findsOneWidget,
    );
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(signedOut, isTrue);
  });

  testWidgets('Field Guide replaces the month card', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Purchases.remember('field_guide_monthly');
    addTearDown(Purchases.resetForTest);
    Names.setForTest(used: 2, grants: 1);
    addTearDown(Names.resetForTest);
    await tester.pumpWidget(
      _Host(
        settings: GuideSettings(),
        accountOf: () => const AccountView(
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          provider: AccountProvider.google,
        ),
      ),
    );
    expect(find.text('Names this month'), findsNothing);
    expect(find.text('Field Guide'), findsOneWidget);
    expect(
      find.text('Unlimited • No ads • Seen sync • Offline'),
      findsOneWidget,
    );
  });
}

class _Host extends StatefulWidget {
  final GuideSettings settings;
  final AccountView? Function()? accountOf;
  final Future<void> Function()? onSignOut;

  const _Host({required this.settings, this.accountOf, this.onSignOut});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettings);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return GuideScope(
      catalog: CatalogRepository(),
      notebook: Notebook(),
      settings: widget.settings,
      reload: () async {},
      selectTab: (_) {},
      child: MaterialApp(
        theme: guideTheme(Brightness.light),
        locale: Locale(widget.settings.language),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: PersonPage(
          accountOf: widget.accountOf,
          onSignOut: widget.onSignOut,
        ),
      ),
    );
  }
}
