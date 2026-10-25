import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whats_that_mushroom/ads/app_banner_ad.dart';
import 'package:whats_that_mushroom/book/taxon_page.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/seen_photo.dart';

void openSpecies(BuildContext context, String latin) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => SpeciesPage(latin: latin)));
}

class SpeciesPage extends StatefulWidget {
  final String latin;

  /// Replaces the gallery picker in tests. Null is a cancelled pick.
  final Future<SeenPhoto?> Function()? pickSeen;

  const SpeciesPage({super.key, required this.latin, this.pickSeen});

  @override
  State<SpeciesPage> createState() => _SpeciesPageState();
}

class _SpeciesPageState extends State<SpeciesPage> {
  var _photo = 0;
  var _namesOpen = false;
  var _ranksOpen = false;
  var _saving = false;

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
    final seen = _seenSummary(scope.notebook, species.name);
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
                if (seen != null)
                  _SeenByYou(
                    seen: seen,
                    copy: copy,
                    colors: colors,
                    onPressed: _openSeen,
                  ),
                _AddSeenButton(
                  copy: copy,
                  colors: colors,
                  saving: _saving,
                  onPressed: () => _addSeen(species.name),
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
          if (Purchases.showsAds())
            const SliverToBoxAdapter(child: AppBannerAd()),
        ],
      ),
    );
  }

  Future<void> _addSeen(String latin) async {
    if (_saving) return;
    final scope = GuideScope.of(context);
    setState(() => _saving = true);
    try {
      final pick = widget.pickSeen ?? pickSeenPhoto;
      final photo = await pick();
      if (!mounted || photo == null) return;
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final saved = await scope.notebook.savePhoto(photo.bytes, id);
      if (!mounted) return;
      if (saved == null) {
        _showFailure();
        return;
      }
      await scope.notebook.addFind(
        FindRecord(
          id: id,
          millis: photo.when.millisecondsSinceEpoch,
          latin: latin,
          photoPath: saved,
          confirmed: true,
          latitude: photo.latitude == 0 ? null : photo.latitude,
          longitude: photo.longitude == 0 ? null : photo.longitude,
        ),
      );
      if (!mounted) return;
      final copy = scope.copy;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(photo.fromPhoto ? copy.addedSeenPhoto : copy.addedSeen),
        ),
      );
    } catch (error) {
      debugPrint('add seen ${widget.latin}: $error');
      _showFailure();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(GuideScope.of(context).copy.seenFailed)),
    );
  }

  void _openSeen() {
    final select = GuideScope.of(context).selectTab;
    Navigator.of(context).popUntil((route) => route.isFirst);
    select(2);
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

class _SpeciesSeen {
  final int count;
  final DateTime? last;
  final String? photoPath;

  const _SpeciesSeen({
    required this.count,
    required this.last,
    required this.photoPath,
  });
}

/// Finds of [latin], newest dated photo first. No finds is null.
_SpeciesSeen? _seenSummary(Notebook notebook, String latin) {
  var count = 0;
  DateTime? last;
  String? photo;
  String? fallback;
  for (final item in notebook.finds) {
    if (item.latin != latin) continue;
    count += 1;
    final path = item.photoPath;
    if (fallback == null && path != null && path.isNotEmpty) fallback = path;
    if (item.millis <= 0) continue;
    final when = DateTime.fromMillisecondsSinceEpoch(item.millis);
    if (last == null || when.isAfter(last)) {
      last = when;
      if (path != null && path.isNotEmpty) photo = path;
    }
  }
  if (count == 0) return null;
  return _SpeciesSeen(count: count, last: last, photoPath: photo ?? fallback);
}

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _seenDate(DateTime when, Copy copy, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final year = when.year == today.year ? '' : ' ${when.year}';
  if (copy.sk) {
    final month = monthsSk[when.month - 1];
    return '${when.day}. $month$year';
  }
  return '${_shortMonths[when.month - 1]} ${when.day}$year';
}

class _SeenByYou extends StatelessWidget {
  final _SpeciesSeen seen;
  final Copy copy;
  final GuideColors colors;
  final VoidCallback onPressed;

  const _SeenByYou({
    required this.seen,
    required this.copy,
    required this.colors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final last = seen.last;
    final when = last == null ? '' : _seenDate(last, copy);
    final detail = last == null
        ? ''
        : seen.count == 1
        ? copy.seenOnce(when)
        : copy.seenTimes(seen.count, when);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Material(
        color: colors.cream,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.rule),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: _thumb(seen.photoPath, colors),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        copy.seenByYou,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          fontSize: 14,
                          height: 1.2,
                          color: colors.moss,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          style: TextStyle(
                            fontFamily: GuideType.sans,
                            fontSize: 14,
                            height: 1.2,
                            color: colors.ink,
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

Widget _thumb(String? path, GuideColors colors) {
  if (path == null || path.isEmpty) return ColoredBox(color: colors.paper2);
  final file = File(path);
  if (!file.existsSync()) return ColoredBox(color: colors.paper2);
  return Image.file(file, fit: BoxFit.cover);
}

class _AddSeenButton extends StatelessWidget {
  final Copy copy;
  final GuideColors colors;
  final bool saving;
  final VoidCallback onPressed;

  const _AddSeenButton({
    required this.copy,
    required this.colors,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: saving ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.ink,
              side: BorderSide(color: colors.rule),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: const TextStyle(
                fontFamily: GuideType.sans,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text('+ ${copy.addSeen}'),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              copy.addSeenHint,
              style: TextStyle(
                fontFamily: GuideType.sans,
                fontSize: 13,
                color: colors.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
