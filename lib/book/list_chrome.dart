import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

const _plateGround = Color(0xFFF1E8D6);

/// Shared list screen: back, eyebrow, title, then the caller's rows.
class ListPageChrome extends StatelessWidget {
  final String backLabel;
  final String eyebrow;
  final String title;
  final String description;
  final String meta;
  final Widget? metaLine;
  final bool plates;
  final bool showSwitch;
  final String photosLabel;
  final String platesLabel;
  final VoidCallback onPhotos;
  final VoidCallback onPlates;
  final List<Widget> body;

  const ListPageChrome({
    super.key,
    required this.backLabel,
    required this.eyebrow,
    required this.title,
    required this.photosLabel,
    required this.platesLabel,
    required this.plates,
    required this.showSwitch,
    required this.onPhotos,
    required this.onPlates,
    required this.body,
    this.description = '',
    this.meta = '',
    this.metaLine,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final line = metaLine;
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
                        Text(eyebrow, style: GuideType.eyebrow(colors)),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: GuideType.display,
                            fontWeight: FontWeight.w500,
                            fontSize: 30,
                            height: 1.05,
                            letterSpacing: -0.4,
                            color: colors.ink,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: TextStyle(
                              fontFamily: GuideType.sans,
                              fontSize: 15,
                              height: 1.4,
                              color: colors.ink2,
                            ),
                          ),
                        ],
                        if (line != null || meta.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          line ??
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
                      photos: photosLabel,
                      plates: platesLabel,
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

/// One row of a species grid. Empty slots keep the last cell from stretching.
Widget speciesGridRow({required int columns, required List<Widget> cells}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: i < cells.length ? cells[i] : const SizedBox.shrink(),
          ),
        ],
      ],
    ),
  );
}

class SpeciesCell extends StatelessWidget {
  final Species species;
  final String title;
  final bool titleIsLatin;
  final bool plates;
  final bool seen;
  final String seenLabel;
  final String? mark;
  final String? markNote;
  final VoidCallback onTap;

  const SpeciesCell({
    super.key,
    required this.species,
    required this.title,
    required this.titleIsLatin,
    required this.plates,
    required this.seen,
    required this.seenLabel,
    required this.onTap,
    this.mark,
    this.markNote,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final drawn = cardPlate(species.illustrationUrl);
    final showingPlate = plates && drawn.isNotEmpty;
    final url = curatedImage(species, plate: plates);
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: showingPlate ? 2 / 3 : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: showingPlate ? _plateGround : colors.paper2,
                child: url.isEmpty
                    ? const SizedBox.expand()
                    : GuidePhoto(
                        url: url,
                        fit: showingPlate ? BoxFit.contain : BoxFit.cover,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          if (mark != null)
            Text(
              mark!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: GuideType.display,
                fontWeight: FontWeight.w500,
                fontSize: 16,
                height: 1.15,
                color: colors.madder,
              ),
            ),
          if (markNote != null)
            Text(
              markNote!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: GuideType.sans,
                fontSize: 10,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
                color: colors.madder,
              ),
            ),
          Text(
            titleIsLatin ? species.name : title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: titleIsLatin
                ? GuideType.latin(colors).copyWith(fontSize: 16, height: 1.15)
                : TextStyle(
                    fontFamily: GuideType.display,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    height: 1.15,
                    color: colors.ink,
                  ),
          ),
          if (!titleIsLatin)
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
                seenLabel,
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
