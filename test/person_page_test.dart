import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/person/person_page.dart';
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
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Light, like the phone'), findsOneWidget);
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
  });
}

class _Host extends StatefulWidget {
  final GuideSettings settings;

  const _Host({required this.settings});

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
        home: const PersonPage(),
      ),
    );
  }
}
