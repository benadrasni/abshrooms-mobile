import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/ads/app_banner_ad.dart';
import 'package:whats_that_mushroom/book/list_chrome.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/key_filter.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/find/key_glyph.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/review_prompt.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

void _leaveForTab(BuildContext context, int index) {
  GuideScope.of(context).selectTab(index);
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Pop [steps] routes, and stop at the shell if the stack is shorter.
void _popSteps(BuildContext context, int steps) {
  var left = steps;
  Navigator.of(context).popUntil((route) {
    if (route.isFirst || left <= 0) return true;
    left -= 1;
    return false;
  });
}

class WherePage extends StatelessWidget {
  final KeySelection selection;

  const WherePage({super.key, required this.selection});

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    if (catalog == null) {
      return Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          child: Column(
            children: [
              _KeyBack(label: copy.underBack),
              Expanded(
                child: CatalogMessage(
                  copy: copy,
                  error: scope.catalog.error,
                  onRetry: scope.reload,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final counts = optionCounts(catalog.species, selection, 'where');
    final open = selection.copyWith(where: '');
    final anywhereCount = catalog.species
        .where((item) => matchesSelection(item, open))
        .length;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            _KeyBack(label: copy.underBack),
            if (selection.under.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _FilterPill(
                    label: copy.underLabel(selection.under),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyStepLine(step: copy.keyStepWhere, free: copy.keyFree),
                  const SizedBox(height: 8),
                  const KeyStepper(filled: 2, steps: 3),
                  const SizedBox(height: 12),
                  Text(copy.whereQuestion, style: GuideType.question(colors)),
                  const SizedBox(height: 14),
                  _WideOption(
                    label: copy.anyWhere,
                    count: anywhereCount,
                    enabled: anywhereCount > 0,
                    onTap: () => _open(context, ''),
                  ),
                  const SizedBox(height: 8),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < whereChoices.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _WherePill(
                              id: whereChoices[i],
                              label: copy.whereLabel(whereChoices[i]),
                              example: copy.whereExample(whereChoices[i]),
                              count: counts[whereChoices[i]] ?? 0,
                              colors: colors,
                              onTap: (counts[whereChoices[i]] ?? 0) > 0
                                  ? () => _open(context, whereChoices[i])
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GuideBottomBar(
        index: null,
        showAd: Purchases.showsAds(),
        onSelect: (index) => _leaveForTab(context, index),
      ),
    );
  }

  void _open(BuildContext context, String where) {
    final page = ColorPage(selection: selection.copyWith(where: where));
    Navigator.of(context).push(guideRoute(guideScreenColour, (_) => page));
  }
}

class _KeyBack extends StatelessWidget {
  final String label;

  const _KeyBack({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        onTap: () => Navigator.maybePop(context),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: IconThemeData(color: colors.moss, size: 20),
                  child: const BackButtonIcon(),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.moss,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Widget? leading;

  const _FilterPill({
    required this.label,
    required this.onPressed,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final mark = leading;
    return Material(
      color: colors.mossFill,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mark != null) ...[mark, const SizedBox(width: 6)],
                Text(
                  label,
                  style: TextStyle(
                    color: colors.onMoss,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.close, size: 14, color: colors.onMoss),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WideOption extends StatelessWidget {
  final String label;
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  const _WideOption({
    required this.label,
    required this.count,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Material(
        color: colors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.rule),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 4,
                end: 5,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 12,
                    color: colors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WherePill extends StatelessWidget {
  final String id;
  final String label;
  final String example;
  final int count;
  final GuideColors colors;
  final VoidCallback? onTap;

  const _WherePill({
    required this.id,
    required this.label,
    required this.example,
    required this.count,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.38 : 1,
      child: Material(
        color: colors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.rule),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KeyGlyph(id: id, color: colors.moss, size: 40),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          height: 1.2,
                          color: colors.ink,
                        ),
                      ),
                      if (example.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          example,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: GuideType.sans,
                            fontSize: 12,
                            height: 1.3,
                            color: colors.ink2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                top: 4,
                end: 5,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 12,
                    color: colors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ColorPage extends StatelessWidget {
  final KeySelection selection;

  const ColorPage({super.key, required this.selection});

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    if (catalog == null) {
      return Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          child: Column(
            children: [
              _KeyBack(label: copy.whereBack),
              Expanded(
                child: CatalogMessage(
                  copy: copy,
                  error: scope.catalog.error,
                  onRetry: scope.reload,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final counts = optionCounts(catalog.species, selection, 'color');
    final anyColor = selection.copyWith(color: '');
    final anyCount = catalog.species
        .where((item) => matchesSelection(item, anyColor))
        .length;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            _KeyBack(label: copy.whereBack),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (selection.under.isNotEmpty)
                    _FilterPill(
                      label: copy.underLabel(selection.under),
                      onPressed: () =>
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                    ),
                  if (selection.where.isNotEmpty)
                    _FilterPill(
                      label: copy.whereLabel(selection.where),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyStepLine(step: copy.keyStepColor, free: copy.keyFree),
                  const SizedBox(height: 8),
                  const KeyStepper(filled: 3, steps: 3),
                  const SizedBox(height: 12),
                  Text(copy.colorQuestion, style: GuideType.question(colors)),
                  const SizedBox(height: 6),
                  Text(copy.colorNote, style: GuideType.muted(colors)),
                  const SizedBox(height: 14),
                  _WideOption(
                    label: copy.anyColor,
                    count: anyCount,
                    enabled: anyCount > 0,
                    onTap: () => _open(context, ''),
                  ),
                  const SizedBox(height: 8),
                  _ColorGrid(
                    copy: copy,
                    colors: colors,
                    counts: counts,
                    onOpen: (id) => _open(context, id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GuideBottomBar(
        index: null,
        showAd: Purchases.showsAds(),
        onSelect: (index) => _leaveForTab(context, index),
      ),
    );
  }

  void _open(BuildContext context, String color) {
    final page = ResultsPage(selection: selection.copyWith(color: color));
    Navigator.of(context).push(guideRoute(guideScreenResults, (_) => page));
  }
}

class _ColorGrid extends StatelessWidget {
  final Copy copy;
  final GuideColors colors;
  final Map<String, int> counts;
  final ValueChanged<String> onOpen;

  const _ColorGrid({
    required this.copy,
    required this.colors,
    required this.counts,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    const columns = 4;
    final rows = (colorChoices.length + columns - 1) ~/ columns;
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: 8),
                  Expanded(child: _cell(row * columns + column)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cell(int index) {
    if (index >= colorChoices.length) return const SizedBox.shrink();
    final id = colorChoices[index];
    final count = counts[id] ?? 0;
    return _ColorPill(
      id: id,
      label: copy.colorLabel(id),
      count: count,
      colors: colors,
      onTap: count > 0 ? () => onOpen(id) : null,
    );
  }
}

class _ColorPill extends StatelessWidget {
  final String id;
  final String label;
  final int count;
  final GuideColors colors;
  final VoidCallback? onTap;

  const _ColorPill({
    required this.id,
    required this.label,
    required this.count,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.38 : 1,
      child: Material(
        color: colors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.rule),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ColorSwatch(id: id, colors: colors),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          height: 1.2,
                          color: colors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                top: 4,
                end: 5,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 12,
                    color: colors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String id;
  final GuideColors colors;

  const _ColorSwatch({required this.id, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorSwatch(id),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.rule),
      ),
    );
  }
}

class ResultsPage extends StatefulWidget {
  final KeySelection selection;

  const ResultsPage({super.key, required this.selection});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late KeySelection _selection = widget.selection;
  var _seasonOpen = false;
  var _plates = false;
  var _reviewNoted = false;
  String? _filterStamp;

  /// The page is still the one on screen. A mushroom pushed on top, or a
  /// page the person already left, is not a place for the sheet.
  bool _reviewStillHere() {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  /// The key's list is on screen. An empty list is not a finished key.
  void _noteKeySuccess(int count) {
    if (_reviewNoted || count <= 0) return;
    _reviewNoted = true;
    unawaited(ReviewPrompt.note(stillHere: _reviewStillHere));
  }

  void _noteFilter(int count) {
    final stamp =
        '${_selection.under}|${_selection.where}|${_selection.color}|${_selection.season}|$count';
    if (_filterStamp == stamp) return;
    _filterStamp = stamp;
    unawaited(
      GuideAnalytics.filterResult(
        under: _selection.under,
        where: _selection.where,
        color: _selection.color,
        count: count,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    if (catalog == null) {
      return Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          child: Column(
            children: [
              _KeyBack(label: copy.colorBack),
              Expanded(
                child: CatalogMessage(
                  copy: copy,
                  error: scope.catalog.error,
                  onRetry: scope.reload,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final month = DateTime.now().month;
    final matches = [
      for (final item in catalog.species)
        if (matchesSelection(item, _selection)) item,
    ];
    _noteFilter(matches.length);
    _noteKeySuccess(matches.length);
    int byName(Species a, Species b) =>
        catalog.compareTitles(catalog.heading(a), catalog.heading(b));
    final now = [
      for (final item in matches)
        if (item.fruitsIn(month)) item,
    ]..sort(byName);
    final later = [
      for (final item in matches)
        if (!item.fruitsIn(month)) item,
    ]..sort(byName);
    final showLater = now.isNotEmpty && later.isNotEmpty;
    final seen = {
      for (final find in scope.notebook.finds)
        if (find.latin != null) find.latin!,
    };
    final seenCount = matches.where((item) => seen.contains(item.name)).length;
    final seasonCounts = optionCounts(catalog.species, _selection, 'season');
    final anyCount = catalog.species
        .where(
          (item) => matchesSelection(item, _selection.copyWith(season: '')),
        )
        .length;
    final seasonLabel = _selection.season.isEmpty
        ? copy.anySeason
        : copy.seasonLabel(_selection.season);
    final caption = seenCount > 0
        ? '${copy.countNoun(matches.length)} · ${copy.youHaveSeen(seenCount)}'
        : copy.countNoun(matches.length);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KeyBack(label: copy.colorBack),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_selection.under.isNotEmpty)
                          _FilterPill(
                            label: copy.underLabel(_selection.under),
                            onPressed: () =>
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                          ),
                        if (_selection.where.isNotEmpty)
                          _FilterPill(
                            label: copy.whereLabel(_selection.where),
                            onPressed: () => _popSteps(context, 2),
                          ),
                        if (_selection.color.isNotEmpty)
                          _FilterPill(
                            label: copy.colorLabel(_selection.color),
                            leading: _FilterDot(id: _selection.color),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CountLine(count: matches.length, caption: caption),
                        const SizedBox(height: 12),
                        _SeasonToggle(
                          label: seasonLabel,
                          selected: _selection.season.isNotEmpty,
                          open: _seasonOpen,
                          onPressed: () =>
                              setState(() => _seasonOpen = !_seasonOpen),
                        ),
                        if (_seasonOpen) ...[
                          const SizedBox(height: 8),
                          _SeasonPanel(
                            copy: copy,
                            selected: _selection.season,
                            anyCount: anyCount,
                            counts: seasonCounts,
                            onSelect: (id) => setState(() {
                              _selection = id.isEmpty
                                  ? _selection.copyWith(season: '')
                                  : _selection.toggle('season', id);
                              _seasonOpen = false;
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (matches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Text(
                        copy.keyEmpty,
                        style: GuideType.body(colors),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    _section(
                      now.isEmpty ? '' : copy.fruitingNowLine(now.length),
                      controls: true,
                    ),
                    ..._grid(
                      catalog,
                      showLater ? now : [...now, ...later],
                      seen,
                    ),
                    if (showLater) ...[
                      _section(
                        copy.otherMonthsLine(later.length),
                        controls: false,
                      ),
                      ..._grid(catalog, later, seen),
                    ],
                  ],
                  if (Purchases.showsAds()) const AppBannerAd(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label, {required bool controls}) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: GuideType.sans,
                fontSize: 12,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: colors.ink3,
              ),
            ),
          ),
          if (controls)
            _ResultSwitch(
              photos: copy.photos,
              plates: copy.plates,
              platesOn: _plates,
              onPhotos: () => setState(() => _plates = false),
              onPlates: () => setState(() => _plates = true),
            ),
        ],
      ),
    );
  }

  List<Widget> _grid(Catalog catalog, List<Species> species, Set<String> seen) {
    final copy = GuideScope.of(context).copy;
    final rows = <Widget>[];
    for (var i = 0; i < species.length; i += 2) {
      final end = i + 2 > species.length ? species.length : i + 2;
      rows.add(
        speciesGridRow(
          columns: 2,
          cells: [
            for (final item in species.sublist(i, end))
              SpeciesCell(
                species: item,
                title: catalog.heading(item),
                titleIsLatin: catalog.heading(item) == item.name,
                plates: _plates,
                seen: seen.contains(item.name),
                seenLabel: copy.seenMark,
                onTap: () => openSpecies(
                  context,
                  item.name,
                  source: GuideMushroomSource.key,
                ),
              ),
          ],
        ),
      );
    }
    return rows;
  }
}

class _CountLine extends StatelessWidget {
  final int count;
  final String caption;

  const _CountLine({required this.count, required this.caption});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Text.rich(
      TextSpan(
        text: '$count',
        style: TextStyle(
          fontFamily: GuideType.display,
          fontWeight: FontWeight.w500,
          fontSize: 30,
          letterSpacing: -0.6,
          height: 1,
          color: colors.ink,
        ),
        children: [
          TextSpan(
            text: ' $caption',
            style: TextStyle(
              fontFamily: GuideType.sans,
              fontWeight: FontWeight.w400,
              fontSize: 14,
              letterSpacing: 0,
              height: 1.3,
              color: colors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final bool open;
  final VoidCallback onPressed;

  const _SeasonToggle({
    required this.label,
    required this.selected,
    required this.open,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final foreground = selected ? colors.onMoss : colors.ink;
    return Material(
      color: selected ? colors.mossFill : colors.cream,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? colors.mossFill : colors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
          child: SizedBox(
            height: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                Transform.rotate(
                  angle: open ? pi : 0,
                  child: Icon(Icons.expand_more, size: 16, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonPanel extends StatelessWidget {
  final Copy copy;
  final String selected;
  final int anyCount;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;

  const _SeasonPanel({
    required this.copy,
    required this.selected,
    required this.anyCount,
    required this.counts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final rows = [
      for (final id in seasonChoices)
        if (selected == id || (counts[id] ?? 0) > 0) id,
    ];
    return Material(
      color: colors.paper,
      elevation: 8,
      shadowColor: const Color(0x1F1A1612),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.rule),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.seasonQuestion,
              style: GuideType.spoken(colors, size: 23),
            ),
            const SizedBox(height: 6),
            Text(copy.seasonNote, style: GuideType.muted(colors)),
            const SizedBox(height: 4),
            _SeasonRow(
              label: copy.anySeason,
              count: anyCount,
              selected: selected.isEmpty,
              onTap: () => onSelect(''),
            ),
            for (final id in rows)
              _SeasonRow(
                label: copy.seasonLabel(id),
                count: counts[id] ?? 0,
                selected: selected == id,
                onTap: () => onSelect(id),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeasonRow extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SeasonRow({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.rule)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? colors.moss : colors.ink3,
                    width: selected ? 6 : 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 15,
                    color: colors.ink,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 13,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDot extends StatelessWidget {
  final String id;

  const _FilterDot({required this.id});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: colorSwatch(id),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x66FFFFFF)),
      ),
    );
  }
}

class _ResultSwitch extends StatelessWidget {
  final String photos;
  final String plates;
  final bool platesOn;
  final VoidCallback onPhotos;
  final VoidCallback onPlates;

  const _ResultSwitch({
    required this.photos,
    required this.plates,
    required this.platesOn,
    required this.onPhotos,
    required this.onPlates,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cream,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(photos, !platesOn, onPhotos, colors),
          _segment(plates, platesOn, onPlates, colors),
        ],
      ),
    );
  }

  Widget _segment(
    String label,
    bool on,
    VoidCallback onPressed,
    GuideColors colors,
  ) {
    return Material(
      color: on ? colors.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: SizedBox(
            height: 28,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: on ? colors.paper : colors.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
