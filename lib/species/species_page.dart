import 'dart:async';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whats_that_mushroom/ads/app_banner_ad.dart';
import 'package:whats_that_mushroom/book/taxon_page.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/seen/species_sightings.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/seen_photo.dart';

void openSpecies(
  BuildContext context,
  String latin, {
  String source = GuideMushroomSource.list,
}) {
  Navigator.of(context).push(
    guideRoute(
      guideScreenSpecies,
      (_) => SpeciesPage(latin: latin, source: source),
    ),
  );
}

class SpeciesPage extends StatefulWidget {
  final String latin;

  /// Replaces the gallery picker in tests. Null is a cancelled pick.
  final Future<SeenPhoto?> Function()? pickSeen;

  /// Replaces the Sightings read in tests.
  final Future<List<SpeciesSighting>> Function(String latin)? loadSightings;

  /// Where this page was opened. Sent with the species event.
  final String source;

  const SpeciesPage({
    super.key,
    required this.latin,
    this.source = GuideMushroomSource.list,
    this.pickSeen,
    this.loadSightings,
  });

  @override
  State<SpeciesPage> createState() => _SpeciesPageState();
}

class _SpeciesPageState extends State<SpeciesPage> {
  final Map<String, GlobalKey> _sectionKeys = {};
  var _saving = false;
  List<SpeciesSighting> _sightings = const [];
  var _sightingsReady = false;
  var _sightingsFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(GuideAnalytics.mushroom(widget.latin, source: widget.source));
    unawaited(_loadSightings());
  }

  Future<void> _loadSightings() async {
    final load = widget.loadSightings ?? loadSpeciesSightings;
    try {
      final rows = await load(widget.latin);
      if (!mounted) return;
      setState(() {
        _sightings = rows;
        _sightingsReady = true;
        _sightingsFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sightings = const [];
        _sightingsReady = true;
        _sightingsFailed = true;
      });
    }
  }

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
    final photos = [
      for (final path in species.photoUrls)
        if (mediaUrl(path).isNotEmpty) mediaUrl(path),
    ];
    final plateUrl = mediaUrl(species.illustrationUrl);
    final seen = _seenSummary(scope.notebook, species.name);
    final width = MediaQuery.sizeOf(context).width;
    final galleryHeight = width >= 600 ? 460.0 : 420.0;
    final ranks = _taxonLines(catalog, species, copy);
    final usesNote = _edible(species.edibility)
        ? copy.usesNote
        : copy.usesCaution;
    final chips = <({String id, String label})>[
      if ((text.cap ?? '').isNotEmpty) (id: 'cap', label: copy.cap),
      if ((text.hymenium ?? '').isNotEmpty)
        (id: 'hymenium', label: copy.hymeniumHeading(species.hymenium)),
      if ((text.stipe ?? '').isNotEmpty) (id: 'stipe', label: copy.stipe),
      if ((text.flesh ?? '').isNotEmpty) (id: 'flesh', label: copy.flesh),
      if ((text.sporePrint ?? '').isNotEmpty) (id: 'spore', label: copy.spore),
      if ((text.habitat ?? '').isNotEmpty) (id: 'habitat', label: copy.habitat),
      if ((text.uses ?? '').isNotEmpty) (id: 'uses', label: copy.uses),
      if ((text.confusion ?? '').isNotEmpty)
        (id: 'lookalikes', label: copy.lookalikes),
      if ((text.notes ?? '').isNotEmpty) (id: 'notes', label: copy.notes),
      if (ranks.isNotEmpty) (id: 'taxonomy', label: copy.classification),
      (id: 'sightings', label: copy.statsSightings),
      if (text.sourceUrls.isNotEmpty) (id: 'sources', label: copy.sources),
    ];
    final head = <Widget>[
      _Gallery(
        title: title,
        photos: photos,
        plate: plateUrl.isEmpty ? null : plateUrl,
        height: galleryHeight,
        favorite: favorite,
        copy: copy,
        onBack: () => Navigator.maybePop(context),
        onFavorite: () {
          final on = !favorite;
          unawaited(scope.notebook.toggleFavorite(species.name));
          unawaited(GuideAnalytics.favorite(on: on));
          setState(() {});
        },
        onShare: () => _share(title, species.name),
      ),
      _NameBlock(
        kicker: _kicker(species),
        title: title,
        latin: species.name,
        author: species.author,
        spoken: spoken,
        names: text.names,
        copy: copy,
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
      _Facts(
        cap: _cap(species, copy),
        stipe: _stipe(species),
        edibility: species.edibility.isEmpty
            ? ''
            : copy.edibility(species.edibility),
        edibilityColor: species.edibility.isEmpty
            ? null
            : _edibleColor(species.edibility, colors),
        season: seasonSpan(species.fruitingFrom, species.fruitingTo, copy.code),
        fruitingFrom: species.fruitingFrom,
        fruitingTo: species.fruitingTo,
        copy: copy,
      ),
    ];
    final tail = <Widget>[
      if ((text.description ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(text.description!, style: GuideType.body(colors)),
          ),
        ),
      if ((text.cap ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: _section(
            copy.cap,
            null,
            text.cap!,
            colors,
            key: _sectionKey('cap'),
          ),
        ),
      if ((text.hymenium ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: _section(
            copy.hymeniumHeading(species.hymenium),
            null,
            text.hymenium!,
            colors,
            key: _sectionKey('hymenium'),
          ),
        ),
      if ((text.stipe ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: _section(
            copy.stipe,
            null,
            text.stipe!,
            colors,
            key: _sectionKey('stipe'),
          ),
        ),
      if ((text.flesh ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: _section(
            copy.flesh,
            null,
            text.flesh!,
            colors,
            key: _sectionKey('flesh'),
          ),
        ),
      if ((text.sporePrint ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: _section(
            copy.spore,
            null,
            text.sporePrint!,
            colors,
            key: _sectionKey('spore'),
          ),
        ),
      if ((text.habitat ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: _section(
            copy.habitat,
            null,
            text.habitat!,
            colors,
            key: _sectionKey('habitat'),
          ),
        ),
      if ((text.uses ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: _section(
            copy.uses,
            usesNote,
            text.uses!,
            colors,
            key: _sectionKey('uses'),
          ),
        ),
      if ((text.confusion ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: _section(
            copy.lookalikes,
            null,
            text.confusion!,
            colors,
            key: _sectionKey('lookalikes'),
          ),
        ),
      if ((text.notes ?? '').isNotEmpty)
        SliverToBoxAdapter(
          child: _section(
            copy.notes,
            null,
            text.notes!,
            colors,
            key: _sectionKey('notes'),
          ),
        ),
      if (ranks.isNotEmpty)
        SliverToBoxAdapter(
          child: _Taxonomy(
            key: _sectionKey('taxonomy'),
            title: copy.classification,
            system: copy.taxonomySystem,
            lines: ranks,
          ),
        ),
      SliverToBoxAdapter(
        child: _Sightings(
          key: _sectionKey('sightings'),
          title: copy.statsSightings,
          note: _sightings.isEmpty
              ? null
              : copy.sightingsShared(_sightings.length),
          empty: _sightingsFailed
              ? copy.statsFailed
              : _sightingsReady
              ? copy.statsSightingsEmpty
              : null,
          hint: copy.sightingsHint,
          sightings: _sightings,
          copy: copy,
        ),
      ),
      if (text.sourceUrls.isNotEmpty)
        SliverToBoxAdapter(
          child: _Sources(
            key: _sectionKey('sources'),
            title: copy.sources,
            urls: text.sourceUrls,
          ),
        ),
      SliverToBoxAdapter(
        child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
      ),
      if (Purchases.showsAds()) const SliverToBoxAdapter(child: AppBannerAd()),
    ];
    return Scaffold(
      backgroundColor: colors.paper,
      body: _StatusBarJumpScroll(
        chips: chips,
        onJump: _jump,
        leading: head,
        trailing: tail,
      ),
    );
  }

  GlobalKey _sectionKey(String id) {
    return _sectionKeys.putIfAbsent(id, GlobalKey.new);
  }

  void _jump(String id) {
    final target = _sectionKeys[id]?.currentContext;
    if (target == null) return;
    final position = Scrollable.of(target).position;
    final cover = MediaQuery.paddingOf(context).top + _galleryPillHeight + 24;
    final alignment = ((cover + 16) / position.viewportDimension).clamp(
      0.0,
      0.5,
    );
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: alignment,
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
      unawaited(
        GuideAnalytics.seenSave(
          source: photo.fromPhoto ? 'photo' : 'manual',
          shared: false,
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

  Future<void> _share(String title, String latin) async {
    final copy = GuideScope.of(context).copy;
    final name = Uri.encodeComponent(latin);
    final url = copy.sk
        ? 'https://whatsthatmushroom.app/sk/mushroom/$name/'
        : 'https://whatsthatmushroom.app/mushroom/$name/';
    await SharePlus.instance.share(ShareParams(text: url, subject: title));
  }
}

class _Gallery extends StatefulWidget {
  final String title;
  final List<String> photos;
  final String? plate;
  final double height;
  final bool favorite;
  final Copy copy;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final VoidCallback onShare;

  const _Gallery({
    required this.title,
    required this.photos,
    required this.plate,
    required this.height,
    required this.favorite,
    required this.copy,
    required this.onBack,
    required this.onFavorite,
    required this.onShare,
  });

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final PageController _page = PageController();

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = widget.copy;
    final slides = <_Slide>[
      for (final url in widget.photos) _Slide.photo(url),
      if (widget.plate != null) _Slide.plate(widget.plate!),
    ];
    if (slides.isEmpty) slides.add(const _Slide.photo(null));
    final plateIndex = widget.plate == null ? -1 : widget.photos.length;
    final top = MediaQuery.paddingOf(context).top + 10;
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView(
            controller: _page,
            children: [
              for (final (index, slide) in slides.indexed)
                _slide(colors, slide, index),
            ],
          ),
          PositionedDirectional(
            top: top,
            start: 12,
            end: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _OverlayButton(
                  label: copy.back,
                  onPressed: widget.onBack,
                  icon: const BackButtonIcon(),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OverlayButton(
                      label: widget.favorite
                          ? copy.favoriteRemove
                          : copy.favoriteAdd,
                      onPressed: widget.onFavorite,
                      icon: Icon(
                        widget.favorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 20,
                        color: widget.favorite ? colors.madder : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _OverlayButton(
                      label: copy.share,
                      onPressed: widget.onShare,
                      icon: const Icon(Icons.ios_share, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: 12,
            bottom: _galleryPillInset,
            child: Row(
              children: [for (final pill in _pills(copy, plateIndex)) pill],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slide(GuideColors colors, _Slide slide, int index) {
    final plate = slide.plate;
    // The scan sits on its own paper in both themes, as on the plants page.
    final well = plate ? GuideColors.light.plateWell : colors.photoWell;
    return GestureDetector(
      onTap: slide.url == null
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) =>
                      _PhotoPage(url: slide.url!, plate: plate),
                ),
              );
            },
      child: ColoredBox(
        color: well,
        child: slide.url == null
            ? const SizedBox.expand()
            : Semantics(
                container: true,
                image: true,
                label: plate
                    ? '${widget.title}, ${widget.copy.plate}'
                    : _indexedName(
                        context,
                        widget.title,
                        index,
                        widget.photos.length,
                      ),
                child: ExcludeSemantics(
                  child: GuidePhoto(
                    key: ValueKey(
                      plate ? 'gallery-plate' : 'gallery-photo-$index',
                    ),
                    url: slide.url!,
                    fit: plate ? BoxFit.contain : BoxFit.cover,
                    background: well,
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _pills(Copy copy, int plateIndex) {
    final pills = <Widget>[];
    void add(Widget pill) {
      if (pills.isNotEmpty) pills.add(const SizedBox(width: 6));
      pills.add(pill);
    }

    if (widget.photos.isNotEmpty) {
      add(
        _Pill(
          label: copy.photoCount(widget.photos.length),
          onPressed: () => _go(0),
        ),
      );
    }
    if (plateIndex >= 0) {
      add(_Pill(label: copy.plate, onPressed: () => _go(plateIndex)));
    }
    return pills;
  }

  void _go(int index) {
    if (!_page.hasClients) return;
    _page.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }
}

const double _galleryPillInset = 12;
const double _galleryPillHeight = 48;
const double _galleryButtonExtent = 48;

class _Slide {
  final String? url;
  final bool plate;

  const _Slide.photo(this.url) : plate = false;

  const _Slide.plate(this.url) : plate = true;
}

class _OverlayButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Widget icon;

  const _OverlayButton({
    required this.label,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Tooltip(
      message: label,
      child: Material(
        color: colors.wash,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: _galleryButtonExtent,
            height: _galleryButtonExtent,
            child: IconTheme(
              data: IconThemeData(color: colors.ink, size: 20),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String? spoken;
  final bool filled;
  final VoidCallback onPressed;

  const _Pill({
    super.key,
    required this.label,
    this.spoken,
    this.filled = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final radius = BorderRadius.circular(_galleryPillHeight / 2);
    final chip = Material(
      color: filled ? colors.cream : colors.wash,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        excludeFromSemantics: spoken != null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: filled ? Border.all(color: colors.rule) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: _galleryPillHeight,
              child: Align(
                alignment: Alignment.center,
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final name = spoken;
    if (name == null) return chip;
    return Semantics(
      container: true,
      button: true,
      label: name,
      excludeSemantics: true,
      onTap: onPressed,
      child: chip,
    );
  }
}

class _PhotoPage extends StatelessWidget {
  final String url;
  final bool plate;

  const _PhotoPage({required this.url, required this.plate});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final well = plate ? GuideColors.light.plateWell : colors.photoWell;
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: well,
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: GuidePhoto(
                url: url,
                fit: BoxFit.contain,
                background: well,
              ),
            ),
          ),
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + 10,
            start: 12,
            child: _OverlayButton(
              label: MaterialLocalizations.of(context).closeButtonLabel,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

String _indexedName(BuildContext context, String label, int index, int count) {
  final place = MaterialLocalizations.of(context)
      .tabLabel(tabIndex: index + 1, tabCount: count);
  if (label.isEmpty) return place;
  return '$label, $place';
}

class _NameBlock extends StatelessWidget {
  final String kicker;
  final String title;
  final String latin;
  final String author;
  final bool spoken;
  final List<String> names;
  final Copy copy;

  const _NameBlock({
    required this.kicker,
    required this.title,
    required this.latin,
    required this.author,
    required this.spoken,
    required this.names,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final authority = author.isEmpty
        ? null
        : TextSpan(
            text: ' $author',
            style: TextStyle(
              fontFamily: GuideType.sans,
              fontStyle: FontStyle.normal,
              fontSize: 14,
              color: colors.ink3,
            ),
          );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kicker.isNotEmpty) ...[
            Text(
              kicker,
              style: GuideType.latin(
                colors,
                size: 14,
              ).copyWith(color: colors.gold),
            ),
            const SizedBox(height: 6),
          ],
          if (spoken)
            Text(
              title,
              style: GuideType.spoken(colors, size: 34).copyWith(height: 1.05),
            )
          else
            Text.rich(
              TextSpan(
                style: GuideType.latin(colors, size: 32).copyWith(height: 1.05),
                children: [
                  TextSpan(text: latin),
                  ?authority,
                ],
              ),
            ),
          if (spoken) ...[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                style: GuideType.latin(colors, size: 18),
                children: [
                  TextSpan(text: latin),
                  ?authority,
                ],
              ),
            ),
          ],
          if (names.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${copy.also} ${names.join(', ')}',
              style: TextStyle(
                fontFamily: GuideType.sans,
                fontSize: 14,
                height: 1.4,
                color: colors.ink2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  final String cap;
  final String stipe;
  final String edibility;
  final Color? edibilityColor;
  final String season;
  final int? fruitingFrom;
  final int? fruitingTo;
  final Copy copy;

  const _Facts({
    required this.cap,
    required this.stipe,
    required this.edibility,
    required this.edibilityColor,
    required this.season,
    required this.fruitingFrom,
    required this.fruitingTo,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final now = DateTime.now().month;
    final from = fruitingFrom;
    final to = fruitingTo;
    final months = from == null || to == null
        ? const <int>[]
        : fruitingMonths(from, to);
    final names = copy.sk ? monthsSk : monthsEn;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.rule,
          border: Border.symmetric(horizontal: BorderSide(color: colors.rule)),
        ),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Fact(
                      label: copy.cap,
                      value: cap.isEmpty ? '—' : cap,
                      valueKey: const Key('guide-cap-value'),
                    ),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: _Fact(
                      label: copy.stipe,
                      value: stipe.isEmpty ? '—' : stipe,
                      valueKey: const Key('guide-stipe-value'),
                    ),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: _Fact(
                      label: copy.edibilityLabel,
                      value: edibility.isEmpty ? '—' : edibility,
                      valueColor: edibilityColor,
                      valueKey: const Key('guide-edibility-value'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 1),
            ColoredBox(
              color: colors.paper,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 11, 20, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      season.isEmpty ? copy.season : '${copy.season} $season',
                      style: GuideType.eyebrow(colors),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var month = 1; month <= 12; month++) ...[
                          if (month > 1) const SizedBox(width: 3),
                          Expanded(
                            child: _MonthCell(
                              month: month,
                              on: months.contains(month),
                              now: month == now,
                              letter: names[month - 1].substring(0, 1),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Key? valueKey;

  const _Fact({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return ColoredBox(
      color: colors.paper,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 8, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GuideType.eyebrow(colors)),
            const SizedBox(height: 2),
            Text(
              value,
              key: valueKey,
              style: TextStyle(
                fontFamily: GuideType.display,
                fontWeight: FontWeight.w500,
                fontSize: 18,
                color: valueColor ?? colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final int month;
  final bool on;
  final bool now;
  final String letter;

  const _MonthCell({
    required this.month,
    required this.on,
    required this.now,
    required this.letter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Container(
      key: ValueKey('guide-month-$month'),
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? colors.mossFill : colors.paper2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: now ? colors.madder : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(fontSize: 10, color: on ? Colors.white : colors.ink3),
      ),
    );
  }
}

class _JumpBar extends StatelessWidget {
  final List<({String id, String label})> chips;
  final ValueChanged<String> onJump;
  final ScrollController controller;

  const _JumpBar({
    super.key,
    required this.chips,
    required this.onJump,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return ColoredBox(
      color: colors.paper,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.rule)),
        ),
        child: SingleChildScrollView(
          key: const Key('guide-species-jumps'),
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _Pill(
                  key: Key('guide-jump-${chips[i].id}'),
                  label: chips[i].label,
                  spoken: _indexedName(
                    context,
                    chips[i].label,
                    i,
                    chips.length,
                  ),
                  filled: true,
                  onPressed: () => onJump(chips[i].id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Jump pills scroll with the page until they meet the status bar, then a
/// paper cover holds them just below the clock.
class _StatusBarJumpScroll extends StatefulWidget {
  final List<({String id, String label})> chips;
  final ValueChanged<String> onJump;
  final List<Widget> leading;
  final List<Widget> trailing;

  const _StatusBarJumpScroll({
    required this.chips,
    required this.onJump,
    required this.leading,
    required this.trailing,
  });

  @override
  State<_StatusBarJumpScroll> createState() => _StatusBarJumpScrollState();
}

class _StatusBarJumpScrollState extends State<_StatusBarJumpScroll> {
  final GlobalKey _jumpKey = GlobalKey();
  final ScrollController _page = ScrollController();
  final ScrollController _flowChips = ScrollController();
  final ScrollController _pinnedChips = ScrollController();
  var _cover = false;
  var _syncScheduled = false;
  var _chipPixels = 0.0;
  double? _pinAt;
  var _measuredInset = 0.0;

  @override
  void initState() {
    super.initState();
    _page.addListener(_scheduleSync);
    _flowChips.addListener(_rememberFlow);
    _pinnedChips.addListener(_rememberPinned);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant _StatusBarJumpScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  @override
  void dispose() {
    _page.removeListener(_scheduleSync);
    _flowChips.removeListener(_rememberFlow);
    _pinnedChips.removeListener(_rememberPinned);
    _page.dispose();
    _flowChips.dispose();
    _pinnedChips.dispose();
    super.dispose();
  }

  void _rememberFlow() {
    if (!_cover && _flowChips.hasClients) _chipPixels = _flowChips.offset;
  }

  void _rememberPinned() {
    if (_cover && _pinnedChips.hasClients) _chipPixels = _pinnedChips.offset;
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncCover();
    });
  }

  void _syncCover() {
    if (!mounted || !_page.hasClients || widget.chips.isEmpty) return;
    final topInset = MediaQuery.paddingOf(context).top;
    if (_pinAt != null && _measuredInset != topInset) {
      _pinAt = _pinAt! + _measuredInset - topInset;
    }
    _measuredInset = topInset;
    final box = _jumpKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.attached && box.hasSize) {
      final top = box.localToGlobal(Offset.zero).dy;
      _pinAt = _page.offset + top - topInset;
    }
    final pinAt = _pinAt;
    if (pinAt == null) return;
    final cover = _page.offset >= pinAt - 0.5;
    if (cover == _cover) return;
    setState(() => _cover = cover);
    _restore(cover ? _pinnedChips : _flowChips);
  }

  void _restore(ScrollController controller, {int tries = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      final max = controller.position.maxScrollExtent;
      if (max <= 0 && _chipPixels > 0 && tries < 2) {
        _restore(controller, tries: tries + 1);
        return;
      }
      final target = _chipPixels.clamp(0.0, max);
      if ((controller.offset - target).abs() >= 0.5) {
        controller.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final colors = GuideColors.of(context);
    final chips = widget.chips;
    return Stack(
      children: [
        CustomScrollView(
          key: const Key('guide-species-scroll'),
          controller: _page,
          slivers: [
            for (final child in widget.leading)
              SliverToBoxAdapter(child: child),
            if (chips.isNotEmpty)
              SliverToBoxAdapter(
                child: ExcludeSemantics(
                  excluding: _cover,
                  child: _JumpBar(
                    key: _jumpKey,
                    chips: chips,
                    onJump: widget.onJump,
                    controller: _flowChips,
                  ),
                ),
              ),
            ...widget.trailing,
          ],
        ),
        if (_cover && chips.isNotEmpty)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: ColoredBox(
              key: const Key('guide-species-jump-cover'),
              color: colors.paper,
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: _JumpBar(
                  chips: chips,
                  onJump: widget.onJump,
                  controller: _pinnedChips,
                ),
              ),
            ),
          ),
      ],
    );
  }
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

Widget _section(
  String title,
  String? note,
  String body,
  GuideColors colors, {
  Key? key,
}) {
  return Column(
    key: key,
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

const int _taxonomyRankLimit = 7;

class _TaxonLine {
  final String rank;
  final String label;
  final String latin;
  final String? vernacular;

  const _TaxonLine({
    required this.rank,
    required this.label,
    required this.latin,
    required this.vernacular,
  });

  bool get linked => rank == 'family' || rank == 'genus';
}

/// The seven ranks nearest the species, genus first. Kingdom is omitted.
List<_TaxonLine> _taxonLines(Catalog catalog, Species species, Copy copy) {
  final present = [
    for (final rank in rankOrder)
      if (rank != 'kingdom' && (species.taxonomy[rank] ?? '').isNotEmpty) rank,
  ];
  return [
    for (final rank in present.reversed.take(_taxonomyRankLimit))
      _TaxonLine(
        rank: rank,
        label: copy.rank(rank),
        latin: species.taxonomy[rank]!,
        vernacular: _taxonVernacular(catalog, species.taxonomy[rank]!),
      ),
  ];
}

String? _taxonVernacular(Catalog catalog, String latin) {
  final spoken = displayName(catalog.taxonVernacular(latin), catalog.language);
  if (spoken.isEmpty) return null;
  return spoken;
}

class _Taxonomy extends StatelessWidget {
  final String title;
  final String system;
  final List<_TaxonLine> lines;

  const _Taxonomy({
    super.key,
    required this.title,
    required this.system,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: GuideType.display,
                fontWeight: FontWeight.w500,
                fontSize: 19,
                color: colors.ink,
              ),
              children: [
                TextSpan(text: title),
                TextSpan(
                  text: '  $system',
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final line in lines) _TaxonRow(line: line),
        ],
      ),
    );
  }
}

class _TaxonRow extends StatelessWidget {
  final _TaxonLine line;

  const _TaxonRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final text = Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 14, height: 1.7, color: colors.ink),
        children: [
          TextSpan(
            text: line.label,
            style: TextStyle(color: colors.ink3),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: line.latin,
            style: GuideType.latin(colors).copyWith(fontSize: 14),
          ),
          if (line.vernacular != null) TextSpan(text: ' · ${line.vernacular}'),
        ],
      ),
      key: ValueKey('guide-taxon-${line.rank}'),
    );
    if (!line.linked) return text;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        guideRoute(
          guideTaxonScreen(line.rank),
          (_) => TaxonPage(kind: line.rank, name: line.latin),
        ),
      ),
      child: text,
    );
  }
}

const int _sightingGridCount = 9;

class _Sightings extends StatelessWidget {
  final String title;
  final String? note;
  final String? empty;
  final String hint;
  final List<SpeciesSighting> sightings;
  final Copy copy;

  const _Sightings({
    super.key,
    required this.title,
    required this.note,
    required this.empty,
    required this.hint,
    required this.sightings,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final shown = sightings.take(_sightingGridCount).toList();
    return Padding(
      key: const Key('guide-species-sightings'),
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: GuideType.display,
                fontWeight: FontWeight.w500,
                fontSize: 19,
                color: colors.ink,
              ),
              children: [
                TextSpan(text: title),
                if (note != null)
                  TextSpan(
                    text: '  $note',
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.ink3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (shown.isEmpty && empty != null)
            Text(empty!, style: TextStyle(fontSize: 13, color: colors.ink3))
          else if (shown.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final sighting = shown[index];
                final when = _sightingWhen(sighting.when, copy);
                final country = _sightingCountryName(context, sighting.country);
                return Semantics(
                  container: true,
                  button: true,
                  image: true,
                  label: _indexedName(
                    context,
                    _sightingSpoken(when, country),
                    index,
                    shown.length,
                  ),
                  excludeSemantics: true,
                  onTap: () => _openSighting(context, sighting.url),
                  child: GestureDetector(
                    key: ValueKey('guide-sighting-${sighting.id}'),
                    onTap: () => _openSighting(context, sighting.url),
                    excludeFromSemantics: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GuidePhoto(
                            url: sighting.url,
                            fit: BoxFit.cover,
                            background: colors.photoWell,
                          ),
                          if (country != null)
                            PositionedDirectional(
                              top: 4,
                              start: 4,
                              end: 4,
                              child: Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: _SightingChip(country),
                              ),
                            ),
                          if (when != null)
                            PositionedDirectional(
                              start: 4,
                              bottom: 4,
                              end: 4,
                              child: Align(
                                alignment: AlignmentDirectional.bottomStart,
                                child: _SightingChip(when),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: TextStyle(fontSize: 13, height: 1.4, color: colors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

void _openSighting(BuildContext context, String url) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => _PhotoPage(url: url, plate: false),
    ),
  );
}

String? _sightingWhen(DateTime? when, Copy copy) {
  if (when == null) return null;
  final names = copy.sk ? monthsSk : monthsEn;
  return '${names[when.month - 1]} ${when.year}';
}

String _sightingSpoken(String? when, String? where) {
  final parts = <String>[
    if (when != null && when.isNotEmpty) when,
    if (where != null && where.isNotEmpty) where,
  ];
  return parts.join(' · ');
}

String? _sightingCountryName(BuildContext context, String? code) {
  if (code == null || code.isEmpty) return null;
  final country = Country.tryParse(code.toUpperCase());
  if (country == null) return code.toUpperCase();
  final translated = country.getTranslatedName(context)?.trim();
  if (translated != null && translated.isNotEmpty) return translated;
  final name = country.name.trim();
  if (name.isNotEmpty) return name;
  return code.toUpperCase();
}

class _SightingChip extends StatelessWidget {
  final String text;

  const _SightingChip(this.text);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GuideColors.of(context).wash,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

const int _collapsedSourceCount = 4;
const int _sourceColumns = 4;
const double _sourceGap = 8;
const double _sourceTapExtent = 48;
const _sourcePlain = 'assets/sources/internet.png';

class _SourceLook {
  final String image;
  final String label;
  final bool plain;

  const _SourceLook(this.image, this.label, {this.plain = false});
}

String _sourceAsset(String name) => 'assets/sources/$name';

/// Host shown under a source icon, without the scheme or a leading www.
String _sourceHost(String url) {
  final uri = Uri.tryParse(url.trim());
  var host = (uri == null || uri.host.isEmpty) ? url.trim() : uri.host;
  if (host.startsWith('www.')) host = host.substring(4);
  return host;
}

_SourceLook _sourceLook(String url) {
  const plain = _sourcePlain;
  var image = plain;
  var label = _sourceHost(url);
  if (url.contains('wikipedia')) {
    image = _sourceAsset('wikipedia.png');
    label = 'wikipedia';
  } else if (url.contains('commons.wikimedia.org')) {
    image = _sourceAsset('commons.png');
    label = 'commons';
  } else if (url.contains('wikidata.org')) {
    image = _sourceAsset('wikidata.png');
    label = 'wikidata';
  } else if (url.contains('species.wikimedia.org')) {
    image = _sourceAsset('species.png');
    label = 'species';
  } else if (url.contains('luontoportti.com')) {
    image = _sourceAsset('luontoportti.png');
    label = 'luontoportti.com';
  } else if (url.contains('botany.cz')) {
    image = _sourceAsset('botany.png');
    label = 'botany.cz';
  } else if (url.contains('floranordica.org')) {
    image = _sourceAsset('floranordica.png');
    label = 'floranordica.org';
  } else if (url.contains('efloras.org')) {
    image = _sourceAsset('eflora.png');
    label = 'efloras.org';
  } else if (url.contains('berkeley.edu')) {
    image = _sourceAsset('berkeley.png');
    label = 'berkeley.edu';
  } else if (url.contains('hortipedia.com')) {
    image = _sourceAsset('hortipedia.png');
    label = 'hortipedia.com';
  } else if (url.contains('plants.usda.gov')) {
    image = _sourceAsset('usda.png');
    label = 'plants.usda.gov';
  } else if (url.contains('forestryimages.org')) {
    image = _sourceAsset('usfs.png');
    label = 'forestryimages.org';
  } else if (url.contains('tela-botanica.org')) {
    image = _sourceAsset('tela_botanica.png');
    label = 'tela-botanica.org';
  } else if (url.contains('infoflora.ch')) {
    image = _sourceAsset('infoflora.png');
    label = 'infoflora.ch';
  } else if (url.contains('pladias.cz')) {
    image = _sourceAsset('pladias.png');
    label = 'pladias.cz';
  } else if (url.contains('nativeplanttrust.org')) {
    image = _sourceAsset('gobotany.png');
    label = 'gobotany';
  } else if (url.contains('bsbi.org')) {
    image = _sourceAsset('bsbi.png');
    label = 'bsbi.org';
  } else if (url.contains('burkeherbarium.org') ||
      url.contains('burke.washington.edu')) {
    image = _sourceAsset('burke.png');
    label = 'burke';
  }
  return _SourceLook(image, label, plain: image == plain);
}

class _Sources extends StatefulWidget {
  final String title;
  final List<String> urls;

  const _Sources({super.key, required this.title, required this.urls});

  @override
  State<_Sources> createState() => _SourcesState();
}

class _SourcesState extends State<_Sources> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final links = widget.urls;
    final hidden = links.length - _collapsedSourceCount;
    final shown = _expanded || hidden <= 0
        ? links
        : links.take(_collapsedSourceCount).toList();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontFamily: GuideType.display,
              fontWeight: FontWeight.w500,
              fontSize: 19,
              height: 1,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: _sourceGap),
          _SourceGrid(urls: shown),
          if (hidden > 0) ...[
            const SizedBox(height: _sourceGap),
            Align(
              alignment: Alignment.center,
              child: _SourceMore(
                expanded: _expanded,
                hidden: hidden,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceGrid extends StatelessWidget {
  final List<String> urls;

  const _SourceGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / _sourceColumns;
        final rows = <Widget>[];
        for (var i = 0; i < urls.length; i += _sourceColumns) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: _sourceGap));
          final slice = urls.skip(i).take(_sourceColumns).toList();
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final url in slice)
                  SizedBox(
                    width: width,
                    child: _SourceButton(url: url),
                  ),
                for (var pad = slice.length; pad < _sourceColumns; pad++)
                  SizedBox(width: width),
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _SourceButton extends StatelessWidget {
  final String url;

  const _SourceButton({required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final look = _sourceLook(url);
    return Semantics(
      button: true,
      link: true,
      label: look.label,
      child: InkWell(
        key: ValueKey(url),
        onTap: () => _open(url),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                look.image,
                width: 50,
                height: 50,
                color: look.plain ? colors.ink : null,
                colorBlendMode: look.plain ? BlendMode.srcIn : null,
              ),
              Text(
                look.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, height: 1.15, color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceMore extends StatelessWidget {
  final bool expanded;
  final int hidden;
  final VoidCallback onTap;

  const _SourceMore({
    required this.expanded,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return InkWell(
      key: const Key('guide-sources-more'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _sourceTapExtent,
          minHeight: _sourceTapExtent,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          widthFactor: 1,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: colors.moss,
                ),
                if (!expanded)
                  Text(
                    '+$hidden',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.moss,
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
