import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/key_filter.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

class WherePage extends StatelessWidget {
  final KeySelection selection;

  const WherePage({super.key, required this.selection});

  @override
  Widget build(BuildContext context) {
    final copy = GuideScope.of(context).copy;
    return _KeyAxisPage(
      selection: selection,
      axis: 'where',
      question: copy.whereQuestion,
      note: copy.keyLede,
      anywhere: true,
      next: (selection) => ColorPage(selection: selection),
    );
  }
}

class ColorPage extends StatelessWidget {
  final KeySelection selection;

  const ColorPage({super.key, required this.selection});

  @override
  Widget build(BuildContext context) {
    final copy = GuideScope.of(context).copy;
    return _KeyAxisPage(
      selection: selection,
      axis: 'color',
      question: copy.colorQuestion,
      note: copy.colorNote,
      anywhere: false,
      next: (selection) => ResultsPage(selection: selection),
    );
  }
}

class _KeyAxisPage extends StatefulWidget {
  final KeySelection selection;
  final String axis;
  final String question;
  final String note;
  final bool anywhere;
  final Widget Function(KeySelection selection) next;

  const _KeyAxisPage({
    required this.selection,
    required this.axis,
    required this.question,
    required this.note,
    required this.anywhere,
    required this.next,
  });

  @override
  State<_KeyAxisPage> createState() => _KeyAxisPageState();
}

class _KeyAxisPageState extends State<_KeyAxisPage> {
  late KeySelection _selection = widget.selection;

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    if (catalog == null) {
      return Scaffold(
        backgroundColor: colors.paper,
        appBar: AppBar(),
        body: CatalogMessage(
          copy: copy,
          error: scope.catalog.error,
          onRetry: scope.reload,
        ),
      );
    }
    final counts = optionCounts(catalog.species, _selection, widget.axis);
    final matched = catalog.species
        .where((item) => matchesSelection(item, _selection))
        .length;
    final openWhere = _selection.copyWith(where: '');
    final anywhereCount = catalog.species
        .where((item) => matchesSelection(item, openWhere))
        .length;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: Text(widget.question, style: GuideType.spoken(colors, size: 22)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          if (widget.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(widget.note, style: GuideType.body(colors)),
            ),
          if (_path(copy).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(_path(copy), style: GuideType.muted(colors)),
            ),
          if (widget.anywhere)
            KeyChoice(
              label: copy.anyWhere,
              example: '',
              count: anywhereCount,
              selected: _selection.where.isEmpty,
              enabled: true,
              onTap: () =>
                  setState(() => _selection = _selection.copyWith(where: '')),
            ),
          for (final id in choicesFor(widget.axis))
            KeyChoice(
              label: _label(copy, id),
              example: _example(copy, id),
              count: counts[id] ?? 0,
              selected: _selection.axis(widget.axis) == id,
              enabled:
                  (counts[id] ?? 0) > 0 || _selection.axis(widget.axis) == id,
              mark: widget.axis == 'color' ? _swatch(id, colors) : null,
              onTap: () => setState(
                () => _selection = _selection.toggle(widget.axis, id),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => widget.next(_selection))),
            child: Text(copy.count(matched)),
          ),
        ),
      ),
    );
  }

  String _path(Copy copy) {
    final parts = <String>[
      if (widget.axis != 'under' && _selection.under.isNotEmpty)
        copy.underLabel(_selection.under),
      if (widget.axis != 'where' && _selection.where.isNotEmpty)
        copy.whereLabel(_selection.where),
    ];
    return parts.join(' · ');
  }

  String _label(Copy copy, String id) {
    return widget.axis == 'color' ? copy.colorLabel(id) : copy.whereLabel(id);
  }

  String _example(Copy copy, String id) {
    return widget.axis == 'where' ? copy.whereExample(id) : '';
  }
}

class ResultsPage extends StatefulWidget {
  final KeySelection selection;

  const ResultsPage({super.key, required this.selection});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late KeySelection _selection = widget.selection;
  var _seasonOpen = false;

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    if (catalog == null) {
      return Scaffold(
        backgroundColor: colors.paper,
        appBar: AppBar(),
        body: CatalogMessage(
          copy: copy,
          error: scope.catalog.error,
          onRetry: scope.reload,
        ),
      );
    }
    final month = DateTime.now().month;
    final matches = [
      for (final item in catalog.species)
        if (matchesSelection(item, _selection)) item,
    ];
    final rows = orderedResults(catalog, matches, _selection, month);
    final seasonCounts = optionCounts(catalog.species, _selection, 'season');
    final anyCount = catalog.species
        .where(
          (item) => matchesSelection(item, _selection.copyWith(season: '')),
        )
        .length;
    final now = [
      for (final item in rows)
        if (item.fruitsIn(month)) item,
    ];
    final later = [
      for (final item in rows)
        if (!item.fruitsIn(month)) item,
    ];
    final split =
        _selection.season.isEmpty && now.isNotEmpty && later.isNotEmpty;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: Text(
          copy.count(matches.length),
          style: GuideType.spoken(colors, size: 22),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  label: Text(
                    _selection.season.isEmpty
                        ? copy.anySeason
                        : copy.seasonLabel(_selection.season),
                  ),
                  onPressed: () => setState(() => _seasonOpen = !_seasonOpen),
                ),
                for (final chip in _chips(copy)) chip,
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text(copy.startOver),
                ),
              ],
            ),
          ),
          if (_seasonOpen) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                copy.seasonQuestion,
                style: GuideType.spoken(colors, size: 22),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(copy.seasonNote, style: GuideType.muted(colors)),
            ),
            KeyChoice(
              label: copy.anySeason,
              example: '',
              count: anyCount,
              selected: _selection.season.isEmpty,
              enabled: true,
              onTap: () =>
                  setState(() => _selection = _selection.copyWith(season: '')),
            ),
            for (final id in seasonChoices)
              KeyChoice(
                label: copy.seasonLabel(id),
                example: '',
                count: seasonCounts[id] ?? 0,
                selected: _selection.season == id,
                enabled: (seasonCounts[id] ?? 0) > 0 || _selection.season == id,
                onTap: () => setState(
                  () => _selection = _selection.toggle('season', id),
                ),
              ),
          ],
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                copy.keyEmpty,
                style: GuideType.body(colors),
                textAlign: TextAlign.center,
              ),
            )
          else if (split) ...[
            _group(copy.fruitingNow, colors),
            for (final item in now) _row(context, catalog, item),
            _group(copy.later, colors),
            for (final item in later) _row(context, catalog, item),
          ] else
            for (final item in rows) _row(context, catalog, item),
        ],
      ),
    );
  }

  List<Widget> _chips(Copy copy) {
    final chips = <Widget>[];
    void add(String axis, String label) {
      if (label.isEmpty) return;
      chips.add(
        ActionChip(
          label: Text(label),
          onPressed: () => setState(
            () => _selection = _selection.toggle(axis, _selection.axis(axis)),
          ),
        ),
      );
    }

    add(
      'under',
      _selection.under.isEmpty ? '' : copy.underLabel(_selection.under),
    );
    add(
      'where',
      _selection.where.isEmpty ? '' : copy.whereLabel(_selection.where),
    );
    add(
      'color',
      _selection.color.isEmpty ? '' : copy.colorLabel(_selection.color),
    );
    return chips;
  }
}

Widget _group(String title, GuideColors colors) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(title, style: GuideType.spoken(colors, size: 20)),
  );
}

Widget _row(BuildContext context, Catalog catalog, Species species) {
  return SpeciesRow(
    catalog: catalog,
    species: species,
    onTap: () => openSpecies(context, species.name),
  );
}

Widget _swatch(String id, GuideColors colors) {
  return Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: colorSwatch(id),
      shape: BoxShape.circle,
      border: Border.all(color: colors.rule),
    ),
  );
}
