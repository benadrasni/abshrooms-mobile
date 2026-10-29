import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whats_that_mushroom/book/book_page.dart';
import 'package:whats_that_mushroom/find/find_page.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/seen/seen_page.dart';
import 'package:whats_that_mushroom/shell/app_version.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/version_gate.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

class GuideShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VersionPrompt versionPrompt;
  final VoidCallback? onVersionUpdate;
  final VoidCallback? onVersionDismiss;

  const GuideShell({
    super.key,
    required this.index,
    required this.onSelect,
    this.versionPrompt = VersionPrompt.none,
    this.onVersionUpdate,
    this.onVersionDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final update = onVersionUpdate;
    final dismiss = onVersionDismiss;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colors.cream,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (versionPrompt == VersionPrompt.banner &&
                  update != null &&
                  dismiss != null)
                VersionBanner(
                  copy: GuideScope.of(context).copy,
                  onUpdate: update,
                  onDismiss: dismiss,
                ),
              Expanded(
                child: IndexedStack(
                  index: index,
                  children: [
                    const FindPage(),
                    const BookPage(),
                    SeenPage(active: index == 2),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: GuideBottomBar(
          index: index,
          onSelect: onSelect,
          showAd: (index == 0 || index == 1) && Purchases.showsAds(),
        ),
      ),
    );
  }
}
