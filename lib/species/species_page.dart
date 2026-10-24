import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whats_that_mushroom/book/taxon_page.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

void openSpecies(BuildContext context, String latin) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => SpeciesPage(latin: latin)));
}

class SpeciesPage extends StatefulWidget {
  final String latin;

  const SpeciesPage({super.key, required this.latin});

  @override
  State<SpeciesPage> createState() => _SpeciesPageState();
}

class _SpeciesPageState extends State<SpeciesPage> {
  var _photo = 0;
  var _namesOpen = false;
  var _ranksOpen = false;

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    final species = catalog?.byName(widget.latin);
    if (catalog == null || species == null) {
      return Scaffold(
        backgroundColor: colors.paper,
        appBar: AppBar(),
        body: catalog == null
            ? CatalogMessage(
                copy: copy,
                error: scope.catalog.error,
                onRetry: scope.reload,
              )
            : Center(
                child: Text(copy.catalogError, style: GuideType.body(colors)),
              ),
      );
    }
    final text = catalog.textFor(species);
    final title = catalog.heading(species);
    final spoken = title != species.name;
    final favorite = scope.notebook.isFavorite(species.name);
    final plates = _frames(species, copy);
    final higher = [
      for (final rank in rankOrder)
        if (rank != 'order' &&
            rank != 'family' &&
            rank != 'genus' &&
            species.taxonomy[rank] != null)
          rank,
    ];
    return Scaffold(
      backgroundColor: colors.paper,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: colors.paper,
            actions: [
              IconButton(
                onPressed: () => scope.notebook.toggleFavorite(species.name),
                icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                color: favorite ? colors.madder : colors.ink,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plates.isNotEmpty)
                  SizedBox(
                    height: 420,
                    child: PageView.builder(
                      itemCount: plates.length,
                      onPageChanged: (index) => setState(() => _photo = index),
                      itemBuilder: (context, index) {
                        final frame = plates[index];
                        return GuidePhoto(
                          url: frame.url,
                          label: frame.label,
                          fit: BoxFit.contain,
                        );
                      },
                    ),
                  ),
                if (plates.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < plates.length; i++)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _photo ? colors.ink : colors.rule,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (species.photoUrls.isNotEmpty) ...[
                  _sectionTitle(copy.field, colors),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Text(copy.fieldLede, style: GuideType.muted(colors)),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    _kicker(species),
                    style: GuideType.latin(
                      colors,
                      size: 14,
                    ).copyWith(color: colors.gold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    title,
                    style: spoken
                        ? GuideType.spoken(colors, size: 34)
                        : GuideType.latin(colors, size: 32),
                  ),
                ),
                if (spoken)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                    child: Text(
                      species.name,
                      style: GuideType.latin(colors, size: 18),
                    ),
                  ),
                if (species.author.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                    child: Text(species.author, style: GuideType.muted(colors)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (species.edibility.isNotEmpty)
                        _fact(
                          copy.edibility(species.edibility),
                          _edibleColor(species.edibility, colors),
                          colors,
                        ),
                      if (seasonSpan(
                        species.fruitingFrom,
                        species.fruitingTo,
                        copy.code,
                      ).isNotEmpty)
                        _fact(
                          '${copy.season} ${seasonSpan(species.fruitingFrom, species.fruitingTo, copy.code)}',
                          colors.ink,
                          colors,
                        ),
                      if (_cap(species, copy).isNotEmpty)
                        _fact(
                          '${copy.cap} ${_cap(species, copy)}',
                          colors.ink,
                          colors,
                        ),
                      if (_stipe(species).isNotEmpty)
                        _fact(
                          '${copy.stipe} ${_stipe(species)}',
                          colors.ink,
                          colors,
                        ),
                    ],
                  ),
                ),
                if (text.names.isNotEmpty) _names(copy, colors, text.names),
                if ((text.description ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(
                      text.description!,
                      style: GuideType.body(colors),
                    ),
                  ),
                _body(
                  copy,
                  colors,
                  text,
                  species.hymenium,
                  _edible(species.edibility) ? copy.usesNote : copy.usesCaution,
                ),
                _taxonomy(context, catalog, copy, colors, species, higher),
                _synonyms(copy, colors, species.synonymLines),
                _sources(copy, colors, text.sourceUrls),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_Frame> _frames(Species species, Copy copy) {
    final frames = <_Frame>[];
    final plate = mediaUrl(species.illustrationUrl);
    if (plate.isNotEmpty) frames.add(_Frame(plate, copy.plate));
    final photos = species.photoUrls
        .map(mediaUrl)
        .where((url) => url.isNotEmpty)
        .toList();
    for (var i = 0; i < photos.length; i++) {
      frames.add(_Frame(photos[i], copy.photo(i + 1, photos.length)));
    }
    return frames;
  }

  Widget _names(Copy copy, GuideColors colors, List<String> names) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        '${copy.also} ${names.join(', ')}',
        style: GuideType.muted(colors),
      ),
    );
  }

  Widget _body(
    Copy copy,
    GuideColors colors,
    SpeciesText text,
    String hymenium,
    String usesNote,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((text.cap ?? '').isNotEmpty)
          _section(copy.cap, null, text.cap!, colors),
        if ((text.hymenium ?? '').isNotEmpty)
          _section(
            copy.hymeniumHeading(hymenium),
            null,
            text.hymenium!,
            colors,
          ),
        if ((text.stipe ?? '').isNotEmpty)
          _section(copy.stipe, null, text.stipe!, colors),
        if ((text.flesh ?? '').isNotEmpty)
          _section(copy.flesh, null, text.flesh!, colors),
        if ((text.sporePrint ?? '').isNotEmpty)
          _section(copy.spore, null, text.sporePrint!, colors),
        if ((text.habitat ?? '').isNotEmpty)
          _section(copy.habitat, null, text.habitat!, colors),
        if ((text.uses ?? '').isNotEmpty)
          _section(copy.uses, usesNote, text.uses!, colors),
        if ((text.confusion ?? '').isNotEmpty)
          _section(copy.lookalikes, null, text.confusion!, colors),
        if ((text.notes ?? '').isNotEmpty)
          _section(copy.notes, null, text.notes!, colors),
      ],
    );
  }

  Widget _taxonomy(
    BuildContext context,
    Catalog catalog,
    Copy copy,
    GuideColors colors,
    Species species,
    List<String> higher,
  ) {
    final focus = [
      if (species.order.isNotEmpty) 'order',
      if (species.family.isNotEmpty) 'family',
      if (species.genus.isNotEmpty) 'genus',
    ];
    if (focus.isEmpty && higher.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(copy.classification, colors),
        if (higher.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(copy.showRanks, style: GuideType.body(colors)),
              initiallyExpanded: _ranksOpen,
              onExpansionChanged: (open) => setState(() => _ranksOpen = open),
              children: [
                for (final rank in higher)
                  _rank(
                    context,
                    catalog,
                    copy,
                    colors,
                    rank,
                    species.taxonomy[rank]!,
                  ),
              ],
            ),
          ),
        for (final rank in focus)
          _rank(context, catalog, copy, colors, rank, species.taxonomy[rank]!),
      ],
    );
  }

  Widget _rank(
    BuildContext context,
    Catalog catalog,
    Copy copy,
    GuideColors colors,
    String rank,
    String scientific,
  ) {
    final title = catalog.taxonTitle(scientific);
    final spoken = title != scientific;
    final linked = rank == 'family' || rank == 'genus';
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.rank(rank), style: GuideType.muted(colors, size: 12)),
          Text(
            title,
            style: spoken
                ? GuideType.spoken(colors, size: 18)
                : GuideType.latin(colors, size: 18),
          ),
          if (spoken)
            Text(scientific, style: GuideType.latin(colors, size: 14)),
        ],
      ),
    );
    if (!linked) return child;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TaxonPage(kind: rank, name: scientific),
        ),
      ),
      child: child,
    );
  }

  Widget _synonyms(Copy copy, GuideColors colors, List<String> lines) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final shown = _namesOpen ? lines : lines.take(2).toList();
    final hidden = lines.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(copy.synonyms, colors),
        for (final line in shown)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(line, style: GuideType.latin(colors, size: 16)),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton(
              onPressed: () => setState(() => _namesOpen = true),
              child: Text(copy.moreNames(hidden)),
            ),
          ),
      ],
    );
  }

  Widget _sources(Copy copy, GuideColors colors, List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(copy.sources, colors),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(copy.sourcesLede, style: GuideType.muted(colors)),
        ),
        for (final url in urls)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: ListTile(
              title: Text(
                url,
                style: GuideType.muted(
                  colors,
                  size: 14,
                ).copyWith(color: colors.moss),
              ),
              onTap: () => _open(url),
            ),
          ),
      ],
    );
  }
}

class _Frame {
  final String url;
  final String label;

  const _Frame(this.url, this.label);
}

String _kicker(Species species) {
  final parts = [
    species.family,
    species.order,
  ].where((part) => part.isNotEmpty);
  return parts.join(' · ');
}

String _cap(Species species, Copy copy) {
  return capMeasure(from: species.capFrom, to: species.capTo, copy: copy);
}

String _stipe(Species species) {
  return stipeMeasure(
    heightFrom: species.stipeHeightFrom,
    heightTo: species.stipeHeightTo,
    thickFrom: species.stipeThickFrom,
    thickTo: species.stipeThickTo,
  );
}

bool _edible(String id) {
  return id == 'choice' || id == 'edible' || id == 'edible_with_caution';
}

Color _edibleColor(String id, GuideColors colors) {
  if (id == 'poisonous' || id == 'deadly') return colors.madder;
  if (id == 'choice' || id == 'edible') return colors.moss;
  return colors.ink;
}

Widget _fact(String label, Color color, GuideColors colors) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: colors.cream,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colors.rule),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 14,
          color: color,
        ),
      ),
    ),
  );
}

Widget _section(String title, String? note, String body, GuideColors colors) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle(title, colors),
      if (note != null && note.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Text(note, style: GuideType.muted(colors)),
        ),
      if (body.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(body, style: GuideType.body(colors)),
        ),
    ],
  );
}

Widget _sectionTitle(String title, GuideColors colors) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
    child: Text(title, style: GuideType.spoken(colors, size: 24)),
  );
}

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
