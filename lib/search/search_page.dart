import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/book/taxon_page.dart';
import 'package:whats_that_mushroom/camera/camera_page.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/search.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

class SearchPage extends StatefulWidget {
  final bool fromBook;

  const SearchPage({super.key, this.fromBook = false});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _keyOut() {
    if (widget.fromBook) {
      GuideScope.of(context).selectTab(0);
    }
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final catalog = scope.catalog.data;
    final sections = catalog == null
        ? const SearchSections()
        : searchSections(catalog, _query.text);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _BackButton(label: widget.fromBook ? copy.book : copy.find),
            _QueryField(
              controller: _query,
              hint: copy.searchFieldHint,
              onChanged: (_) => setState(() {}),
            ),
            Expanded(
              child: _body(
                catalog: catalog,
                scope: scope,
                copy: copy,
                sections: sections,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({
    required Catalog? catalog,
    required GuideScope scope,
    required Copy copy,
    required SearchSections sections,
  }) {
    if (catalog == null) {
      return CatalogMessage(
        copy: copy,
        error: scope.catalog.error,
        onRetry: scope.reload,
      );
    }
    if (foldName(_query.text).length < 2) return const SizedBox.shrink();
    if (sections.isEmpty) {
      return _Empty(
        sentence: copy.searchEmpty,
        photo: copy.searchTryPhoto,
        keyLabel: copy.searchKeyOut,
        onPhoto: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CameraPage())),
        onKey: _keyOut,
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (sections.mushrooms.isNotEmpty) ...[
          _SectionLabel(copy.mushroomsSection),
          for (final hit in sections.mushrooms) _mushroom(catalog, hit),
        ],
        if (sections.genera.isNotEmpty) ...[
          _SectionLabel(copy.genera),
          for (final hit in sections.genera) _taxon(catalog, hit),
        ],
        if (sections.families.isNotEmpty) ...[
          _SectionLabel(copy.families),
          for (final hit in sections.families) _taxon(catalog, hit),
        ],
      ],
    );
  }

  Widget _mushroom(Catalog catalog, SearchHit hit) {
    final species = catalog.byName(hit.name);
    if (species == null) return const SizedBox.shrink();
    final title = catalog.heading(species);
    final spoken = title != species.name;
    final plate = species.photoUrls.isEmpty;
    final url = plate
        ? cardPlate(species.illustrationUrl)
        : mediaUrl(species.photoUrls.first);
    return _ResultRow(
      title: title,
      latin: spoken ? species.name : null,
      url: url,
      plate: plate,
      onTap: () => openSpecies(context, species.name),
    );
  }

  Widget _taxon(Catalog catalog, SearchHit hit) {
    final title = catalog.taxonTitle(hit.name);
    final spoken = title != hit.name;
    return _ResultRow(
      title: title,
      latin: spoken ? hit.name : null,
      url: familyIcon(_plateFamily(catalog, hit)),
      plate: true,
      count: catalog.countOf(hit.kind, hit.name),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TaxonPage(kind: hit.kind, name: hit.name),
        ),
      ),
    );
  }
}

String _plateFamily(Catalog catalog, SearchHit hit) {
  if (hit.kind == 'family') return hit.name;
  for (final item in catalog.species) {
    if (item.genus == hit.name && item.family.isNotEmpty) return item.family;
  }
  return '';
}

class _BackButton extends StatelessWidget {
  final String label;

  const _BackButton({required this.label});

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
                  label,
                  style: TextStyle(
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

class _QueryField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _QueryField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.moss, width: 1.5),
        ),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.search, size: 20, color: colors.ink2),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  cursorColor: colors.moss,
                  textInputAction: TextInputAction.search,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontFamily: GuideType.sans,
                    fontSize: 16,
                    color: colors.ink,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 16,
                      color: colors.ink2,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 2),
      child: Text(title.toUpperCase(), style: GuideType.eyebrow(colors)),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String title;
  final String? latin;
  final String url;
  final bool plate;
  final int? count;
  final VoidCallback onTap;

  const _ResultRow({
    required this.title,
    required this.latin,
    required this.url,
    required this.plate,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final showLatin = latin != null && latin!.isNotEmpty && latin != title;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 9, 20, 9),
        child: Row(
          children: [
            _Thumb(url: url, plate: plate),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: showLatin
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
                  if (showLatin)
                    Text(
                      latin!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GuideType.latin(
                        colors,
                      ).copyWith(fontSize: 13, height: 1.2, color: colors.ink2),
                    ),
                ],
              ),
            ),
            if (count != null) ...[
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
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final bool plate;

  const _Thumb({required this.url, required this.plate});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: GuidePhoto(
          url: url,
          fit: plate ? BoxFit.contain : BoxFit.cover,
          background: plate ? colors.cream : colors.paper2,
        ),
      ),
    );
    if (!plate) return photo;
    return Container(
      width: 44,
      height: 44,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.rule),
      ),
      child: photo,
    );
  }
}

class _Empty extends StatelessWidget {
  final String sentence;
  final String photo;
  final String keyLabel;
  final VoidCallback onPhoto;
  final VoidCallback onKey;

  const _Empty({
    required this.sentence,
    required this.photo,
    required this.keyLabel,
    required this.onPhoto,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.paper2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: GuideType.sans,
              fontSize: 14,
              height: 1.4,
              color: colors.ink2,
            ),
            children: _spans(),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _spans() {
    final spans = <InlineSpan>[];
    var rest = sentence;
    while (rest.isNotEmpty) {
      final photoAt = rest.indexOf(photo);
      final keyAt = rest.indexOf(keyLabel);
      final photoFirst = photoAt >= 0 && (keyAt < 0 || photoAt <= keyAt);
      final at = photoFirst ? photoAt : keyAt;
      if (at < 0) {
        spans.add(TextSpan(text: rest));
        break;
      }
      if (at > 0) spans.add(TextSpan(text: rest.substring(0, at)));
      final token = photoFirst ? photo : keyLabel;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _Link(text: token, onTap: photoFirst ? onPhoto : onKey),
        ),
      );
      rest = rest.substring(at + token.length);
    }
    return spans;
  }
}

class _Link extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _Link({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: GuideType.sans,
          color: colors.moss,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }
}
