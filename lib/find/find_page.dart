import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/camera/camera_page.dart';
import 'package:whats_that_mushroom/data/new_book.dart';
import 'package:whats_that_mushroom/find/key_glyph.dart';
import 'package:whats_that_mushroom/find/strips.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/key_filter.dart';
import 'package:whats_that_mushroom/key/key_pages.dart';
import 'package:whats_that_mushroom/person/person_page.dart';
import 'package:whats_that_mushroom/search/search_page.dart';
import 'package:whats_that_mushroom/lists/curated_lists_section.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

class FindPage extends StatelessWidget {
  const FindPage({super.key});

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
    final counts = optionCounts(catalog.species, const KeySelection(), 'under');
    final recent = scope.notebook.finds.take(5).toList();
    final fresh = newInBook(catalog.species);
    final favorites =
        [
          for (final latin in scope.notebook.favorites)
            if (catalog.byName(latin) != null) catalog.byName(latin)!,
        ]..sort(
          (a, b) =>
              catalog.compareTitles(catalog.heading(a), catalog.heading(b)),
        );
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _TitleBar(
          copy: copy,
          colors: colors,
          onPerson: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PersonPage())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: colors.cream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: colors.rule),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SearchPage())),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: colors.ink2, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        copy.searchHint,
                        style: GuideType.muted(colors),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _CameraCard(
          copy: copy,
          colors: colors,
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CameraPage())),
        ),
        _KeyCard(
          copy: copy,
          colors: colors,
          counts: counts,
          onUnder: (id) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WherePage(selection: KeySelection(under: id)),
            ),
          ),
        ),
        if (recent.isNotEmpty) ...[
          SectionHeader(
            title: copy.seenLately,
            action: copy.allFinds,
            onAction: () => scope.selectTab(2),
          ),
          SeenStrip(
            copy: copy,
            catalog: catalog,
            finds: recent,
            onOpenSeen: () => scope.selectTab(2),
          ),
        ],
        if (favorites.isNotEmpty || fresh.isNotEmpty) ...[
          SectionHeader(title: copy.listsTitle),
          ListStrip(
            copy: copy,
            catalog: catalog,
            favorites: favorites,
            fresh: fresh,
          ),
        ],
        const CuratedListsSection(),
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  final Copy copy;
  final GuideColors colors;
  final VoidCallback onPerson;

  const _TitleBar({
    required this.copy,
    required this.colors,
    required this.onPerson,
  });

  @override
  Widget build(BuildContext context) {
    final title = GuideType.wordmark(colors).copyWith(
      fontWeight: FontWeight.w500,
      fontSize: 21,
      letterSpacing: -0.4,
      height: 1.1,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: title,
                children: [
                  TextSpan(text: copy.brandLead),
                  TextSpan(
                    text: copy.brandName,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                      color: colors.madder,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: copy.person,
            excludeSemantics: true,
            onTap: onPerson,
            child: Tooltip(
              message: copy.person,
              child: Material(
                color: colors.cream,
                shape: CircleBorder(side: BorderSide(color: colors.rule)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPerson,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.person_outline,
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

class _CameraCard extends StatelessWidget {
  final Copy copy;
  final GuideColors colors;
  final VoidCallback onTap;

  const _CameraCard({
    required this.copy,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onCard = colors.onMoss;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
      child: Material(
        color: colors.moss,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.cameraTitle,
                        style: TextStyle(
                          fontFamily: GuideType.display,
                          fontWeight: FontWeight.w500,
                          fontSize: 21,
                          height: 1.1,
                          color: onCard,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        copy.cameraBody,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          fontSize: 13,
                          height: 1.3,
                          color: onCard.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var i = 0; i < 5; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: onCard,
                                border: Border.all(color: onCard, width: 1.5),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              copy.cameraFree,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: GuideType.sans,
                                fontSize: 12,
                                height: 1.2,
                                color: onCard.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: onCard,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: colors.moss,
                      size: 28,
                    ),
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

class _KeyCard extends StatelessWidget {
  final Copy copy;
  final GuideColors colors;
  final Map<String, int> counts;
  final ValueChanged<String> onUnder;

  const _KeyCard({
    required this.copy,
    required this.colors,
    required this.counts,
    required this.onUnder,
  });

  @override
  Widget build(BuildContext context) {
    final rows = (underChoices.length + 3) ~/ 4;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepLine(copy: copy, colors: colors),
          const SizedBox(height: 8),
          const _KeyStepper(filled: 1, steps: 3),
          const SizedBox(height: 12),
          Text(copy.underQuestion, style: GuideType.question(colors)),
          const SizedBox(height: 6),
          Text(copy.underNote, style: GuideType.muted(colors)),
          const SizedBox(height: 14),
          for (var row = 0; row < rows; row++) ...[
            if (row > 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < 4; column++) ...[
                    if (column > 0) const SizedBox(width: 8),
                    Expanded(child: _cell(row * 4 + column)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(int index) {
    if (index >= underChoices.length) return const SizedBox.shrink();
    final id = underChoices[index];
    final count = counts[id] ?? 0;
    return _UnderPill(
      label: copy.underLabel(id),
      example: copy.underExample(id),
      count: count,
      glyph: id,
      colors: colors,
      onTap: count > 0 ? () => onUnder(id) : null,
    );
  }
}

class _StepLine extends StatelessWidget {
  final Copy copy;
  final GuideColors colors;

  const _StepLine({required this.copy, required this.colors});

  @override
  Widget build(BuildContext context) {
    final stepStyle = GuideType.eyebrow(colors);
    final freeStyle = stepStyle.copyWith(color: colors.moss);
    return Row(
      children: [
        Flexible(
          child: Text(
            copy.keyStep.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stepStyle,
          ),
        ),
        const SizedBox(width: 8),
        Text(copy.keyFree.toUpperCase(), maxLines: 1, style: freeStyle),
      ],
    );
  }
}

class _KeyStepper extends StatelessWidget {
  final int filled;
  final int steps;

  const _KeyStepper({required this.filled, required this.steps});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Row(
      children: [
        for (var i = 0; i < steps; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: i < filled ? colors.madder : colors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(height: 3),
            ),
          ),
        ],
      ],
    );
  }
}

class _UnderPill extends StatelessWidget {
  final String label;
  final String example;
  final int count;
  final String glyph;
  final GuideColors colors;
  final VoidCallback? onTap;

  const _UnderPill({
    required this.label,
    required this.example,
    required this.count,
    required this.glyph,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.38 : 1,
      child: Material(
        color: colors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.rule),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      KeyGlyph(id: glyph, color: colors.moss, size: 40),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          height: 1.2,
                          color: colors.ink,
                        ),
                      ),
                      if (example.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          example,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: GuideType.sans,
                            fontSize: 12,
                            height: 1.3,
                            color: colors.ink2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                top: 4,
                end: 5,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 12,
                    color: colors.ink2,
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
