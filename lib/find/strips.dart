import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/book/favorites_page.dart';
import 'package:whats_that_mushroom/book/new_page.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/new_book.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/lists/curated_list_page.dart';
import 'package:whats_that_mushroom/seen/sighting_storage.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 12, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: GuideType.section(colors))),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colors.moss,
                textStyle: const TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

class SeenStrip extends StatelessWidget {
  final Copy copy;
  final Catalog catalog;
  final List<FindRecord> finds;
  final VoidCallback onOpenSeen;

  const SeenStrip({
    super.key,
    required this.copy,
    required this.catalog,
    required this.finds,
    required this.onOpenSeen,
  });

  @override
  Widget build(BuildContext context) {
    const edge = 118.0;
    return SizedBox(
      height: _stripHeight(context, edge),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: finds.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _card(context, finds[index], edge),
      ),
    );
  }

  double _stripHeight(BuildContext context, double width) {
    final colors = GuideColors.of(context);
    var tallest = 0.0;
    for (final find in finds) {
      final species = find.latin == null ? null : catalog.byName(find.latin!);
      final title = _title(find, species);
      final spoken =
          species != null && catalog.heading(species) != species.name;
      final name = _blockHeight(
        context,
        text: title,
        style: _nameStyle(colors, spoken: spoken),
        width: width,
        maxLines: 2,
      );
      final date = _blockHeight(
        context,
        text: _when(context, find.millis),
        style: _dateStyle(colors),
        width: width,
        maxLines: 1,
      );
      final height = width + 6 + name + 2 + date;
      if (height > tallest) tallest = height;
    }
    // Text on the phone rounds a line up past the painter. The extra
    // pixels keep the date from clipping.
    return tallest + 8;
  }

  Widget _card(BuildContext context, FindRecord find, double edge) {
    final colors = GuideColors.of(context);
    final species = find.latin == null ? null : catalog.byName(find.latin!);
    final title = _title(find, species);
    final spoken = species != null && title != species.name;
    return SizedBox(
      width: edge,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: species == null
              ? onOpenSeen
              : () => openSpecies(
                  context,
                  species.name,
                  source: GuideMushroomSource.seen,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _SightPhoto(
                    path: find.photoPath,
                    cover: species == null
                        ? ''
                        : cardPlate(species.illustrationUrl),
                    edge: edge,
                  ),
                  if (!find.confirmed)
                    PositionedDirectional(
                      start: 6,
                      top: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.madder,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          child: Text(
                            copy.toConfirm,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _nameStyle(colors, spoken: spoken),
              ),
              const SizedBox(height: 2),
              Text(
                _when(context, find.millis),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _dateStyle(colors),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _title(FindRecord find, Species? species) {
    if (species != null) return catalog.heading(species);
    final outside = find.outsideName?.trim() ?? '';
    if (outside.isNotEmpty) return outside;
    return find.latin ?? '';
  }
}

class ListStrip extends StatelessWidget {
  final Copy copy;
  final Catalog catalog;
  final List<Species> favorites;
  final List<NewDay> fresh;
  final List<CuratedListView> curated;

  const ListStrip({
    super.key,
    required this.copy,
    required this.catalog,
    required this.favorites,
    required this.fresh,
    this.curated = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (favorites.isNotEmpty)
        _cover(
          context,
          title: copy.favoriteMushrooms,
          subtitle: copy.count(favorites.length),
          photo: speciesPhoto(favorites.first),
          gold: false,
          onTap: () => Navigator.of(context).push(
            guideRoute(
              guideScreenFavorites,
              (_) => FavoritesPage(backLabel: copy.find),
            ),
          ),
        ),
      if (fresh.isNotEmpty && fresh.first.species.isNotEmpty)
        _cover(
          context,
          title: copy.newInBook,
          subtitle: copy.latestLine(
            copy.count(newBookCount(fresh)),
            MaterialLocalizations.of(context)
                .formatMediumDate(fresh.first.date),
          ),
          photo: speciesPhoto(fresh.first.species.first),
          gold: true,
          onTap: () =>
              Navigator.of(context)
                  .push(guideRoute(guideScreenNew, (_) => const NewPage())),
        ),
      for (final list in curated)
        _cover(
          context,
          key: Key('curated-card-${list.id}'),
          title: list.title,
          subtitle: _curatedSubtitle(copy, list),
          photo: list.coverPhotoUrl,
          gold: false,
          onTap: () => Navigator.of(context).push(
            guideRoute(
              guideListScreen(list.id),
              (_) => CuratedListPage(list: list, backLabel: copy.find),
            ),
          ),
        ),
    ];
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) => cards[index],
      ),
    );
  }

  Widget _cover(
    BuildContext context, {
    Key? key,
    required String title,
    required String subtitle,
    required String photo,
    required bool gold,
    required VoidCallback onTap,
  }) {
    final colors = GuideColors.of(context);
    return SizedBox(
      key: key,
      width: 150,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: gold
                      ? Border.all(color: colors.gold, width: 2)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 150,
                    height: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (photo.isEmpty)
                          ColoredBox(color: colors.paper2)
                        else
                          GuidePhoto(url: photo, fit: BoxFit.cover),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0x99000000)],
                              stops: [0.45, 1],
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          start: 9,
                          end: 9,
                          bottom: 7,
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: GuideType.display,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 12,
                  height: 1.25,
                  color: colors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SightPhoto extends StatelessWidget {
  final String? path;
  final String cover;
  final double edge;

  const _SightPhoto({
    required this.path,
    required this.cover,
    required this.edge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final stored = path;
    if (stored != null && sightingPhotoIsRemote(stored)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: edge,
          height: edge,
          child: GuidePhoto(
            url: stored,
            fit: BoxFit.cover,
            background: colors.photoWell,
          ),
        ),
      );
    }
    final file = stored == null || stored.isEmpty ? null : File(stored);
    if (file != null && file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: edge,
          height: edge,
          child: Image.file(file, fit: BoxFit.cover),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: edge,
        height: edge,
        child: cover.isEmpty
            ? ColoredBox(color: colors.paper2)
            : GuidePhoto(url: cover, fit: BoxFit.cover),
      ),
    );
  }
}

String _curatedSubtitle(Copy copy, CuratedListView list) {
  final parameter = list.parameter?.trim() ?? '';
  if (parameter.isNotEmpty) return parameter;
  return copy.count(list.entries.length);
}

String _when(BuildContext context, int millis) {
  final when = DateTime.fromMillisecondsSinceEpoch(millis);
  final localizations = MaterialLocalizations.of(context);
  if (when.year != DateTime.now().year)
    return localizations.formatShortDate(when);
  final date = localizations.formatMediumDate(when);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(when));
  return '$date, $time';
}

TextStyle _nameStyle(GuideColors colors, {required bool spoken}) {
  if (spoken) {
    return TextStyle(
      fontFamily: GuideType.sans,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      height: 1.2,
      color: colors.ink,
    );
  }
  return GuideType.latin(colors).copyWith(fontSize: 13, height: 1.2);
}

TextStyle _dateStyle(GuideColors colors) {
  return TextStyle(
    fontFamily: GuideType.sans,
    fontSize: 11,
    color: colors.ink2,
  );
}

double _blockHeight(
  BuildContext context, {
  required String text,
  required TextStyle style,
  required double width,
  required int maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
    ellipsis: '\u2026',
  )..layout(maxWidth: width);
  final height = painter.height;
  painter.dispose();
  return height;
}
