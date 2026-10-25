import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whats_that_mushroom/ads/app_banner_ad.dart';
import 'package:whats_that_mushroom/book/book_page.dart';
import 'package:whats_that_mushroom/find/find_page.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/seen/seen_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

class GuideShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const GuideShell({super.key, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
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
          child: IndexedStack(
            index: index,
            children: const [FindPage(), BookPage(), SeenPage()],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((index == 0 || index == 1) && Purchases.showsAds())
              const AppBannerAd(pinned: true),
            NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onSelect,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.search),
                  label: copy.find,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  label: copy.book,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.photo_outlined),
                  label: copy.seen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
