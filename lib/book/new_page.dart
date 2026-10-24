import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/new_book.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

const _plateGround = Color(0xFFF1E8D6);

/// New in the book: the latest species, grouped by the day they were added.
class NewPage extends StatefulWidget {
  const NewPage({super.key});

  @override
  State<NewPage> createState() => _NewPageState();
}

class _NewPageState extends State<NewPage> {
  bool _plates = false;

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final catalog = scope.catalog.data;
    final days = catalog == null
        ? const <NewDay>[]
        : newInBook(catalog.species);
    final seen = {
      for (final find in scope.notebook.finds)
        if (find.latin != null) find.latin!,
    };
    var seenCount = 0;
    for (final day in days) {
      for (final species in day.species) {
        if (seen.contains(species.name)) seenCount += 1;
      }
    }
    return _ListChrome(
      copy: scope.copy,
      countLine: days.isEmpty ? '' : scope.copy.newAdded(newBookCount(days)),
      seenCount: seenCount,
      plates: _plates,
      showSwitch: days.isNotEmpty,
      onPhotos: () => setState(() => _plates = false),
      onPlates: () => setState(() => _plates = true),
      body: _body(context, catalog, days, seen),
    );
  }

  List<Widget> _body(
    BuildContext context,
    Catalog? catalog,
    List<NewDay> days,
    Set<String> seen,
  ) {
    if (catalog == null || days.isEmpty) return const [];
    final rows = <Widget>[];
    final pending = <Species>[];
    void flush() {
      if (pending.isEmpty) return;
      rows.add(
        _gridRow([for (final species in pending) species], seen, catalog),
      );
      pending.clear();
    }

    for (final day in days) {
      if (day.species.isEmpty) continue;
      flush();
      rows.add(_DateHeader(day: day, first: rows.isEmpty));
      for (final species in day.species) {
        pending.add(species);
        if (pending.length == 2) flush();
      }
    }
    flush();
    return rows;
  }

  Widget _gridRow(List<Species> species, Set<String> seen, Catalog catalog) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: i < species.length
                  ? _SpeciesCell(
                      catalog: catalog,
                      species: species[i],
                      plates: _plates,
                      seen: seen.contains(species[i].name),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListChrome extends StatelessWidget {
  final Copy copy;
  final String countLine;
  final int seenCount;
  final bool plates;
  final bool showSwitch;
  final VoidCallback onPhotos;
  final VoidCallback onPlates;
  final List<Widget> body;

  const _ListChrome({
    required this.copy,
    required this.countLine,
    required this.seenCount,
    required this.plates,
    required this.showSwitch,
    required this.onPhotos,
    required this.onPlates,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final meta = seenCount > 0
        ? '$countLine · ${copy.youHaveSeen(seenCount)}'
        : countLine;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackButton(label: copy.find),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.listsTitle.toUpperCase(),
                          style: GuideType.eyebrow(colors),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          copy.newInBook,
                          style: TextStyle(
                            fontFamily: GuideType.display,
                            fontWeight: FontWeight.w500,
                            fontSize: 30,
                            height: 1.05,
                            letterSpacing: -0.4,
                            color: colors.ink,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            meta,
                            style: TextStyle(
                              fontFamily: GuideType.sans,
                              fontSize: 14,
                              height: 1.3,
                              color: colors.ink2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showSwitch)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _ViewSwitch(
                      photos: copy.photos,
                      plates: copy.plates,
                      platesOn: plates,
                      onPhotos: onPhotos,
                      onPlates: onPlates,
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverList(delegate: SliverChildListDelegate(body)),
            ),
          ],
        ),
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

class _DateHeader extends StatelessWidget {
  final NewDay day;
  final bool first;

  const _DateHeader({required this.day, required this.first});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final word = newDayWord(
      day.date,
      DateTime.now(),
      today: copy.today,
      yesterday: copy.yesterday,
    );
    final label =
        word ?? MaterialLocalizations.of(context).formatMediumDate(day.date);
    return Padding(
      padding: EdgeInsets.only(top: first ? 4 : 10, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 12,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
          color: colors.ink2,
        ),
      ),
    );
  }
}

class _SpeciesCell extends StatelessWidget {
  final Catalog catalog;
  final Species species;
  final bool plates;
  final bool seen;

  const _SpeciesCell({
    required this.catalog,
    required this.species,
    required this.plates,
    required this.seen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final heading = catalog.heading(species);
    final spoken = heading != species.name;
    final url = plates
        ? cardPlate(species.illustrationUrl)
        : speciesPhoto(species);
    return InkWell(
      onTap: () => openSpecies(context, species.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: plates ? 2 / 3 : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: plates ? _plateGround : colors.paper2,
                child: url.isEmpty
                    ? const SizedBox.expand()
                    : GuidePhoto(
                        url: url,
                        fit: plates ? BoxFit.contain : BoxFit.cover,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            spoken ? heading : species.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: spoken
                ? TextStyle(
                    fontFamily: GuideType.display,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    height: 1.15,
                    color: colors.ink,
                  )
                : GuideType.latin(colors).copyWith(fontSize: 16, height: 1.15),
          ),
          if (spoken)
            Text(
              species.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GuideType.latin(colors)
                  .copyWith(fontSize: 13, height: 1.2, color: colors.ink2),
            ),
          if (seen)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                copy.seenMark,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.moss,
                ),
              ),
            ),
        ],
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

/// A field photo when the book has one, otherwise the card plate.
String speciesPhoto(Species species) {
  if (species.photoUrls.isNotEmpty) return mediaUrl(species.photoUrls.first);
  return cardPlate(species.illustrationUrl);
}
