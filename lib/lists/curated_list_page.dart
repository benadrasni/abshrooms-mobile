import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

class CuratedListPage extends StatefulWidget {
  final CuratedListView list;
  final String backLabel;
  final void Function(BuildContext context, String latin) onOpenSpecies;

  const CuratedListPage({
    super.key,
    required this.list,
    required this.backLabel,
    this.onOpenSpecies = openSpecies,
  });

  @override
  State<CuratedListPage> createState() => _CuratedListPageState();
}

class _CuratedListPageState extends State<CuratedListPage> {
  var _plates = false;

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final scope = context.dependOnInheritedWidgetOfExactType<GuideScope>();
    final copy = scope?.copy ?? const Copy('en');
    final list = widget.list;
    final host = sourceHost(list.sourceUrl);
    final seen = <String>{
      if (scope != null)
        for (final find in scope.notebook.finds)
          if (find.latin != null) find.latin!,
    };
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 980
        ? 4
        : width >= 700
        ? 3
        : 2;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Back(label: widget.backLabel),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.lists.toUpperCase(),
                          style: GuideType.eyebrow(colors),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          list.title,
                          style: TextStyle(
                            fontFamily: GuideType.display,
                            fontWeight: FontWeight.w500,
                            fontSize: 30,
                            height: 1.05,
                            letterSpacing: -0.4,
                            color: colors.ink,
                          ),
                        ),
                        if (list.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            list.description,
                            style: TextStyle(
                              fontFamily: GuideType.sans,
                              fontSize: 15,
                              height: 1.4,
                              color: colors.ink2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontFamily: GuideType.sans,
                              fontSize: 14,
                              height: 1.3,
                              color: colors.ink2,
                            ),
                            children: [
                              TextSpan(text: copy.count(list.entries.length)),
                              if (host != null && list.sourceUrl != null) ...[
                                const TextSpan(text: ' · '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: () => _openSource(list.sourceUrl!),
                                    child: Text(
                                      '$host ↗',
                                      style: TextStyle(
                                        fontFamily: GuideType.sans,
                                        fontSize: 14,
                                        height: 1.3,
                                        fontWeight: FontWeight.w600,
                                        color: colors.moss,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (list.entries.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _Switch(
                          photos: copy.photos,
                          plates: copy.plates,
                          platesOn: _plates,
                          onPhotos: () => setState(() => _plates = false),
                          onPlates: () => setState(() => _plates = true),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (list.entries.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Text(
                    copy.sk
                        ? 'Žiadny z týchto druhov zatiaľ v atlase nie je.'
                        : 'None of these species are in the guide yet.',
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 15,
                      height: 1.4,
                      color: colors.ink2,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    _rows(list.entries, columns, seen, copy),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(
    List<CuratedEntryView> entries,
    int columns,
    Set<String> seen,
    Copy copy,
  ) {
    final rows = <Widget>[];
    for (var start = 0; start < entries.length; start += columns) {
      final slice = entries.skip(start).take(columns).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: i < slice.length
                      ? _Cell(
                          entry: slice[i],
                          plates: _plates,
                          seen: seen.contains(slice[i].species.name),
                          seenLabel: copy.seenMark,
                          thisYear: copy.sk ? 'TENTO ROK' : 'THIS YEAR',
                          onTap: () => widget.onOpenSpecies(
                            context,
                            slice[i].species.name,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return rows;
  }
}

class _Cell extends StatelessWidget {
  final CuratedEntryView entry;
  final bool plates;
  final bool seen;
  final String seenLabel;
  final String thisYear;
  final VoidCallback onTap;

  const _Cell({
    required this.entry,
    required this.plates,
    required this.seen,
    required this.seenLabel,
    required this.thisYear,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final species = entry.species;
    final url = curatedImage(species, plate: plates);
    final plateOnly = plates && species.illustrationUrl.isNotEmpty;
    final mark = entry.region ?? (entry.year == null ? null : '${entry.year}');
    return InkWell(
      key: Key('curated-entry-${species.name}-${entry.year}-${entry.region}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: plateOnly ? 2 / 3 : 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: plateOnly ? colors.plateWell : colors.paper2,
                child: url.isEmpty
                    ? const SizedBox.expand()
                    : GuidePhoto(
                        url: url,
                        fit: plateOnly ? BoxFit.contain : BoxFit.cover,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          if (mark != null)
            Text(
              mark,
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
          if (entry.thisYear)
            Text(
              thisYear,
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
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: entry.titleIsLatin
                ? TextStyle(
                    fontFamily: GuideType.display,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    height: 1.15,
                    color: colors.ink,
                  )
                : TextStyle(
                    fontFamily: GuideType.display,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    height: 1.15,
                    color: colors.ink,
                  ),
          ),
          if (!entry.titleIsLatin)
            Text(
              species.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: GuideType.display,
                fontStyle: FontStyle.italic,
                fontSize: 13,
                height: 1.2,
                color: colors.ink2,
              ),
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

class _Back extends StatelessWidget {
  final String label;

  const _Back({required this.label});

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

class _Switch extends StatelessWidget {
  final String photos;
  final String plates;
  final bool platesOn;
  final VoidCallback onPhotos;
  final VoidCallback onPlates;

  const _Switch({
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

Future<void> _openSource(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
