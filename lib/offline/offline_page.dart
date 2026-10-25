import 'dart:async';

import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/field_guide/field_guide_page.dart';
import 'package:whats_that_mushroom/offline/offline_book.dart';
import 'package:whats_that_mushroom/offline/offline_plan.dart';
import 'package:whats_that_mushroom/purchase/purchases.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

const offlineEverythingKey = Key('guide-offline-all');
const offlineDownloadKey = Key('guide-offline-get');
const offlineRemoveKey = Key('guide-offline-remove');
const offlinePauseKey = Key('guide-offline-pause');
const offlineUpdateKey = Key('guide-offline-update');

class OfflineJob {
  final String title;
  final int species;
  final int doneMb;
  final int totalMb;

  const OfflineJob({
    required this.title,
    required this.species,
    required this.doneMb,
    required this.totalMb,
  });

  double get fraction {
    if (totalMb <= 0) return 0;
    return (doneMb / totalMb).clamp(0, 1);
  }
}

typedef OfflineStarter = Future<OfflineStart> Function({
  required OfflineRequest request,
  required void Function(int done, int total) onProgress,
  required void Function() onFinished,
  required void Function() onFailed,
});

/// The whole book, kept on this phone. There is no regional pack.
class OfflinePage extends StatefulWidget {
  final OfflineView? view;
  final OfflineJob? job;
  final Future<void> Function()? onFieldGuide;
  final Future<void> Function(OfflineRequest request)? onDownload;
  final Future<void> Function()? onUpdate;
  final Future<void> Function()? onRemove;
  final Future<void> Function()? onPause;
  final OfflineStarter? start;

  const OfflinePage({
    super.key,
    this.view,
    this.job,
    this.onFieldGuide,
    this.onDownload,
    this.onUpdate,
    this.onRemove,
    this.onPause,
    this.start,
  });

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  OfflineView? _view;
  OfflineJob? _job;
  var _selected = false;
  var _loading = true;
  var _failed = false;
  var _ticket = 0;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    final ready = widget.view;
    if (ready != null) {
      _view = ready;
      _loading = false;
    } else {
      Purchases.revision.addListener(_onPlan);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  @override
  void didUpdateWidget(OfflinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.view;
    if (next != null && next != oldWidget.view) {
      _view = next;
      _loading = false;
      _failed = false;
    }
    if (widget.job != oldWidget.job && _job == oldWidget.job) {
      _job = widget.job;
    }
  }

  @override
  void dispose() {
    if (widget.view == null) Purchases.revision.removeListener(_onPlan);
    super.dispose();
  }

  void _onPlan() {
    final view = _view;
    if (!mounted || view == null) return;
    final allowed = Purchases.hasFieldGuide();
    if (allowed == view.canDownload) return;
    setState(() => _view = view.copyWith(canDownload: allowed));
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    final scope = GuideScope.of(context);
    try {
      if (scope.catalog.data == null || scope.catalog.error != null) {
        await scope.catalog.load(scope.settings.language);
      }
      if (!mounted || ticket != _ticket) return;
      final catalog = scope.catalog.data;
      if (catalog == null) {
        throw scope.catalog.error ?? StateError('catalog');
      }
      setState(() {
        _view = offlineViewOf(
          species: catalog.species,
          canDownload: Purchases.hasFieldGuide(),
          stored: OfflineBook.stored,
          saved: OfflineBook.saved,
          skipped: OfflineBook.skipped,
        );
        _loading = false;
        _failed = false;
      });
    } catch (error) {
      debugPrint('offline: $error');
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _loading = false;
        _failed = _view == null;
      });
    }
  }

  Future<void> _download(OfflineRequest request) async {
    if (request.pending.isEmpty && !request.markStored) return;
    final custom = widget.onDownload;
    if (custom != null) {
      await custom(request);
      return;
    }
    final copy = GuideScope.of(context).copy;
    final bar = _barMb(request);
    final scope = request.update ? 'update' : 'everything';
    var finished = false;
    try {
      final started = await (widget.start ?? _engine)(
        request: request,
        onProgress: (done, _) {
          if (!mounted) return;
          setState(() {
            _job = OfflineJob(
              title: request.title,
              species: request.species,
              doneMb: _doneMb(request, done, bar),
              totalMb: bar,
            );
          });
        },
        onFinished: () {
          finished = true;
          unawaited(GuideAnalytics.offlinePack(scope: scope, result: 'ok'));
          if (!mounted) return;
          setState(() {
            _job = null;
            _selected = false;
            _refresh();
          });
        },
        onFailed: () {
          unawaited(GuideAnalytics.offlinePack(scope: scope, result: 'fail'));
          if (!mounted) return;
          setState(() => _job = null);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(copy.offlineDownloadFailed)));
        },
      );
      if (!mounted || finished) return;
      if (started == OfflineStart.needsWifi) {
        unawaited(GuideAnalytics.offlinePack(scope: scope, result: 'wifi'));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(copy.offlineWifi)));
        return;
      }
      if (started == OfflineStart.started && _job == null) {
        setState(() {
          _job = OfflineJob(
            title: request.title,
            species: request.species,
            doneMb: 0,
            totalMb: bar,
          );
        });
      }
    } catch (error) {
      debugPrint('offline: $error');
      unawaited(GuideAnalytics.offlinePack(scope: scope, result: 'fail'));
      if (!mounted) return;
      setState(() => _job = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(copy.offlineDownloadFailed)));
    }
  }

  Future<OfflineStart> _engine({
    required OfflineRequest request,
    required void Function(int done, int total) onProgress,
    required void Function() onFinished,
    required void Function() onFailed,
  }) {
    final scope = GuideScope.of(context);
    return startOfflineDownload(
      request: request,
      onProgress: onProgress,
      onFinished: onFinished,
      onFailed: onFailed,
      warm: () => warmOfflineWords(scope.catalog, scope.settings.language),
    );
  }

  void _refresh() {
    final view = _view;
    final catalog = GuideScope.of(context).catalog.data;
    if (view == null) return;
    if (catalog == null) {
      _view = view.copyWith(stored: OfflineBook.stored);
      return;
    }
    _view = offlineViewOf(
      species: catalog.species,
      canDownload: view.canDownload,
      stored: OfflineBook.stored,
      saved: OfflineBook.saved,
      skipped: OfflineBook.skipped,
    );
  }

  Future<void> _pause() async {
    final custom = widget.onPause;
    if (custom != null) {
      await custom();
      return;
    }
    OfflineBook.pause();
    if (mounted) setState(() => _job = null);
  }

  Future<void> _remove() async {
    final custom = widget.onRemove;
    if (custom != null) {
      await custom();
      return;
    }
    final copy = GuideScope.of(context).copy;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.offlineTitle),
        content: Text(copy.offlineRemoveAsk),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(copy.yes),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await OfflineBook.clear();
    if (!mounted) return;
    setState(() {
      _job = null;
      _selected = false;
      _refresh();
    });
  }

  Future<void> _openFieldGuide() async {
    final custom = widget.onFieldGuide;
    if (custom != null) {
      await custom();
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const FieldGuidePage()));
    _onPlan();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackButton(),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.moss,
                ),
              ),
            ),
          ),
        ],
      );
    }
    final view = _view;
    if (_failed || view == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackButton(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    copy.offlineLoadFailed,
                    style: TextStyle(color: colors.ink2),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _failed = false;
                      });
                      unawaited(_load());
                    },
                    child: Text(copy.retry),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return _content(context, view);
  }

  Widget _content(BuildContext context, OfflineView view) {
    final copy = GuideScope.of(context).copy;
    final colors = GuideColors.of(context);
    final job = _job;
    final bookSize = offlineAbout(copy, OfflineAmount.ofSpecies(view.species));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              const _BackButton(),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.fieldGuide.toUpperCase(),
                      style: GuideType.eyebrow(colors),
                    ),
                    const SizedBox(height: 4),
                    Text(copy.offlineTitle, style: GuideType.question(colors)),
                    const SizedBox(height: 8),
                    Text(
                      copy.offlineIntro,
                      style: TextStyle(
                        fontFamily: GuideType.sans,
                        fontSize: 14,
                        height: 1.4,
                        color: colors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!view.canDownload) _Upsell(onPressed: _openFieldGuide),
              if (job != null)
                _JobCard(
                  job: job,
                  species: copy.count(job.species),
                  onPause: _pause,
                ),
              if (view.stored)
                _KeptCard(
                  detail: copy.offlineKept(
                    copy.offlineEverything,
                    copy.count(view.species),
                    bookSize,
                  ),
                  onRemove: _remove,
                ),
              if (view.hasUpdate && job == null)
                _UpdateCard(
                  detail: copy.offlineAdd(
                    copy.count(view.missingSpecies),
                    offlineAbout(
                      copy,
                      OfflineAmount.ofBytes(
                        offlineUpdateBytes(view.missingSpecies),
                      ),
                    ),
                  ),
                  label: view.canDownload
                      ? copy.offlineUpdate
                      : copy.fieldGuide,
                  onPressed: () => _onUpdate(view),
                ),
              _Pack(
                key: offlineEverythingKey,
                on: _selected,
                title: copy.offlineEverything,
                meta: copy.count(view.species),
                size: view.stored ? copy.offlineOnPhone : bookSize,
                onPressed: () => setState(() => _selected = !_selected),
              ),
            ],
          ),
        ),
        _Bar(
          view: view,
          selected: _selected,
          busy: job != null,
          onPressed: () => _onGet(view),
        ),
      ],
    );
  }

  Future<void> _onGet(OfflineView view) async {
    if (!_selected || view.pending.isEmpty) return;
    if (!view.canDownload) {
      await _openFieldGuide();
      return;
    }
    final copy = GuideScope.of(context).copy;
    await _download(
      OfflineRequest(
        title: copy.offlineEverything,
        species: view.species,
        pending: view.pending,
        alreadyDone: view.alreadyDone,
        totalFiles: view.totalFiles,
        markStored: true,
        update: false,
      ),
    );
  }

  Future<void> _onUpdate(OfflineView view) async {
    if (!view.hasUpdate || _job != null) return;
    if (!view.canDownload) {
      await _openFieldGuide();
      return;
    }
    final custom = widget.onUpdate;
    if (custom != null) {
      await custom();
      return;
    }
    final copy = GuideScope.of(context).copy;
    await _download(
      OfflineRequest(
        title: copy.offlineUpdate,
        species: view.missingSpecies,
        pending: view.pending,
        alreadyDone: view.alreadyDone,
        totalFiles: view.totalFiles,
        markStored: true,
        update: true,
      ),
    );
  }
}

int _barMb(OfflineRequest request) {
  if (request.update) {
    return OfflineAmount.ofBytes(offlineUpdateBytes(request.species)).barMb;
  }
  return OfflineAmount.ofSpecies(request.species).barMb;
}

int _doneMb(OfflineRequest request, int done, int bar) {
  final span = request.update ? request.pending.length : request.totalFiles;
  final finished = request.update ? done - request.alreadyDone : done;
  if (span <= 0 || bar <= 0) return 0;
  final value = (bar * finished / span).round();
  if (value < 0) return 0;
  if (value > bar) return bar;
  return value;
}

class _Upsell extends StatelessWidget {
  final Future<void> Function() onPressed;

  const _Upsell({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.rule),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.offlineUpsellTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                copy.offlineUpsellBody,
                style: TextStyle(color: colors.ink2, height: 1.35),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => onPressed(),
                style: TextButton.styleFrom(
                  foregroundColor: colors.moss,
                  backgroundColor: colors.mossFill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  copy.offlineSeeGuide,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final OfflineJob job;
  final String species;
  final Future<void> Function() onPause;

  const _JobCard({
    required this.job,
    required this.species,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.rule),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.offlineDownloading(job.title),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    key: offlinePauseKey,
                    onPressed: onPause,
                    style: TextButton.styleFrom(foregroundColor: colors.moss),
                    child: Text(
                      copy.offlinePause,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Text(
                copy.offlineProgress(
                  '${job.doneMb}',
                  '${job.totalMb}',
                  species,
                ),
                style: TextStyle(fontSize: 13, color: colors.ink3),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: job.fraction,
                  minHeight: 8,
                  backgroundColor: colors.paper2,
                  color: colors.mossFill,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.offlineProgressNote,
                style: TextStyle(fontSize: 13, color: colors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeptCard extends StatelessWidget {
  final String detail;
  final Future<void> Function() onRemove;

  const _KeptCard({required this.detail, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.rule),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.offlineOnPhone,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(fontSize: 13, color: colors.ink3),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: offlineRemoveKey,
                onPressed: onRemove,
                style: TextButton.styleFrom(foregroundColor: colors.madder),
                child: Text(
                  copy.offlineRemove,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final String detail;
  final String label;
  final Future<void> Function() onPressed;

  const _UpdateCard({
    required this.detail,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.rule),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.offlineUpdate,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(fontSize: 13, color: colors.ink3),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: offlineUpdateKey,
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: colors.mossFill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pack extends StatelessWidget {
  final bool on;
  final String title;
  final String meta;
  final String size;
  final VoidCallback onPressed;

  const _Pack({
    super.key,
    required this.on,
    required this.title,
    required this.meta,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: colors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: on ? colors.moss : colors.rule,
            width: on ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Box(on: on),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: GuideType.display,
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                          height: 1.15,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        style: TextStyle(fontSize: 13, color: colors.ink3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  size,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

class _Box extends StatelessWidget {
  final bool on;

  const _Box({required this.on});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: on ? colors.mossFill : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: on ? colors.moss : colors.ink3, width: 1.5),
      ),
      child: SizedBox(
        width: 22,
        height: 22,
        child: on
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final OfflineView view;
  final bool selected;
  final bool busy;
  final VoidCallback onPressed;

  const _Bar({
    required this.view,
    required this.selected,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final ready = selected && view.pending.isNotEmpty && !busy;
    final adding = view.stored ? view.missingSpecies : view.species;
    final size = view.stored
        ? offlineAbout(copy, OfflineAmount.ofBytes(offlineUpdateBytes(adding)))
        : offlineAbout(copy, OfflineAmount.ofSpecies(adding));
    final title = selected ? copy.offlineEverything : copy.offlineChoose;
    final String meta;
    if (!selected) {
      meta = copy.offlineChooseNote;
    } else if (view.pending.isEmpty) {
      meta = copy.offlineAlready;
    } else if (!view.canDownload) {
      meta = copy.offlineAddGuide(copy.count(adding), size);
    } else {
      meta = copy.offlineAdd(copy.count(adding), size);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: colors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            if (!busy) ...[
              const SizedBox(width: 12),
              Opacity(
                opacity: ready ? 1 : 0.45,
                child: TextButton(
                  key: offlineDownloadKey,
                  onPressed: ready ? onPressed : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: colors.mossFill,
                    disabledBackgroundColor: colors.mossFill,
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    view.canDownload ? copy.offlineDownload : copy.fieldGuide,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

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
                  GuideScope.of(context).copy.back,
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
