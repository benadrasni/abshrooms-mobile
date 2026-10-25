import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/book/new_page.dart';
import 'package:whats_that_mushroom/book/taxon_page.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/new_book.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/lists/curated_lists_section.dart';
import 'package:whats_that_mushroom/search/search_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

enum BookSegment { families, genera, lists }

class BookPage extends StatefulWidget {
  const BookPage({super.key});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final ScrollController _scroll = ScrollController();
  BookSegment _segment = BookSegment.families;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(BookSegment segment) {
    if (_segment == segment) return;
    setState(() => _segment = segment);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    if (scope.catalog.loading && catalog == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (catalog == null) {
      return CatalogMessage(
        copy: copy,
        error: scope.catalog.error,
        onRetry: scope.reload,
      );
    }
    final seen = {
      for (final find in scope.notebook.finds)
        if (find.latin != null) find.latin!,
    };
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: _TitleBar(
            title: copy.book,
            subtitle: copy.bookCounts(
              copy.count(catalog.species.length),
              catalog.namesOf('family').length,
            ),
            searchLabel: copy.search,
            onSearch: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SearchPage(fromBook: true),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _Segments(segment: _segment, onChanged: _select),
        ),
        ..._body(catalog, copy, colors, seen),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  List<Widget> _body(
    Catalog catalog,
    Copy copy,
    GuideColors colors,
    Set<String> seen,
  ) {
    switch (_segment) {
      case BookSegment.families:
        return [
          _taxonSliver(
            catalog,
            catalog.namesOf('family'),
            family: true,
            seen: seen,
          ),
        ];
      case BookSegment.genera:
        return [
          _taxonSliver(
            catalog,
            catalog.namesOf('genus'),
            family: false,
            seen: seen,
          ),
        ];
      case BookSegment.lists:
        return [
          _lists(catalog, copy, colors, seen),
          const SliverToBoxAdapter(child: CuratedListsSection(book: true)),
        ];
    }
  }

  Widget _taxonSliver(
    Catalog catalog,
    List<String> names, {
    required bool family,
    required Set<String> seen,
  }) {
    return SliverList.builder(
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        final title = catalog.taxonTitle(name);
        final kind = family ? 'family' : 'genus';
        return _TaxonRow(
          title: title,
          latin: name,
          count: catalog.countOf(kind, name),
          plate: familyIcon(_plateFamily(catalog, name, family: family)),
          note: family ? null : _genusNote(catalog, name, seen),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TaxonPage(kind: kind, name: name),
            ),
          ),
        );
      },
    );
  }

  Widget _lists(
    Catalog catalog,
    Copy copy,
    GuideColors colors,
    Set<String> seen,
  ) {
    final favorites =
        [
          for (final latin in scopeFavorites())
            if (catalog.byName(latin) != null) catalog.byName(latin)!,
        ]..sort(
          (a, b) =>
              catalog.compareTitles(catalog.heading(a), catalog.heading(b)),
        );
    final fresh = newInBook(catalog.species);
    final cards = <Widget>[];
    if (favorites.isNotEmpty) {
      cards.add(
        _ListCard(
          title: copy.favoriteMushrooms,
          subtitle: copy.count(favorites.length),
          photos: [for (final item in favorites.take(4)) speciesPhoto(item)],
          favorite: true,
          gold: false,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TaxonPage(kind: 'favorites', name: ''),
            ),
          ),
        ),
      );
    }
    if (fresh.isNotEmpty) {
      final species = [for (final day in fresh) ...day.species];
      cards.add(
        _ListCard(
          title: copy.newInBook,
          subtitle: copy.latestLine(
            copy.count(species.length),
            MaterialLocalizations.of(context)
                .formatMediumDate(fresh.first.date),
          ),
          photos: [for (final item in species.take(4)) speciesPhoto(item)],
          favorite: false,
          gold: true,
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const NewPage())),
        ),
      );
    }
    if (cards.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.only(top: 6),
      sliver: SliverList.builder(
        itemCount: cards.length,
        itemBuilder: (_, index) => cards[index],
      ),
    );
  }

  Set<String> scopeFavorites() {
    return GuideScope.of(context).notebook.favorites;
  }

  String? _genusNote(Catalog catalog, String genus, Set<String> seen) {
    final copy = GuideScope.of(context).copy;
    final month = DateTime.now().month;
    var fruiting = 0;
    var found = 0;
    for (final item in catalog.speciesIn('genus', genus)) {
      if (item.fruitsIn(month)) fruiting += 1;
      if (seen.contains(item.name)) found += 1;
    }
    final parts = <String>[
      if (fruiting > 0) copy.fruitingNowLine(fruiting),
      if (found > 0) copy.youHaveSeen(found),
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

String _plateFamily(Catalog catalog, String name, {required bool family}) {
  if (family) return name;
  for (final item in catalog.species) {
    if (item.genus == name && item.family.isNotEmpty) return item.family;
  }
  return '';
}

class _TitleBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String searchLabel;
  final VoidCallback onSearch;

  const _TitleBar({
    required this.title,
    required this.subtitle,
    required this.searchLabel,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GuideType.wordmark(colors).copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 21,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 13,
                    height: 1.3,
                    color: colors.ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: searchLabel,
            child: Material(
              color: colors.cream,
              shape: CircleBorder(side: BorderSide(color: colors.rule)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSearch,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(Icons.search, size: 20, color: colors.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  final BookSegment segment;
  final ValueChanged<BookSegment> onChanged;

  const _Segments({required this.segment, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final items = [
      (BookSegment.families, copy.families),
      (BookSegment.genera, copy.genera),
      (BookSegment.lists, copy.lists),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.rule),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: _Segment(
                    label: item.$2,
                    selected: segment == item.$1,
                    onTap: () => onChanged(item.$1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Material(
      color: selected ? colors.ink : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: GuideType.sans,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? colors.paper
                          : Colors.white)
                    : colors.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaxonRow extends StatelessWidget {
  final String title;
  final String latin;
  final int count;
  final String plate;
  final String? note;
  final VoidCallback onTap;

  const _TaxonRow({
    required this.title,
    required this.latin,
    required this.count,
    required this.plate,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final spoken = title != latin;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 9, 20, 9),
        child: Row(
          children: [
            _Plate(url: plate),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: spoken
                        ? TextStyle(
                            fontFamily: GuideType.sans,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.2,
                            color: colors.ink,
                          )
                        : GuideType.latin(colors)
                              .copyWith(fontSize: 16, height: 1.2),
                  ),
                  if (spoken)
                    Text(
                      latin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GuideType.latin(
                        colors,
                      ).copyWith(fontSize: 13, height: 1.2, color: colors.ink2),
                    ),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      note!,
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: GuideType.sans,
                fontSize: 12,
                color: colors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  final String url;

  const _Plate({required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Container(
      width: 44,
      height: 44,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.rule),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: colors.cream,
          child: url.isEmpty
              ? const SizedBox.expand()
              : GuidePhoto(url: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> photos;
  final bool favorite;
  final bool gold;
  final VoidCallback onTap;

  const _ListCard({
    required this.title,
    required this.subtitle,
    required this.photos,
    required this.favorite,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final slots = favorite ? photos.length.clamp(1, 4) : 4;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
      child: Material(
        color: colors.cream,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: gold ? colors.gold : colors.rule,
            width: gold ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photos.isNotEmpty) ...[
                  _Thumbs(photos: photos, slots: slots),
                  const SizedBox(height: 10),
                ],
                Text.rich(
                  TextSpan(
                    children: [
                      if (favorite)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: Icon(
                              Icons.favorite,
                              size: 16,
                              color: colors.madder,
                            ),
                          ),
                        ),
                      TextSpan(
                        text: title,
                        style: TextStyle(
                          fontFamily: GuideType.display,
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                          height: 1.15,
                          color: colors.ink,
                        ),
                      ),
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.bottom,
                        child: SizedBox(width: 6),
                      ),
                      TextSpan(
                        text: subtitle,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          fontSize: 13,
                          height: 1.15,
                          color: colors.ink2,
                        ),
                      ),
                    ],
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

class _Thumbs extends StatelessWidget {
  final List<String> photos;
  final int slots;

  const _Thumbs({required this.photos, required this.slots});

  @override
  Widget build(BuildContext context) {
    final count = slots < 1 ? 1 : slots;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: i < photos.length && photos[i].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GuidePhoto(url: photos[i], fit: BoxFit.cover),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }
}
