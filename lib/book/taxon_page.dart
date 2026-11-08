import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/book/list_chrome.dart';
import 'package:whats_that_mushroom/camera/open_camera.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/guide_window.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

/// Column count for a family or genus grid. A phone uses two. A tablet in
/// portrait uses three, and a landscape tablet uses four.
int taxonGridColumns(Size size) => GuideWindow.photoColumns(size);

/// A family or genus, on the same page as the plants result list.
///
/// The title, the large count, and a photo grid split by the current month.
/// The key's filters and the banner stay off.
class TaxonPage extends StatefulWidget {
  final String kind;
  final String name;
  final String? backLabel;

  /// Where a species opened from this list was reached. A photo that named
  /// only the genus uses [GuideMushroomSource.photo].
  final String speciesSource;
  final Future<void> Function(BuildContext context)? onTryPhoto;

  const TaxonPage({
    super.key,
    required this.kind,
    required this.name,
    this.backLabel,
    this.speciesSource = GuideMushroomSource.list,
    this.onTryPhoto,
  });

  @override
  State<TaxonPage> createState() => _TaxonPageState();
}

class _TaxonPageState extends State<TaxonPage> {
  var _plates = false;

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final back = widget.backLabel?.trim();
    final backLabel = back == null || back.isEmpty ? copy.back : back;
    final catalog = scope.catalog.data;
    if (catalog == null) {
      return Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          child: Column(
            children: [
              _BackButton(label: backLabel),
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
    final title = catalog.taxonTitle(widget.name);
    final showLatin =
        widget.name.isNotEmpty &&
        widget.name.toLowerCase() != title.toLowerCase();
    final month = DateTime.now().month;
    final rows = catalog.speciesIn(widget.kind, widget.name);
    int byName(Species a, Species b) =>
        catalog.compareTitles(catalog.heading(a), catalog.heading(b));
    final now = [
      for (final item in rows)
        if (item.fruitsIn(month)) item,
    ]..sort(byName);
    final later = [
      for (final item in rows)
        if (!item.fruitsIn(month)) item,
    ]..sort(byName);
    final showLater = now.isNotEmpty && later.isNotEmpty;
    final seen = {
      for (final find in scope.notebook.finds)
        if (find.latin != null) find.latin!,
    };
    final seenCount = rows.where((item) => seen.contains(item.name)).length;
    final caption = seenCount > 0
        ? '${copy.countNoun(rows.length)} · ${copy.youHaveSeen(seenCount)}'
        : copy.countNoun(rows.length);
    final columns = taxonGridColumns(MediaQuery.sizeOf(context));
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackButton(label: backLabel),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: GuideType.display,
                            fontWeight: FontWeight.w500,
                            fontSize: 28,
                            height: 1.1,
                            color: colors.ink,
                          ),
                        ),
                        if (showLatin)
                          Text(
                            widget.name,
                            style: GuideType.latin(colors).copyWith(
                              fontSize: 15,
                              height: 1.3,
                              color: colors.ink3,
                            ),
                          ),
                        const SizedBox(height: 10),
                        _CountLine(count: rows.length, caption: caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (rows.isNotEmpty) ...[
                    _section(
                      now.isEmpty ? '' : copy.fruitingNowLine(now.length),
                      controls: true,
                    ),
                    ..._grid(
                      catalog,
                      showLater ? now : [...now, ...later],
                      seen,
                      columns,
                    ),
                    if (showLater) ...[
                      _section(
                        copy.otherMonthsLine(later.length),
                        controls: false,
                      ),
                      ..._grid(catalog, later, seen, columns),
                    ],
                  ],
                  _footer(copy, colors),
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
            _ViewSwitch(
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

  List<Widget> _grid(
    Catalog catalog,
    List<Species> species,
    Set<String> seen,
    int columns,
  ) {
    final copy = GuideScope.of(context).copy;
    final rows = <Widget>[];
    for (var i = 0; i < species.length; i += columns) {
      final end = i + columns > species.length ? species.length : i + columns;
      rows.add(
        speciesGridRow(
          columns: columns,
          cells: [
            for (final item in species.sublist(i, end))
              SpeciesCell(
                key: Key('taxon-${item.name}'),
                species: item,
                title: catalog.heading(item),
                titleIsLatin: catalog.heading(item) == item.name,
                plates: _plates,
                seen: seen.contains(item.name),
                seenLabel: copy.seenMark,
                onTap: () => openSpecies(
                  context,
                  item.name,
                  source: widget.speciesSource,
                ),
              ),
          ],
        ),
      );
    }
    return rows;
  }

  Widget _footer(Copy copy, GuideColors colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: GuideType.sans,
            fontSize: 13,
            height: 1.4,
            color: colors.ink3,
          ),
          children: [
            TextSpan(text: copy.resultsMissing),
            const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () {
                  final open = widget.onTryPhoto;
                  if (open != null) {
                    open(context);
                    return;
                  }
                  openGuideCamera(context);
                },
                child: Text(
                  copy.searchTryPhoto,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: colors.moss,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

class _BackButton extends StatelessWidget {
  final String label;

  const _BackButton({required this.label});

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

class _ViewSwitch extends StatelessWidget {
  final String photos;
  final String plates;
  final bool platesOn;
  final VoidCallback onPhotos;
  final VoidCallback onPlates;

  const _ViewSwitch({
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
