import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/seen/stats.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

String _grouped(BuildContext context, int value) {
  return statGrouped(value, locale: Localizations.localeOf(context).toString());
}

/// Your finds, and Sightings.
///
/// The notebook stays on this phone. Sightings are the public Firestore
/// documents. A country row appears only when a row carries a country code.
class StatsPage extends StatefulWidget {
  final bool sightings;

  /// The back label is Seen. Person uses Back.
  final bool fromSeen;

  final Future<SightingsLoad> Function() loadSightings;
  final String? Function(FindRecord find)? countryOf;
  final void Function(BuildContext context, String name)? onOpen;

  const StatsPage({
    super.key,
    this.sightings = false,
    this.fromSeen = false,
    this.loadSightings = loadPublicSightings,
    this.countryOf,
    this.onOpen,
  });

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late bool _public;
  SightingsLoad? _sightings;
  var _sightingsLoading = true;
  var _sightingsFailed = false;

  @override
  void initState() {
    super.initState();
    _public = widget.sightings;
    unawaited(_loadSightings());
  }

  Future<void> _loadSightings() async {
    try {
      final load = await widget.loadSightings();
      if (!mounted) return;
      setState(() {
        _sightings = load;
        _sightingsLoading = false;
        _sightingsFailed = false;
      });
    } catch (error) {
      debugPrint('stats sightings: $error');
      if (!mounted) return;
      setState(() {
        _sightingsLoading = false;
        _sightingsFailed = true;
      });
    }
  }

  void _retrySightings() {
    setState(() {
      _sightingsLoading = true;
      _sightingsFailed = false;
    });
    unawaited(_loadSightings());
  }

  bool? _inBook(Catalog? catalog, String name) {
    if (name.isEmpty) return false;
    if (catalog == null) return null;
    return catalog.byName(name) != null;
  }

  void _open(String name) {
    if (name.isEmpty) return;
    final known = _inBook(GuideScope.of(context).catalog.data, name);
    if (known == null) return;
    if (!known) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(GuideScope.of(context).copy.seenNotInBook)),
      );
      return;
    }
    final custom = widget.onOpen;
    if (custom != null) {
      custom(context, name);
      return;
    }
    openSpecies(context, name, source: GuideMushroomSource.seen);
  }

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final stats = notebookStats(
      scope.notebook.finds,
      countryOf: widget.countryOf,
    );
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Back(label: widget.fromSeen ? copy.seen : copy.back),
            _Intro(
              title: _public ? copy.statsSightings : copy.statsYours,
              note: _note(copy, stats),
            ),
            _Segments(
              sightings: _public,
              onYours: () {
                if (!_public) return;
                setState(() => _public = false);
              },
              onSightings: () {
                if (_public) return;
                setState(() => _public = true);
              },
            ),
            if (_public)
              _sightingsBody(copy, stats)
            else
              _findsBody(copy, stats),
          ],
        ),
      ),
    );
  }

  String _note(Copy copy, NotebookStats stats) {
    if (_public) return copy.statsSightingsNote;
    final note = copy.statsYoursNote;
    if (stats.unconfirmed == 0) return note;
    return '$note ${copy.statsToConfirm(stats.unconfirmed)}';
  }

  Widget _findsBody(Copy copy, NotebookStats stats) {
    if (stats.finds == 0) return _Hint(copy.statsEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Numbers(
          counts: [
            (_grouped(context, stats.finds), copy.statsFinds(stats.finds)),
            (
              _grouped(context, stats.mushrooms),
              copy.statsMushrooms(stats.mushrooms),
            ),
            (_grouped(context, stats.shared), copy.statsShared(stats.shared)),
          ],
        ),
        _Section(copy.statsSpan),
        if (stats.first != null)
          _MushroomRow(
            role: copy.statsFirst,
            name: stats.first!.name,
            spoken: stats.first!.spoken,
            photoPath: stats.first!.photoPath,
            detail: copy.statsDay(stats.first!.when),
            onTap: () => _open(stats.first!.name),
          ),
        if (stats.last != null)
          _MushroomRow(
            role: copy.statsLast,
            name: stats.last!.name,
            spoken: stats.last!.spoken,
            photoPath: stats.last!.photoPath,
            detail: copy.statsDay(stats.last!.when),
            onTap: () => _open(stats.last!.name),
          ),
        if (stats.most.isEmpty)
          _Hint(copy.statsOnce)
        else
          for (final mushroom in stats.most)
            _MushroomRow(
              role: copy.statsMost,
              name: mushroom.name,
              spoken: mushroom.spoken,
              photoPath: mushroom.photoPath,
              detail: copy.seenFinds(mushroom.count),
              onTap: () => _open(mushroom.name),
            ),
        if (stats.years.isNotEmpty) ...[
          _Section(copy.statsByYear),
          _YearBars(years: stats.years),
        ],
        if (stats.countries.isNotEmpty) ...[
          _Section(
            copy.statsByCountry(_grouped(context, stats.countries.length)),
          ),
          _Countries(countries: stats.countries),
          if (stats.unplaced > 0) _Hint(copy.statsNoPlace(stats.unplaced)),
        ],
      ],
    );
  }

  Widget _sightingsBody(Copy copy, NotebookStats stats) {
    if (_sightingsLoading) return const _Wait();
    if (_sightingsFailed) return _Failed(onRetry: _retrySightings);
    final headline = _sightings?.headline;
    final years = _sightings?.years ?? const <StatYear>[];
    if (headline == null || headline.count == 0) {
      return _Hint(copy.statsSightingsEmpty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Numbers(
          counts: [
            (_grouped(context, headline.count), copy.statsSightings),
            (
              _grouped(context, headline.mushrooms),
              copy.statsMushrooms(headline.mushrooms),
            ),
            (_grouped(context, headline.people), copy.statsPeople),
          ],
        ),
        _Section(copy.statsSpanMost),
        if (headline.firstName.isNotEmpty)
          _MushroomRow(
            role: copy.statsFirst,
            name: headline.firstName,
            detail: headline.firstWhen == null
                ? null
                : copy.statsDay(headline.firstWhen!),
            onTap: () => _open(headline.firstName),
          ),
        if (headline.lastName.isNotEmpty)
          _MushroomRow(
            role: copy.statsLast,
            name: headline.lastName,
            detail: headline.lastWhen == null
                ? null
                : copy.statsDay(headline.lastWhen!),
            onTap: () => _open(headline.lastName),
          ),
        if (headline.mostName.isNotEmpty && headline.mostCount > 0)
          _MushroomRow(
            role: copy.statsMost,
            name: headline.mostName,
            detail: copy.statsSightingTimes(headline.mostCount),
            onTap: () => _open(headline.mostName),
          ),
        if (years.isNotEmpty) ...[
          _Section(copy.statsByYear),
          _YearBars(years: years),
        ],
        if (headline.countries.isNotEmpty) ...[
          _Section(
            copy.statsByCountry(_grouped(context, headline.countries.length)),
          ),
          _Countries(countries: headline.countries),
        ],
        _Hint(
          copy.statsPlace(_grouped(context, headline.people), stats.shared),
        ),
      ],
    );
  }
}

/// Public Sightings. An app with no Firebase returns an empty load so the
/// page can still open in a test. A query failure is left for the page.
Future<SightingsLoad> loadPublicSightings() async {
  try {
    if (Firebase.apps.isEmpty) {
      return const SightingsLoad(headline: null, years: []);
    }
  } catch (error) {
    debugPrint('stats sightings: $error');
    return const SightingsLoad(headline: null, years: []);
  }
  final snap = await FirebaseFirestore.instance
      .collection('sightings')
      .where('status', isEqualTo: 'public')
      .get();
  return sightingsFromDocs([for (final doc in snap.docs) doc.data()]);
}

class _Intro extends StatelessWidget {
  final String title;
  final String note;

  const _Intro({required this.title, required this.note});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.statistics.toUpperCase(), style: GuideType.eyebrow(colors)),
          const SizedBox(height: 6),
          Text(title, style: GuideType.question(colors)),
          const SizedBox(height: 8),
          Text(
            note,
            style: TextStyle(
              fontFamily: GuideType.sans,
              fontSize: 13,
              height: 1.35,
              color: colors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  final bool sightings;
  final VoidCallback onYours;
  final VoidCallback onSightings;

  const _Segments({
    required this.sightings,
    required this.onYours,
    required this.onSightings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 4),
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
              Expanded(
                child: _Segment(
                  key: const Key('guide-stats-yours'),
                  label: copy.statsYours,
                  selected: !sightings,
                  onTap: onYours,
                ),
              ),
              Expanded(
                child: _Segment(
                  key: const Key('guide-stats-sightings'),
                  label: copy.statsSightings,
                  selected: sightings,
                  onTap: onSightings,
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
    super.key,
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
                color: selected ? colors.onInk : colors.ink3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  final List<(String, String)> counts;

  const _Numbers({required this.counts});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 16, 8, 0),
      child: Row(
        children: [
          for (final count in counts)
            Expanded(
              child: Column(
                children: [
                  Text(
                    count.$1,
                    style: TextStyle(
                      fontFamily: GuideType.display,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count.$2,
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 13,
                      color: colors.ink3,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;

  const _Section(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 12,
          letterSpacing: 0.96,
          fontWeight: FontWeight.w600,
          color: colors.ink3,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 13,
          height: 1.35,
          color: GuideColors.of(context).ink3,
        ),
      ),
    );
  }
}

class _Wait extends StatelessWidget {
  const _Wait();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  final VoidCallback onRetry;

  const _Failed({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            copy.statsFailed,
            style: TextStyle(fontFamily: GuideType.sans, color: colors.ink2),
          ),
          TextButton(
            key: const Key('guide-stats-retry'),
            onPressed: onRetry,
            child: Text(copy.retry),
          ),
        ],
      ),
    );
  }
}

class _Face {
  final String title;
  final bool spoken;
  final String? latin;

  const _Face({required this.title, required this.spoken, this.latin});
}

_Face _face(Catalog? catalog, String name, {String? spoken}) {
  final species = catalog?.byName(name);
  if (species != null && catalog != null) {
    final title = catalog.heading(species);
    final named = title != species.name;
    return _Face(
      title: title,
      spoken: named,
      latin: named ? species.name : null,
    );
  }
  final common = spoken?.trim() ?? '';
  if (common.isNotEmpty) {
    return _Face(
      title: common,
      spoken: true,
      latin: name.isEmpty ? null : name,
    );
  }
  return _Face(title: name, spoken: false);
}

String? _plate(Catalog? catalog, String name) {
  final species = catalog?.byName(name);
  if (species == null) return null;
  final url = cardPlate(species.illustrationUrl);
  return url.isEmpty ? null : url;
}

class _MushroomRow extends StatelessWidget {
  final String role;
  final String name;
  final String? spoken;
  final String? photoPath;
  final String? detail;
  final VoidCallback onTap;

  const _MushroomRow({
    required this.role,
    required this.name,
    this.spoken,
    this.photoPath,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final catalog = GuideScope.of(context).catalog.data;
    final face = _face(catalog, name, spoken: spoken);
    final latin = face.latin;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
        child: Row(
          children: [
            _Thumb(path: photoPath, url: _plate(catalog, name)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: colors.ink3,
                    ),
                  ),
                  Text(
                    face.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: face.spoken
                        ? const TextStyle(
                            fontFamily: GuideType.sans,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            height: 1.2,
                          )
                        : GuideType.latin(colors)
                              .copyWith(fontSize: 16, height: 1.2),
                  ),
                  if (latin != null)
                    Text(
                      latin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GuideType.latin(
                        colors,
                      ).copyWith(fontSize: 13, height: 1.2, color: colors.ink3),
                    ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: TextStyle(
                        fontFamily: GuideType.sans,
                        fontSize: 13,
                        height: 1.2,
                        color: colors.ink3,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? path;
  final String? url;

  const _Thumb({required this.path, required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final file = path == null || path!.isEmpty ? null : File(path!);
    final ready = file != null && file.existsSync();
    final photo = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: ready
            ? Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: colors.paper2),
              )
            : photo == null
            ? ColoredBox(color: colors.paper2)
            : GuidePhoto(url: photo, fit: BoxFit.cover),
      ),
    );
  }
}

class _YearBars extends StatefulWidget {
  final List<StatYear> years;

  const _YearBars({required this.years});

  @override
  State<_YearBars> createState() => _YearBarsState();
}

class _YearBarsState extends State<_YearBars> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _pinEnd();
  }

  @override
  void didUpdateWidget(covariant _YearBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.years.length != widget.years.length) _pinEnd();
  }

  void _pinEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    var maxCount = 0;
    for (final year in widget.years) {
      if (year.count > maxCount) maxCount = year.count;
    }
    return SizedBox(
      height: 132,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.years.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final year = widget.years[index];
          final bar = maxCount == 0
              ? 4.0
              : math.max(4.0, year.count / maxCount * 72);
          return SizedBox(
            width: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _grouped(context, year.count),
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 11,
                    color: colors.ink3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 22,
                  height: bar,
                  decoration: BoxDecoration(
                    color: colors.gold,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${year.year}',
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 11,
                    color: colors.ink3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Countries extends StatelessWidget {
  final List<StatCountry> countries;

  const _Countries({required this.countries});

  @override
  Widget build(BuildContext context) {
    if (countries.isEmpty) return const SizedBox.shrink();
    final colors = GuideColors.of(context);
    final rows = [...countries];
    rows.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return _countryName(
        context,
        a.code,
      ).compareTo(_countryName(context, b.code));
    });
    var maxCount = 0;
    for (final row in rows) {
      if (row.count > maxCount) maxCount = row.count;
    }
    final tiles = [
      for (final row in rows)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
          child: Row(
            children: [
              _Flag(code: row.code),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _countryName(context, row.code),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: GuideType.sans,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _Bar(
                      factor: maxCount == 0
                          ? 0.04
                          : math.max(0.04, row.count / maxCount),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _grouped(context, row.count),
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 13,
                  color: colors.ink3,
                ),
              ),
            ],
          ),
        ),
    ];
    if (!_wide(context)) return Column(children: tiles);
    final mid = (tiles.length / 2).ceil();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: tiles.sublist(0, mid))),
        Expanded(child: Column(children: tiles.sublist(mid))),
      ],
    );
  }
}

bool _wide(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.shortestSide >= 650 && size.width > size.height;
}

class _Bar extends StatelessWidget {
  final double factor;

  const _Bar({required this.factor});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: constraints.maxWidth * factor,
            height: 3,
            decoration: BoxDecoration(
              color: GuideColors.of(context).gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}

class _Flag extends StatelessWidget {
  final String code;

  const _Flag({required this.code});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final country = Country.tryParse(code.toUpperCase());
    return Container(
      width: 22,
      height: 15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: Text(
        country?.flagEmoji ?? code.toUpperCase(),
        style: const TextStyle(fontSize: 10, height: 1),
      ),
    );
  }
}

String _countryName(BuildContext context, String code) {
  final country = Country.tryParse(code.toUpperCase());
  if (country == null) return code.toUpperCase();
  final translated = country.getTranslatedName(context)?.trim();
  if (translated != null && translated.isNotEmpty) return translated;
  final name = country.name.trim();
  if (name.isNotEmpty) return name;
  return code.toUpperCase();
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
        key: const Key('guide-stats-back'),
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
                    fontFamily: GuideType.sans,
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
