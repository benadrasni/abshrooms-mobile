import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whats_that_mushroom/book/book_page.dart';
import 'package:whats_that_mushroom/find/find_page.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/seen/seen_page.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

class GuideShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const GuideShell({super.key, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
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
        bottomNavigationBar: GuideBottomBar(
          index: index,
          onSelect: onSelect,
          showAd: (index == 0 || index == 1) && Purchases.showsAds(),
        ),
      ),
    );
  }
}
