import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/ads/app_banner_ad.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/offline/offline_book.dart';
import 'package:whats_that_mushroom/shell/guide_tabs.dart';
import 'package:whats_that_mushroom/shell/guide_window.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

export 'package:whats_that_mushroom/shell/guide_tabs.dart';
export 'package:whats_that_mushroom/shell/guide_window.dart';

class GuidePhoto extends StatelessWidget {
  final String url;
  final String? label;
  final BoxFit fit;
  final Color? background;

  const GuidePhoto({
    super.key,
    required this.url,
    this.label,
    this.fit = BoxFit.contain,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineBook.revision,
      builder: (context, _) {
        final colors = GuideColors.of(context);
        final file = url.isEmpty ? null : OfflineBook.localFile(url);
        return ColoredBox(
          color: background ?? colors.plateWell,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url.isEmpty)
                const SizedBox.shrink()
              else if (file != null)
                Image.file(
                  file,
                  fit: fit,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.hide_image_outlined, color: colors.ink2),
                )
              else
                CachedNetworkImage(
                  imageUrl: url,
                  fit: fit,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) =>
                      Icon(Icons.hide_image_outlined, color: colors.ink2),
                ),
              if (label != null)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.cream.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          label!,
                          style: GuideType.muted(colors, size: 12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SpeciesTile extends StatelessWidget {
  final String title;
  final bool titleLatin;
  final String latin;
  final String third;
  final bool thirdSpoken;
  final String imageUrl;
  final VoidCallback onTap;

  const SpeciesTile({
    super.key,
    required this.title,
    required this.titleLatin,
    required this.latin,
    required this.third,
    required this.thirdSpoken,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final nameStyle = titleLatin
        ? GuideType.latin(colors, size: 20)
        : GuideType.spoken(colors, size: 20);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 96,
                child: GuidePhoto(url: imageUrl),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: nameStyle),
                  if (!titleLatin)
                    Text(latin, style: GuideType.latin(colors, size: 15)),
                  if (third.isNotEmpty)
                    Text(
                      third,
                      style: GuideType.muted(colors).copyWith(
                        fontStyle: thirdSpoken
                            ? FontStyle.normal
                            : FontStyle.italic,
                        fontFamily: thirdSpoken
                            ? GuideType.sans
                            : GuideType.display,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpeciesRow extends StatelessWidget {
  final Catalog catalog;
  final Species species;
  final VoidCallback onTap;

  const SpeciesRow({
    super.key,
    required this.catalog,
    required this.species,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = catalog.heading(species);
    final family = species.family.isEmpty
        ? ''
        : catalog.taxonTitle(species.family);
    final familySpoken = family.isNotEmpty && family != species.family;
    return SpeciesTile(
      title: title,
      titleLatin: title == species.name,
      latin: species.name,
      third: family,
      thirdSpoken: familySpoken,
      imageUrl: cardPlate(species.illustrationUrl),
      onTap: onTap,
    );
  }
}

class CatalogMessage extends StatelessWidget {
  final Copy copy;
  final Object? error;
  final VoidCallback onRetry;

  const CatalogMessage({
    super.key,
    required this.copy,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final denied = catalogDenied(error ?? '');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            denied ? copy.catalogClosed : copy.catalogError,
            style: GuideType.body(colors),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: Text(copy.retry)),
        ],
      ),
    );
  }
}

class KeyStepLine extends StatelessWidget {
  final String step;
  final String free;

  const KeyStepLine({super.key, required this.step, required this.free});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final stepStyle = GuideType.eyebrow(colors);
    final freeStyle = stepStyle.copyWith(color: colors.moss);
    return Row(
      children: [
        Flexible(
          child: Text(
            step.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stepStyle,
          ),
        ),
        const SizedBox(width: 8),
        Text(free.toUpperCase(), maxLines: 1, style: freeStyle),
      ],
    );
  }
}

class KeyStepper extends StatelessWidget {
  final int filled;
  final int steps;

  const KeyStepper({super.key, required this.filled, required this.steps});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Row(
      children: [
        for (var i = 0; i < steps; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: i < filled ? colors.madder : colors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(height: 3),
            ),
          ),
        ],
      ],
    );
  }
}

class KeyChoice extends StatelessWidget {
  final String label;
  final String example;
  final int count;
  final bool selected;
  final bool enabled;
  final Widget? mark;
  final VoidCallback? onTap;

  const KeyChoice({
    super.key,
    required this.label,
    required this.example,
    required this.count,
    required this.selected,
    required this.enabled,
    this.mark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final fill = selected ? colors.moss : colors.cream;
    final ink = selected ? colors.onMoss : colors.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? colors.moss : colors.rule),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: enabled ? 1 : 0.38,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (mark != null) ...[mark!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: GuideType.sans,
                            fontSize: 17,
                            color: ink,
                          ),
                        ),
                        if (example.isNotEmpty)
                          Text(
                            example,
                            style: TextStyle(
                              fontFamily: GuideType.sans,
                              fontSize: 13,
                              color: selected ? colors.onMoss : colors.ink2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 16,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Find, Book, and Seen. The banner sits above the bar.
///
/// [index] is null on a page pushed over the shell, so no tab is selected.
class GuideBottomBar extends StatelessWidget {
  final int? index;
  final ValueChanged<int> onSelect;
  final bool showAd;

  /// Account is open. None of Find, Book, or Seen is that page.
  final bool personOn;

  const GuideBottomBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.showAd,
    this.personOn = false,
  });

  @override
  Widget build(BuildContext context) {
    final copy = GuideScope.of(context).copy;
    final open = index == null || personOn;
    final scheme = Theme.of(context).colorScheme;
    final bar = NavigationBar(
      selectedIndex: index ?? 0,
      indicatorColor: open ? Colors.transparent : null,
      onDestinationSelected: onSelect,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.center_focus_weak),
          label: copy.find,
        ),
        NavigationDestination(
          icon: const Icon(Icons.menu_book_outlined),
          label: copy.book,
        ),
        NavigationDestination(
          icon: const Icon(Icons.article_outlined),
          label: copy.seen,
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAd) const AppBannerAd(pinned: true),
        if (open)
          NavigationBarTheme(
            data: NavigationBarTheme.of(context).copyWith(
              indicatorColor: Colors.transparent,
              iconTheme: WidgetStatePropertyAll(
                IconThemeData(size: 24, color: scheme.onSurfaceVariant),
              ),
            ),
            child: bar,
          )
        else
          bar,
      ],
    );
  }
}

/// Landscape sidebar plus the page. Phone and iPad portrait return [child].
Widget guideWithRail(
  BuildContext context, {
  required Widget child,
  bool personOn = false,
  bool showAd = false,
  ValueChanged<int>? onSelect,
}) {
  if (!GuideWindow.of(context).wide) return child;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GuideSideRail(
        personOn: personOn,
        onSelect: onSelect ?? (index) => guideRailSelect(context, index),
        onPerson: () => guideRailPerson(context),
      ),
      Expanded(
        child: Column(
          children: [
            Expanded(child: child),
            if (showAd) const AppBannerAd(pinned: true),
          ],
        ),
      ),
    ],
  );
}

/// Phone tabs stay on the bottom. A wide window uses the leading rail.
///
/// A side status column keeps Find, Book, and Seen in that column. The
/// content column drops that side's inset so a nested [SafeArea] does not
/// pad it a second time.
Widget guideChromeFrame(
  BuildContext context, {
  required Widget child,
  required int? index,
  required ValueChanged<int> onSelect,
  bool tabs = true,
  bool showAd = false,
  bool personOn = false,
}) {
  final wide = GuideWindow.of(context).wide;
  final chrome = GuideChrome.of(context);
  if (chrome.vertical) {
    if (!tabs) {
      return Scaffold(body: SafeArea(child: child));
    }
    final media = MediaQuery.of(context);
    final padding = chrome.onRight
        ? media.padding.copyWith(right: 0)
        : media.padding.copyWith(left: 0);
    final viewPadding = chrome.onRight
        ? media.viewPadding.copyWith(right: 0)
        : media.viewPadding.copyWith(left: 0);
    final content = MediaQuery(
      data: media.copyWith(padding: padding, viewPadding: viewPadding),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(child: child),
            if (showAd) const AppBannerAd(pinned: true),
          ],
        ),
      ),
    );
    final column = _GuideSideTabs(
      index: index,
      personOn: personOn,
      side: chrome.side,
      onRight: chrome.onRight,
      onSelect: onSelect,
    );
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: chrome.onRight
            ? [Expanded(child: content), column]
            : [column, Expanded(child: content)],
      ),
    );
  }
  return Scaffold(
    body: SafeArea(
      // Phone tabs pad the navigation-bar inset. A wide screen, and a page
      // without tabs, pads it here so the banner stays above the bar.
      bottom: wide || !tabs,
      child: guideWithRail(
        context,
        personOn: personOn,
        showAd: wide && showAd,
        onSelect: onSelect,
        child: child,
      ),
    ),
    bottomNavigationBar: wide || !tabs
        ? null
        : GuideBottomBar(
            index: index,
            personOn: personOn,
            showAd: showAd,
            onSelect: onSelect,
          ),
  );
}

/// Centers a bottom sheet as a card on a tablet. The phone sheet is unchanged.
Widget guideSheetAlign(BuildContext context, Widget sheet) {
  if (!GuideWindow.of(context).tablet) return sheet;
  return LayoutBuilder(
    builder: (context, constraints) {
      final spare = constraints.maxWidth - 64;
      final card = spare < 520 ? spare : 520.0;
      final limit = constraints.maxHeight * 0.88;
      final maxHeight = !constraints.maxHeight.isFinite
          ? 680.0
          : (limit < 680 ? limit : 680.0);
      return Center(
        child: SizedBox(
          width: card < 1 ? constraints.maxWidth : card,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: sheet,
          ),
        ),
      );
    },
  );
}

bool _tabOn(int tab, int? index, bool personOn) =>
    !personOn && index != null && tab == index;

/// Find, Book, and Seen in the side status column.
class _GuideSideTabs extends StatelessWidget {
  final int? index;
  final bool personOn;
  final double side;
  final bool onRight;
  final ValueChanged<int> onSelect;

  const _GuideSideTabs({
    required this.index,
    required this.side,
    required this.onRight,
    required this.onSelect,
    this.personOn = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = [
      (copy.find, Icons.center_focus_weak),
      (copy.book, Icons.menu_book_outlined),
      (copy.seen, Icons.article_outlined),
    ];
    final rule = BorderSide(color: colors.rule);
    return DecoratedBox(
      key: const Key('guide-side-tabs'),
      decoration: BoxDecoration(
        color: colors.cream,
        border: Border(
          left: onRight ? rule : BorderSide.none,
          right: onRight ? BorderSide.none : rule,
        ),
      ),
      child: SizedBox(
        width: side,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  _RailButton(
                    label: items[i].$1,
                    icon: items[i].$2,
                    selected: _tabOn(i, index, personOn),
                    tabIndex: i,
                    onPressed: () => onSelect(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Find, Book, and Seen down the side, with Person at the bottom.
class GuideSideRail extends StatelessWidget {
  final bool personOn;
  final ValueChanged<int> onSelect;
  final VoidCallback onPerson;

  const GuideSideRail({
    super.key,
    required this.personOn,
    required this.onSelect,
    required this.onPerson,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final items = [
      (0, copy.find, Icons.center_focus_weak),
      (1, copy.book, Icons.menu_book_outlined),
      (2, copy.seen, Icons.article_outlined),
    ];
    return DecoratedBox(
      key: const Key('guide-side-rail'),
      decoration: BoxDecoration(
        color: colors.cream,
        border: BorderDirectional(end: BorderSide(color: colors.rule)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: 104,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final item in items)
                  _RailButton(
                    label: item.$2,
                    icon: item.$3,
                    selected: _tabOn(item.$1, GuideTabs.index, personOn),
                    tabIndex: item.$1,
                    onPressed: () => onSelect(item.$1),
                  ),
                const Spacer(),
                _RailButton(
                  label: copy.person,
                  icon: Icons.person_outline,
                  selected: personOn,
                  onPressed: onPerson,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int? tabIndex;
  final VoidCallback onPressed;

  const _RailButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.tabIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final color = selected ? colors.moss : colors.ink3;
    final button = InkWell(
      onTap: onPressed,
      excludeFromSemantics: tabIndex != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            _RailIcon(icon: icon, color: color, selected: selected),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
    final index = tabIndex;
    if (index == null) return button;
    return _TabSemantics(
      label: label,
      index: index,
      selected: selected,
      onPressed: onPressed,
      child: button,
    );
  }
}

class _RailIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;

  const _RailIcon({
    required this.icon,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 64, maxHeight: 32),
      child: SizedBox(
        width: double.infinity,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (selected)
              Positioned.fill(
                child: DecoratedBox(
                  key: const Key('guide-tab-indicator'),
                  decoration: BoxDecoration(
                    color: colors.paper2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            Icon(icon, size: 24, color: color),
          ],
        ),
      ),
    );
  }
}

/// The visible word stays [label]. Screen readers also hear which tab this is.
class _TabSemantics extends StatelessWidget {
  final String label;
  final int index;
  final bool selected;
  final VoidCallback onPressed;
  final Widget child;

  const _TabSemantics({
    required this.label,
    required this.index,
    required this.selected,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final place = MaterialLocalizations.of(context)
        .tabLabel(tabIndex: index + 1, tabCount: 3);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $place',
      child: child,
    );
  }
}
