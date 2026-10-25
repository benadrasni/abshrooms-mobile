import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/camera/camera_page.dart';
import 'package:whats_that_mushroom/camera/outside_page.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/field_guide/field_guide_page.dart';
import 'package:whats_that_mushroom/person/auth.dart';
import 'package:whats_that_mushroom/person/sign_in_page.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/search/search_page.dart';
import 'package:whats_that_mushroom/seen/publish.dart';
import 'package:whats_that_mushroom/seen/share.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

const _monthsShortEn = [
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

const _monthsShortSk = [
  'jan',
  'feb',
  'mar',
  'apr',
  'máj',
  'jún',
  'júl',
  'aug',
  'sep',
  'okt',
  'nov',
  'dec',
];

const _hideSharedKey = 'seen_hide_shared';

/// The on-device notebook, laid out like the plants Seen page.
///
/// Unconfirmed finds stay at the top. Confirmed finds group by month.
/// A confirmed photo in the book can be sent as a Sighting. The notebook
/// itself stays on this phone.
class SeenPage extends StatefulWidget {
  /// Overrides the signed-in account. Tests pass this so they never touch
  /// Firebase Auth.
  final bool? signedIn;

  final Future<bool> Function(FindRecord find)? onShare;
  final Future<bool> Function(FindRecord find)? onWithdraw;
  final Future<bool> Function(FindRecord find)? onRemoveSent;

  /// Overrides the remembered Hide shared choice.
  final bool? hideShared;

  const SeenPage({
    super.key,
    this.signedIn,
    this.onShare,
    this.onWithdraw,
    this.onRemoveSent,
    this.hideShared,
  });

  @override
  State<SeenPage> createState() => _SeenPageState();
}

class _SeenPageState extends State<SeenPage> {
  final Set<String> _busy = {};
  Notebook? _notebook;
  bool? _hideShared;
  var _synced = false;

  @override
  void initState() {
    super.initState();
    Purchases.revision.addListener(_onChange);
    if (widget.hideShared == null) unawaited(_loadHide());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notebook = GuideScope.of(context).notebook;
    if (identical(notebook, _notebook)) return;
    _notebook?.removeListener(_onChange);
    _notebook = notebook;
    notebook.addListener(_onChange);
    if (_synced) return;
    _synced = true;
    unawaited(_syncShares());
  }

  @override
  void dispose() {
    Purchases.revision.removeListener(_onChange);
    _notebook?.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  bool get _hidingShared {
    final chosen = _hideShared;
    if (chosen != null) return chosen;
    return widget.hideShared ?? false;
  }

  bool get _signedIn {
    final chosen = widget.signedIn;
    if (chosen != null) return chosen;
    return readSignedInAccount() != null;
  }

  Future<void> _loadHide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_hideSharedKey) ?? false;
      if (!mounted || _hideShared != null || !stored) return;
      setState(() => _hideShared = true);
    } catch (error) {
      debugPrint('seen hide: $error');
    }
  }

  Future<void> _toggleHide() async {
    final next = !_hidingShared;
    setState(() => _hideShared = next);
    if (widget.hideShared != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hideSharedKey, next);
    } catch (error) {
      debugPrint('seen hide: $error');
    }
  }

  Future<void> _syncShares() async {
    if (widget.onShare != null || widget.signedIn == false) return;
    final notebook = _notebook;
    if (notebook == null) return;
    await syncSightings(notebook);
  }

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final finds = scope.notebook.finds;
    final sharedCount = seenSharedCount(finds);
    final hiding = _hidingShared && sharedCount > 0;
    final visible = hiding ? seenHidingShared(finds).toList() : finds;
    final groups = _arrange(visible);
    final tiles = _tiles(
      copy,
      groups,
      finds: finds,
      hiding: hiding,
      sharedCount: sharedCount,
      fieldGuide: Purchases.hasFieldGuide(),
    );
    final lines = _lines(context, tiles);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: lines.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Title(
            title: copy.seen,
            subtitle: hiding
                ? copy.seenSubtitleHidden(visible.length, sharedCount)
                : copy.seenSubtitle(visible.length),
            cameraLabel: copy.cameraTitle,
            onCamera: _openCamera,
          );
        }
        final line = lines[index - 1];
        final kind = line.first.kind;
        final paired = kind == _Kind.confirm || kind == _Kind.find;
        if (paired && _pairs(context)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: i < line.length
                      ? _tile(
                          context,
                          line[i],
                          hiding: hiding,
                          sharedCount: sharedCount,
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          );
        }
        return _tile(
          context,
          line.single,
          hiding: hiding,
          sharedCount: sharedCount,
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    _Tile tile, {
    required bool hiding,
    required int sharedCount,
  }) {
    final copy = GuideScope.of(context).copy;
    final colors = GuideColors.of(context);
    switch (tile.kind) {
      case _Kind.empty:
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
          child: Text(
            copy.seenEmpty,
            style: TextStyle(
              fontFamily: GuideType.sans,
              fontSize: 13,
              color: colors.ink3,
            ),
          ),
        );
      case _Kind.confirmHead:
        return _MonthLabel(text: tile.text!, color: colors.madder);
      case _Kind.confirm:
        final find = tile.find!;
        return _ConfirmCard(
          find: find,
          face: _face(find),
          detail: _detail(copy, find),
          busy: _busy.contains(find.id),
          onOpen: () => unawaited(_open(find)),
          onConfirm: () => unawaited(_confirm(find)),
          onAnother: () => unawaited(_another(find)),
          onDelete: () => unawaited(_delete(find)),
        );
      case _Kind.month:
        return _MonthLabel(text: tile.text!);
      case _Kind.hide:
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 0),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _Pill(
              key: const Key('guide-seen-hide-shared'),
              label: hiding
                  ? copy.seenSharedHidden(sharedCount)
                  : copy.seenHideShared(sharedCount),
              onPressed: () => unawaited(_toggleHide()),
              foreground: hiding ? Colors.white : colors.ink,
              background: hiding ? colors.mossFill : colors.cream,
              border: hiding ? null : colors.rule,
            ),
          ),
        );
      case _Kind.onlyShared:
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
          child: Text(
            copy.seenOnlyShared,
            style: TextStyle(
              fontFamily: GuideType.sans,
              fontSize: 13,
              color: colors.ink3,
            ),
          ),
        );
      case _Kind.find:
        final find = tile.find!;
        final chip = seenChip(
          find,
          inBook: _inBook(find),
          catalogKnown: GuideScope.of(context).catalog.data != null,
        );
        final opens = chip == SeenChip.outside || _inBook(find);
        return _FindRow(
          find: find,
          face: _face(find),
          detail: _detail(copy, find),
          busy: _busy.contains(find.id),
          chip: chip,
          onOpen: opens ? () => unawaited(_open(find)) : null,
          onShare: () => unawaited(_share(find)),
          onWithdraw: () => unawaited(_withdraw(find)),
          onDelete: () => unawaited(_askDelete(find)),
        );
      case _Kind.upsell:
        return _Upsell(onPressed: _openFieldGuide);
    }
  }

  /// Two finds share a line on a landscape tablet. A phone stays one column.
  bool _pairs(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide >= 650 && size.width > size.height;
  }

  List<List<_Tile>> _lines(BuildContext context, List<_Tile> tiles) {
    if (!_pairs(context)) {
      return [
        for (final tile in tiles) [tile],
      ];
    }
    final lines = <List<_Tile>>[];
    final pending = <_Tile>[];
    void flush() {
      if (pending.isEmpty) return;
      lines.add(List.of(pending));
      pending.clear();
    }

    for (final tile in tiles) {
      final pair = tile.kind == _Kind.confirm || tile.kind == _Kind.find;
      if (!pair || (pending.isNotEmpty && pending.first.kind != tile.kind)) {
        flush();
      }
      if (!pair) {
        lines.add([tile]);
        continue;
      }
      pending.add(tile);
      if (pending.length == 2) flush();
    }
    flush();
    return lines;
  }

  List<_Tile> _tiles(
    Copy copy,
    _Groups groups, {
    required List<FindRecord> finds,
    required bool hiding,
    required int sharedCount,
    required bool fieldGuide,
  }) {
    final tiles = <_Tile>[];
    if (finds.isEmpty) tiles.add(const _Tile(_Kind.empty));
    if (groups.unconfirmed.isNotEmpty) {
      tiles.add(
        _Tile(
          _Kind.confirmHead,
          text: '${copy.toConfirm} · ${groups.unconfirmed.length}'
              .toUpperCase(),
        ),
      );
      for (final find in groups.unconfirmed) {
        tiles.add(_Tile(_Kind.confirm, find: find));
      }
    }
    if (sharedCount > 0) tiles.add(const _Tile(_Kind.hide));
    if (hiding && groups.total == 0) tiles.add(const _Tile(_Kind.onlyShared));
    for (final month in groups.months) {
      tiles.add(
        _Tile(
          _Kind.month,
          text: '${copy.monthName(month.month.month)} ${month.month.year}'
              .toUpperCase(),
        ),
      );
      for (final find in month.finds) {
        tiles.add(_Tile(_Kind.find, find: find));
      }
    }
    if (!fieldGuide) tiles.add(const _Tile(_Kind.upsell));
    return tiles;
  }

  _Face _face(FindRecord find) {
    final catalog = GuideScope.of(context).catalog.data;
    final latin = find.latin?.trim() ?? '';
    final species = catalog == null || latin.isEmpty
        ? null
        : catalog.byName(latin);
    if (species != null && catalog != null) {
      final title = catalog.heading(species);
      final spoken = title != species.name;
      return _Face(
        title: title,
        spoken: spoken,
        latin: spoken ? species.name : null,
      );
    }
    final common = find.spoken?.trim() ?? '';
    final scientific = (find.outsideName ?? find.latin ?? '').trim();
    if (common.isNotEmpty) {
      return _Face(
        title: common,
        spoken: true,
        latin: scientific.isEmpty ? null : scientific,
      );
    }
    return _Face(title: scientific, spoken: false);
  }

  bool _inBook(FindRecord find) {
    final latin = find.latin?.trim() ?? '';
    if (latin.isEmpty) return false;
    final catalog = GuideScope.of(context).catalog.data;
    return catalog != null && catalog.byName(latin) != null;
  }

  void _openCamera() {
    Navigator.of(context).push(
      guideRoute<void>(guideScreenCamera, (_) => const CameraPage()),
    );
  }

  void _openFieldGuide() {
    Navigator.of(context).push(
      guideRoute<void>(guideScreenFieldGuide, (_) => const FieldGuidePage()),
    );
  }

  Future<void> _open(FindRecord find) async {
    final catalog = GuideScope.of(context).catalog.data;
    final latin = find.latin?.trim() ?? '';
    if (latin.isNotEmpty) {
      if (catalog == null) return;
      if (catalog.byName(latin) != null) {
        openSpecies(context, latin, source: GuideMushroomSource.seen);
        return;
      }
    }
    final outside = find.outsideName?.trim() ?? '';
    if (outside.isEmpty) return;
    final result = await Navigator.of(context).push<OutsideResult>(
      guideRoute(
        guideScreenOutside,
        (_) => OutsidePage(
          recordId: find.id,
          onSearch: () {
            Navigator.of(
              context,
            ).push(
              guideRoute<void>(guideScreenSearch, (_) => const SearchPage()),
            );
          },
        ),
      ),
    );
    if (!mounted || result == null) return;
    final message = result.message;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    final species = result.species;
    if (species != null) {
      openSpecies(context, species, source: GuideMushroomSource.seen);
    }
  }

  Future<void> _confirm(FindRecord find) async {
    if (!_busy.add(find.id)) return;
    setState(() {});
    final copy = GuideScope.of(context).copy;
    try {
      await GuideScope.of(context).notebook.confirm(find.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(copy.seenConfirmed)));
    } catch (error) {
      debugPrint('seen confirm: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(GuideScope.of(context).copy.seenFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(find.id));
    }
  }

  Future<void> _another(FindRecord find) async {
    if (_busy.contains(find.id)) return;
    final catalog = GuideScope.of(context).catalog.data;
    final candidates = catalog == null
        ? const <FindName>[]
        : [
            for (final name in find.others)
              if (catalog.byName(name.scientificName) != null) name,
          ];
    final chosen = await showOtherNames(
      context: context,
      candidates: candidates,
      onSearch: () {
        if (!mounted) return;
        Navigator.of(context)
            .push(
              guideRoute<void>(guideScreenSearch, (_) => const SearchPage()),
            );
      },
    );
    if (!mounted || chosen == null) return;
    final species = GuideScope.of(context).catalog.data
        ?.byName(chosen.scientificName);
    if (species == null) return;
    if (!_busy.add(find.id)) return;
    setState(() {});
    try {
      await GuideScope.of(context).notebook.replace(
        find.copyWith(
          latin: species.name,
          dropOutside: true,
          dropSpoken: true,
          confirmed: true,
          probability: chosen.probability,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(GuideScope.of(context).copy.outsideChanged)),
      );
    } catch (error) {
      debugPrint('seen another: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(GuideScope.of(context).copy.seenFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(find.id));
    }
  }

  String _deleteBody(Copy copy, FindRecord find) {
    switch (find.share) {
      case FindShare.shared:
        return copy.seenDeleteShared;
      case FindShare.review:
      case FindShare.rejected:
        return copy.seenDeleteSent;
      case FindShare.none:
        return copy.seenDeleteBody;
    }
  }

  Future<void> _share(FindRecord find) async {
    if (!seenPhotoOnPhone(find.photoPath)) return;
    if (!_signedIn) {
      await Navigator.of(context).push<void>(
        guideRoute<void>(guideScreenSignIn, (_) => const SignInPage()),
      );
      if (!mounted || !_signedIn) return;
    }
    final copy = GuideScope.of(context).copy;
    final face = _face(find);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _sheetFrame(
          sheetContext,
          _ShareSheet(
            find: find,
            title: copy.seenShareTitle(face.title),
            latin: face.spoken ? find.latin?.trim() : null,
            detail: _detail(copy, find),
            onSend: () => unawaited(_sendShare(sheetContext, find)),
          ),
        );
      },
    );
  }

  Future<void> _sendShare(BuildContext sheetContext, FindRecord find) async {
    Navigator.pop(sheetContext);
    final action = widget.onShare;
    final ok = action != null
        ? await action(find)
        : await publishSighting(find);
    if (!mounted) return;
    if (ok) {
      await GuideScope.of(context).notebook.setShare(find.id, FindShare.review);
      unawaited(GuideAnalytics.seenSave(source: 'photo', shared: true));
    }
    if (!mounted) return;
    final copy = GuideScope.of(context).copy;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? copy.seenShareSent : copy.seenShareFailed)),
    );
  }

  Future<void> _withdraw(FindRecord find) async {
    final copy = GuideScope.of(context).copy;
    final face = _face(find);
    final review = find.share == FindShare.review;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _sheetFrame(
          sheetContext,
          _WithdrawSheet(
            title: review
                ? copy.seenWithdrawReviewTitle
                : copy.seenIsSighting(face.title),
            body: review ? copy.seenWithdrawReviewBody : copy.seenWithdrawBody,
            onWithdraw: () {
              Navigator.pop(sheetContext);
              unawaited(_sendWithdraw(find));
            },
          ),
        );
      },
    );
  }

  Future<void> _sendWithdraw(FindRecord find) async {
    if (!_busy.add(find.id)) return;
    setState(() {});
    try {
      final action = widget.onWithdraw;
      final ok = action != null
          ? await action(find)
          : await withdrawSighting(find);
      if (!mounted) return;
      if (ok) {
        await GuideScope.of(context).notebook.setShare(find.id, FindShare.none);
      }
      if (!mounted) return;
      final copy = GuideScope.of(context).copy;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? copy.seenWithdrawn : copy.seenShareFailed),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(find.id));
    }
  }

  Future<void> _askDelete(FindRecord find) async {
    if (_busy.contains(find.id)) return;
    final copy = GuideScope.of(context).copy;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final size = MediaQuery.sizeOf(sheetContext);
        final tablet = size.shortestSide >= 650;
        final sheet = _DeleteSheet(
          title: copy.deleteAsk,
          body: _deleteBody(copy, find),
          onDelete: () {
            Navigator.pop(sheetContext);
            unawaited(_delete(find));
          },
        );
        if (!tablet) return sheet;
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: sheet,
            ),
          ),
        );
      },
    );
  }

  Future<void> _delete(FindRecord find) async {
    if (!_busy.add(find.id)) return;
    setState(() {});
    try {
      if (find.share != FindShare.none) {
        final action = widget.onRemoveSent;
        final removed = action != null
            ? await action(find)
            : await deleteSighting(find);
        if (!removed) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(GuideScope.of(context).copy.seenDeleteFailed),
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      await GuideScope.of(context).notebook.remove(find.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(GuideScope.of(context).copy.outsideDeleted)),
      );
    } catch (error) {
      debugPrint('seen delete: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(GuideScope.of(context).copy.seenDeleteFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(find.id));
    }
  }
}

class _Groups {
  final List<FindRecord> unconfirmed;
  final List<_Month> months;

  const _Groups({required this.unconfirmed, required this.months});

  int get total =>
      unconfirmed.length +
      months.fold<int>(0, (count, month) => count + month.finds.length);
}

class _Month {
  final DateTime month;
  final List<FindRecord> finds;

  const _Month({required this.month, required this.finds});
}

/// Unconfirmed finds stay at the top. Confirmed finds group by month,
/// newest month first.
_Groups _arrange(List<FindRecord> finds) {
  final unconfirmed = <FindRecord>[];
  final grouped = <DateTime, List<FindRecord>>{};
  for (final find in finds) {
    if (!find.confirmed) {
      unconfirmed.add(find);
      continue;
    }
    final when = DateTime.fromMillisecondsSinceEpoch(find.millis);
    final month = DateTime(when.year, when.month);
    grouped.putIfAbsent(month, () => []).add(find);
  }
  unconfirmed.sort(_newest);
  final months = [
    for (final entry in grouped.entries)
      _Month(month: entry.key, finds: [...entry.value]..sort(_newest)),
  ]..sort((a, b) => b.month.compareTo(a.month));
  return _Groups(unconfirmed: unconfirmed, months: months);
}

int _newest(FindRecord a, FindRecord b) {
  final byWhen = b.millis.compareTo(a.millis);
  if (byWhen != 0) return byWhen;
  return a.id.compareTo(b.id);
}

String _detail(Copy copy, FindRecord find) {
  final date = DateTime.fromMillisecondsSinceEpoch(find.millis);
  final month = (copy.sk ? _monthsShortSk : _monthsShortEn)[date.month - 1];
  if (copy.sk) return '${date.day}. $month';
  return '$month ${date.day}';
}

enum _Kind { empty, confirmHead, confirm, hide, onlyShared, month, find, upsell }

Widget _sheetFrame(BuildContext context, Widget sheet) {
  final size = MediaQuery.sizeOf(context);
  if (size.shortestSide < 650) return sheet;
  return Padding(
    padding: const EdgeInsets.all(32),
    child: Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: sheet,
      ),
    ),
  );
}

class _Tile {
  final _Kind kind;
  final FindRecord? find;
  final String? text;

  const _Tile(this.kind, {this.find, this.text});
}

class _Face {
  final String title;
  final bool spoken;
  final String? latin;

  const _Face({required this.title, required this.spoken, this.latin});
}

class _Title extends StatelessWidget {
  final String title;
  final String subtitle;
  final String cameraLabel;
  final VoidCallback onCamera;

  const _Title({
    required this.title,
    required this.subtitle,
    required this.cameraLabel,
    required this.onCamera,
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
                    color: colors.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: cameraLabel,
            excludeSemantics: true,
            onTap: onCamera,
            child: Tooltip(
              message: cameraLabel,
              child: Material(
                color: colors.cream,
                shape: CircleBorder(side: BorderSide(color: colors.rule)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('guide-seen-camera'),
                  onTap: onCamera,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 20,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const _MonthLabel({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 6),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 12,
          letterSpacing: 0.96,
          fontWeight: FontWeight.w600,
          color: color ?? colors.ink3,
        ),
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  final FindRecord find;
  final _Face face;
  final String detail;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onConfirm;
  final VoidCallback onAnother;
  final VoidCallback onDelete;

  const _ConfirmCard({
    required this.find,
    required this.face,
    required this.detail,
    required this.busy,
    required this.onOpen,
    required this.onConfirm,
    required this.onAnother,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final latin = face.latin;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.rule),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              InkWell(
                onTap: busy ? null : onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _Photo(path: find.photoPath, size: 74, radius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (find.probability != null) ...[
                              _ConfidenceMark(probability: find.probability),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              face.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: face.spoken
                                  ? TextStyle(
                                      fontFamily: GuideType.display,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18,
                                      height: 1.1,
                                      color: colors.ink,
                                    )
                                  : GuideType.latin(
                                      colors,
                                      size: 18,
                                    ).copyWith(height: 1.1),
                            ),
                            if (latin != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                latin,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GuideType.latin(
                                  colors,
                                  size: 13,
                                ).copyWith(color: colors.ink3),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Text(
                              detail,
                              style: TextStyle(
                                fontFamily: GuideType.sans,
                                fontSize: 12,
                                color: colors.ink3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.rule)),
                ),
                child: Row(
                  children: [
                    _CardAction(
                      key: Key('guide-seen-confirm-${find.id}'),
                      label: copy.confirm,
                      color: colors.moss,
                      busy: busy,
                      onPressed: onConfirm,
                    ),
                    _CardAction(
                      key: Key('guide-seen-another-${find.id}'),
                      label: copy.seenAnother,
                      color: colors.moss,
                      busy: busy,
                      onPressed: onAnother,
                    ),
                    _CardAction(
                      key: Key('guide-seen-delete-${find.id}'),
                      label: copy.delete,
                      color: colors.madder,
                      last: true,
                      busy: busy,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final String label;
  final Color color;
  final bool last;
  final bool busy;
  final VoidCallback onPressed;

  const _CardAction({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.last = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: last
              ? null
              : BorderDirectional(end: BorderSide(color: colors.rule)),
        ),
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: SizedBox(
            height: 42,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FindRow extends StatelessWidget {
  final FindRecord find;
  final _Face face;
  final String detail;
  final bool busy;
  final SeenChip? chip;
  final VoidCallback? onOpen;
  final VoidCallback onShare;
  final VoidCallback onWithdraw;
  final VoidCallback onDelete;

  const _FindRow({
    required this.find,
    required this.face,
    required this.detail,
    required this.busy,
    required this.chip,
    required this.onOpen,
    required this.onShare,
    required this.onWithdraw,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 9, 20, 9),
      child: Row(
        children: [
          InkWell(
            onTap: onOpen,
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: _Photo(path: find.photoPath, size: 44, radius: 8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    face.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: face.spoken
                        ? TextStyle(
                            fontFamily: GuideType.sans,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colors.ink,
                          )
                        : GuideType.latin(colors, size: 15),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 13,
                      color: colors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chip != null) ...[
                  Flexible(
                    child: _ShareChip(
                      find: find,
                      chip: chip!,
                      onShare: onShare,
                      onWithdraw: onWithdraw,
                      onOutside: onOpen,
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
                TextButton(
                  key: Key('guide-seen-row-delete-${find.id}'),
                  onPressed: busy ? null : onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.madder,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(copy.delete),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareChip extends StatelessWidget {
  final FindRecord find;
  final SeenChip chip;
  final VoidCallback onShare;
  final VoidCallback onWithdraw;
  final VoidCallback? onOutside;

  const _ShareChip({
    required this.find,
    required this.chip,
    required this.onShare,
    required this.onWithdraw,
    required this.onOutside,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    switch (chip) {
      case SeenChip.share:
        return _Pill(
          key: Key('guide-seen-share-${find.id}'),
          label: copy.share,
          onPressed: onShare,
          foreground: colors.ink,
          background: colors.cream,
          border: colors.rule,
        );
      case SeenChip.shared:
        return _Pill(
          key: Key('guide-seen-shared-${find.id}'),
          label: copy.seenShared,
          onPressed: onWithdraw,
          foreground: Colors.white,
          background: colors.mossFill,
        );
      case SeenChip.review:
        return _Pill(
          key: Key('guide-seen-review-${find.id}'),
          label: copy.seenInReview,
          onPressed: onWithdraw,
          foreground: colors.gold,
          background: Color.alphaBlend(
            colors.gold.withValues(alpha: 0.14),
            colors.cream,
          ),
        );
      case SeenChip.rejected:
        return _Status(
          label: copy.seenNotAccepted,
          foreground: colors.madder,
          background: Color.alphaBlend(
            colors.madder.withValues(alpha: 0.14),
            colors.cream,
          ),
        );
      case SeenChip.outside:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('guide-seen-outside-${find.id}'),
            onTap: onOutside,
            borderRadius: BorderRadius.circular(12),
            child: _Status(
              label: copy.seenNotInBook,
              foreground: colors.ink3,
              background: colors.paper2,
            ),
          ),
        );
    }
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color foreground;
  final Color background;
  final Color? border;

  const _Pill({
    super.key,
    required this.label,
    required this.onPressed,
    required this.foreground,
    required this.background,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: border == null ? BorderSide.none : BorderSide(color: border!),
        ),
        textStyle: const TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ShareSheet extends StatefulWidget {
  final FindRecord find;
  final String title;
  final String? latin;
  final String detail;
  final VoidCallback onSend;

  const _ShareSheet({
    required this.find,
    required this.title,
    required this.latin,
    required this.detail,
    required this.onSend,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  var _consent = false;

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 650;
    final latin = widget.latin;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: tablet
            ? BorderRadius.circular(22)
            : const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!tablet) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.rule,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                _Photo(path: widget.find.photoPath, size: 64, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: GuideType.section(colors)),
                      if (latin != null && latin.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          latin,
                          style: GuideType.latin(
                            colors,
                            size: 13,
                          ).copyWith(color: colors.ink3),
                        ),
                      ],
                      Text(
                        widget.detail,
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
            const SizedBox(height: 14),
            _Fact(copy.seenShareReviewed),
            _Fact(copy.seenSharePlace),
            _Fact(copy.seenShareNote),
            _Fact(copy.seenShareAnytime),
            const SizedBox(height: 8),
            InkWell(
              key: const Key('guide-seen-consent'),
              onTap: () => setState(() => _consent = !_consent),
              borderRadius: BorderRadius.circular(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.rule),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _consent ? colors.mossFill : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _consent ? colors.mossFill : colors.ink3,
                            width: 1.5,
                          ),
                        ),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: _consent
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          copy.seenShareConsent,
                          style: TextStyle(
                            fontFamily: GuideType.sans,
                            fontSize: 14,
                            height: 1.4,
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('guide-seen-send'),
              onPressed: _consent ? widget.onSend : null,
              style: FilledButton.styleFrom(
                backgroundColor: colors.mossFill,
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.mossFill.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(copy.seenShareSend),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String text;

  const _Fact(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 14,
          height: 1.45,
          color: colors.ink2,
        ),
      ),
    );
  }
}

class _WithdrawSheet extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onWithdraw;

  const _WithdrawSheet({
    required this.title,
    required this.body,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 650;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: tablet
            ? BorderRadius.circular(22)
            : const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!tablet) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.rule,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(title, style: GuideType.question(colors)),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontFamily: GuideType.sans,
                fontSize: 15,
                height: 1.4,
                color: colors.ink2,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('guide-seen-withdraw'),
              onPressed: onWithdraw,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.madder,
                side: BorderSide(color: colors.rule),
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(copy.seenWithdraw),
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;

  const _Status({
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: GuideType.sans,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _Upsell extends StatelessWidget {
  final VoidCallback onPressed;

  const _Upsell({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.mossFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.seenUpsellTitle,
                style: TextStyle(
                  fontFamily: GuideType.display,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  color: colors.onMoss,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                copy.seenUpsellBody,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 14,
                  height: 1.4,
                  color: colors.onMoss.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('guide-seen-upsell'),
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: colors.mossFill,
                  backgroundColor: colors.onMoss,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(copy.offlineSeeGuide),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteSheet extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onDelete;

  const _DeleteSheet({
    required this.title,
    required this.body,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 650;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: tablet
            ? BorderRadius.circular(22)
            : const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!tablet) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.rule,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(title, style: GuideType.question(colors)),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontFamily: GuideType.sans,
                fontSize: 15,
                height: 1.4,
                color: colors.ink2,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('guide-seen-delete-confirm'),
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.madder,
                side: BorderSide(color: colors.rule),
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(copy.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String? path;
  final double size;
  final double radius;

  const _Photo({required this.path, required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final file = path == null || path!.isEmpty ? null : File(path!);
    final ready = file != null && file.existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: ready
            ? Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: colors.paper2),
              )
            : ColoredBox(color: colors.paper2),
      ),
    );
  }
}

class _ConfidenceMark extends StatelessWidget {
  final double? probability;

  const _ConfidenceMark({required this.probability});

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
            fontFamily: GuideType.sans,
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
