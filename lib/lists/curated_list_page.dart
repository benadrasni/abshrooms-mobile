import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whats_that_mushroom/book/list_chrome.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
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
    final host = sourceHost(list.sourceUrl);
    return ListPageChrome(
      backLabel: widget.backLabel,
      eyebrow: copy.lists.toUpperCase(),
      title: list.title,
      description: list.description,
      photosLabel: copy.photos,
      platesLabel: copy.plates,
      plates: _plates,
      showSwitch: list.entries.isNotEmpty,
      onPhotos: () => setState(() => _plates = false),
      onPlates: () => setState(() => _plates = true),
      metaLine: Text.rich(
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
      body: list.entries.isEmpty
          ? [_empty(copy, colors)]
          : _rows(list, columns, seen, copy),
    );
  }

  Widget _empty(Copy copy, GuideColors colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text(
        copy.listsEmpty,
        style: TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 15,
          height: 1.4,
          color: colors.ink2,
        ),
      ),
    );
  }

  List<Widget> _rows(
    CuratedListView list,
    int columns,
    Set<String> seen,
    Copy copy,
  ) {
    final rows = <Widget>[];
    final entries = list.entries;
    for (var start = 0; start < entries.length; start += columns) {
      final slice = entries.skip(start).take(columns).toList();
      rows.add(
        speciesGridRow(
          columns: columns,
          cells: [
            for (final entry in slice)
              SpeciesCell(
                key: Key(
                  'curated-entry-${entry.species.name}-${entry.year}-${entry.region}',
                ),
                species: entry.species,
                title: entry.title,
                titleIsLatin: entry.titleIsLatin,
                plates: _plates,
                seen: seen.contains(entry.species.name),
                seenLabel: copy.seenMark,
                mark:
                    entry.region ??
                    (entry.year == null ? null : '${entry.year}'),
                markNote: entry.thisYear ? copy.thisYear : null,
                onTap: () => widget.onOpenSpecies(context, entry.species.name),
              ),
          ],
        ),
      );
    }
    return rows;
  }
}

Future<void> _openSource(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
