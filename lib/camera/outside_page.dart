import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

/// What Outside the book asks the screen underneath to do next.
class OutsideResult {
  final String? message;
  final String? species;
  final bool seen;
  final bool find;

  const OutsideResult.seen(this.message)
    : species = null,
      seen = true,
      find = false;

  const OutsideResult.find()
    : message = null,
      species = null,
      seen = false,
      find = true;

  const OutsideResult.species(this.species, this.message)
    : seen = false,
      find = false;
}

/// A name from a photo whose page is not in the book yet.
class OutsidePage extends StatefulWidget {
  final String recordId;
  final void Function(String latin)? onOpenSpecies;
  final VoidCallback? onSearch;

  const OutsidePage({
    super.key,
    required this.recordId,
    this.onOpenSpecies,
    this.onSearch,
  });

  @override
  State<OutsidePage> createState() => _OutsidePageState();
}

class _OutsidePageState extends State<OutsidePage> {
  var _busy = false;

  FindRecord? _record() {
    for (final item in GuideScope.of(context).notebook.finds) {
      if (item.id == widget.recordId) return item;
    }
    return null;
  }

  Future<void> _keep(FindRecord record) async {
    if (_busy) return;
    setState(() => _busy = true);
    final scope = GuideScope.of(context);
    try {
      await scope.notebook.confirm(record.id);
      if (!mounted) return;
      final when = DateTime.fromMillisecondsSinceEpoch(record.millis);
      Navigator.pop(
        context,
        OutsideResult.seen(
          scope.copy.outsideConfirmed(scope.copy.monthName(when.month)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(FindRecord record) async {
    if (_busy) return;
    setState(() => _busy = true);
    final scope = GuideScope.of(context);
    try {
      await scope.notebook.remove(record.id);
      if (!mounted) return;
      Navigator.pop(context, OutsideResult.seen(scope.copy.outsideDeleted));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _another(FindRecord record, List<FindName> candidates) async {
    if (_busy) return;
    final scope = GuideScope.of(context);
    final chosen = await showOtherNames(
      context: context,
      candidates: candidates,
      onSearch: widget.onSearch,
    );
    if (chosen == null || !mounted) return;
    final species = scope.catalog.data?.byName(chosen.scientificName);
    if (species == null) return;
    setState(() => _busy = true);
    try {
      await scope.notebook.replace(
        record.copyWith(
          latin: species.name,
          dropOutside: true,
          dropSpoken: true,
          confirmed: true,
          probability: chosen.probability,
        ),
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        OutsideResult.species(species.name, scope.copy.outsideChanged),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(String latin) {
    final action = widget.onOpenSpecies;
    if (action != null) {
      action(latin);
      return;
    }
    openSpecies(context, latin, source: GuideMushroomSource.outside);
  }

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final record = _record();
    final colors = GuideColors.of(context);
    if (record == null) {
      return Scaffold(backgroundColor: colors.paper, appBar: AppBar());
    }
    return _page(context, scope, record);
  }

  Widget _page(BuildContext context, GuideScope scope, FindRecord record) {
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    final when = DateTime.fromMillisecondsSinceEpoch(record.millis);
    final wide = _wide(MediaQuery.sizeOf(context));
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final candidates = _inBook(catalog, record.others);
    final shot = _Shot(
      path: record.photoPath,
      whenLabel: _dayLabel(context, copy, when),
      expand: wide,
      onClose: () => Navigator.pop(context, const OutsideResult.find()),
    );
    final text = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Confidence(probability: record.probability),
            const SizedBox(height: 6),
            Text(
              record.outsideName ?? '',
              style: GuideType.latin(colors, size: 30),
            ),
            if (record.spoken != null && record.spoken!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                record.spoken!.trim(),
                style: TextStyle(fontSize: 15, color: colors.ink3),
              ),
            ],
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.paper2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              copy.cameraOutside,
              style: TextStyle(fontSize: 14, height: 1.4, color: colors.ink2),
            ),
          ),
        ),
      ),
      if (candidates.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 10),
          child: Text(copy.cameraInBook, style: GuideType.section(colors)),
        ),
        for (final name in candidates)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10),
            child: _Candidate(
              name: name,
              species: catalog?.byName(name.scientificName),
              catalog: catalog,
              actionLabel: copy.cameraFullPage,
              onOpen: _open,
            ),
          ),
      ],
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.madder, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.confirmed
                      ? copy.outsideConfirmedLine(_clock(context, when))
                      : copy.outsideSaved,
                  style: TextStyle(
                    color: colors.madder,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  copy.outsideSavedDetail(_clock(context, when)),
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.ink3,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!record.confirmed)
                      _Action(
                        key: const Key('guide-outside-keep'),
                        label: copy.outsideKeep,
                        filled: true,
                        onPressed: _busy ? null : () => _keep(record),
                      ),
                    _Action(
                      key: const Key('guide-outside-another'),
                      label: copy.outsideAnother,
                      onPressed: _busy
                          ? null
                          : () => _another(record, candidates),
                    ),
                    _Action(
                      key: const Key('guide-outside-delete'),
                      label: copy.delete,
                      foreground: colors.madder,
                      onPressed: _busy ? null : () => _delete(record),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ];
    return Scaffold(
      key: const Key('guide-outside-page'),
      backgroundColor: colors.paper,
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 105, child: shot),
                Expanded(
                  flex: 95,
                  child: ListView(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    children: text,
                  ),
                ),
              ],
            )
          : ListView(
              padding: EdgeInsets.only(bottom: bottomInset),
              children: [shot, ...text],
            ),
    );
  }
}

List<FindName> _inBook(Catalog? catalog, List<FindName> names) {
  if (catalog == null) return const [];
  return [
    for (final name in names)
      if (catalog.byName(name.scientificName) != null) name,
  ];
}

String _clock(BuildContext context, DateTime when) {
  return MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(when));
}

String _dayLabel(BuildContext context, Copy copy, DateTime when) {
  final now = DateTime.now();
  final same =
      now.year == when.year && now.month == when.month && now.day == when.day;
  if (same) return copy.outsideJustNow;
  return MaterialLocalizations.of(context).formatShortDate(when);
}

bool _wide(Size size) {
  return size.shortestSide >= 650 &&
      size.width > size.height &&
      size.width >= 1000;
}

class _Shot extends StatelessWidget {
  final String? path;
  final String whenLabel;
  final bool expand;
  final VoidCallback onClose;

  const _Shot({
    required this.path,
    required this.whenLabel,
    required this.expand,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final top = MediaQuery.paddingOf(context).top;
    final height = expand
        ? null
        : (MediaQuery.sizeOf(context).shortestSide >= 650 ? 420.0 : 300.0);
    final stack = Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF333333)),
        _photo(path),
        PositionedDirectional(
          top: top + 10,
          start: 12,
          child: Material(
            color: colors.cream.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              key: const Key('guide-outside-close'),
              tooltip: copy.cameraClose,
              onPressed: onClose,
              icon: Icon(Icons.close, color: colors.ink, size: 20),
            ),
          ),
        ),
        PositionedDirectional(
          start: 12,
          bottom: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.cream.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                whenLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (expand) return stack;
    return SizedBox(height: height, child: stack);
  }
}

Widget _photo(String? path) {
  if (path == null || path.isEmpty) return const SizedBox.expand();
  final file = File(path);
  if (!file.existsSync()) return const SizedBox.expand();
  return Image.file(file, fit: BoxFit.cover, width: double.infinity);
}

class _Candidate extends StatelessWidget {
  final FindName name;
  final Species? species;
  final Catalog? catalog;
  final String actionLabel;
  final void Function(String latin) onOpen;

  const _Candidate({
    required this.name,
    required this.species,
    required this.catalog,
    required this.actionLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final book = species;
    final heading = book == null || catalog == null
        ? name.scientificName
        : catalog!.heading(book);
    final showLatin = heading.toLowerCase() != book?.name.toLowerCase();
    final plate = book == null ? '' : cardPlate(book.illustrationUrl);
    return Material(
      color: colors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: book == null ? null : () => onOpen(book.name),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: GuidePhoto(url: plate, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Confidence(probability: name.probability),
                    const SizedBox(height: 2),
                    Text(
                      heading,
                      style: TextStyle(
                        fontFamily: GuideType.display,
                        fontWeight: FontWeight.w500,
                        fontSize: 17,
                        color: colors.ink,
                      ),
                    ),
                    if (showLatin && book != null)
                      Text(book.name, style: GuideType.latin(colors, size: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                actionLabel,
                style: TextStyle(
                  color: colors.moss,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Confidence extends StatelessWidget {
  final double? probability;

  const _Confidence({required this.probability});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final value = probability ?? 0;
    final Color color;
    final String label;
    final int filled;
    if (value >= 0.5) {
      color = colors.moss;
      label = copy.likely;
      filled = 3;
    } else if (value >= 0.2) {
      color = colors.gold;
      label = copy.possible;
      filled = 2;
    } else {
      color = colors.ink3;
      label = copy.uncertain;
      filled = 1;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: 6,
            height: 12,
            decoration: BoxDecoration(
              color: i < filled ? color : colors.rule,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final bool filled;
  final Color? foreground;
  final VoidCallback? onPressed;

  const _Action({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        backgroundColor: filled ? colors.mossFill : colors.cream,
        foregroundColor: filled ? Colors.white : (foreground ?? colors.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: filled ? BorderSide.none : BorderSide(color: colors.rule),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

/// Other names for this photo. Returns the name the person chose.
Future<FindName?> showOtherNames({
  required BuildContext context,
  required List<FindName> candidates,
  VoidCallback? onSearch,
}) {
  return showModalBottomSheet<FindName>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final scope = GuideScope.of(sheetContext);
      final colors = GuideColors.of(sheetContext);
      final copy = scope.copy;
      final catalog = scope.catalog.data;
      final tablet = MediaQuery.sizeOf(sheetContext).shortestSide >= 650;
      return Padding(
        padding: tablet ? const EdgeInsets.all(32) : EdgeInsets.zero,
        child: Align(
          alignment: tablet ? Alignment.center : Alignment.bottomCenter,
          child: Material(
            color: colors.paper,
            borderRadius: tablet
                ? BorderRadius.circular(22)
                : const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: tablet ? 520 : 800),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!tablet)
                        Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.rule,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const SizedBox(width: 36, height: 4),
                          ),
                        ),
                      if (!tablet) const SizedBox(height: 12),
                      Text(
                        copy.outsideWhich,
                        style: TextStyle(
                          fontFamily: GuideType.display,
                          fontWeight: FontWeight.w500,
                          fontSize: 23,
                          height: 1.12,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        copy.outsideWhichBody,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: colors.ink2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final name in candidates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _Candidate(
                            name: name,
                            species: catalog?.byName(name.scientificName),
                            catalog: catalog,
                            actionLabel: copy.outsideChoose,
                            onOpen: (_) => Navigator.pop(sheetContext, name),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          key: const Key('guide-outside-search'),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            onSearch?.call();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: colors.ink,
                            backgroundColor: colors.cream,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                              side: BorderSide(color: colors.rule),
                            ),
                          ),
                          child: Text(copy.outsideSearch),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
