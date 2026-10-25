import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/find/strips.dart';
import 'package:whats_that_mushroom/lists/curated_list_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';

/// Curated-list cards. Hides itself when the language has no lists, or when
/// Firestore denies the read because the rule is not published yet.
class CuratedListsSection extends StatefulWidget {
  final bool book;
  final Future<CuratedListsSnapshot> Function() loadLists;

  const CuratedListsSection({
    super.key,
    this.book = false,
    this.loadLists = fetchCuratedLists,
  });

  @override
  State<CuratedListsSection> createState() => _CuratedListsSectionState();
}

class _CuratedListsSectionState extends State<CuratedListsSection> {
  String? _language;
  Catalog? _catalog;
  CuratedListsSnapshot? _snapshot;
  int _ticket = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GuideScope.of(context);
    final catalog = scope.catalog.data;
    if (catalog == null) return;
    final language = scope.language;
    if (language == _language && identical(catalog, _catalog)) return;
    _language = language;
    _catalog = catalog;
    _load(language);
  }

  Future<void> _load(String language) async {
    final ticket = ++_ticket;
    final snapshot = await widget.loadLists();
    if (!mounted || ticket != _ticket || language != _language) return;
    setState(() => _snapshot = snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final snapshot = _snapshot;
    final language = _language;
    if (catalog == null || language == null) return const SizedBox.shrink();
    final copy = GuideScope.of(context).copy;
    if (snapshot == null) return const SizedBox.shrink();
    if (snapshot.failed) {
      return _Failed(
        copy: copy,
        book: widget.book,
        onRetry: () => _load(language),
      );
    }
    final lists = [
      for (final doc in selectCuratedLists(snapshot.documents, language))
        presentCuratedList(doc, catalog, language),
    ]..sort(compareCuratedListViews);
    if (lists.isEmpty) return const SizedBox.shrink();
    return _Cards(
      copy: copy,
      lists: lists,
      book: widget.book,
      onOpen: (list) {
        final back = widget.book ? copy.book : copy.find;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: 'curated-list', arguments: list.id),
            builder: (_) => CuratedListPage(list: list, backLabel: back),
          ),
        );
      },
    );
  }
}

class _Failed extends StatelessWidget {
  final Copy copy;
  final bool book;
  final VoidCallback onRetry;

  const _Failed({
    required this.copy,
    required this.book,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final message = Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.sk ? 'Zoznamy sa nepodarilo načítať.' : "Couldn't load lists.",
            style: TextStyle(
              fontFamily: GuideType.sans,
              fontSize: 14,
              height: 1.3,
              color: colors.ink2,
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(copy.retry)),
        ],
      ),
    );
    if (book) return message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: copy.lists),
        message,
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  final Copy copy;
  final List<CuratedListView> lists;
  final bool book;
  final ValueChanged<CuratedListView> onOpen;

  const _Cards({
    required this.copy,
    required this.lists,
    required this.book,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (book) {
      return Column(
        children: [
          for (final list in lists)
            _BookCard(
              list: list,
              subtitle: _subtitle(copy, list),
              onTap: () => onOpen(list),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: copy.lists),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: lists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final list = lists[index];
              return _FindCard(
                list: list,
                subtitle: _subtitle(copy, list),
                onTap: () => onOpen(list),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _subtitle(Copy copy, CuratedListView list) {
  final parameter = list.parameter?.trim();
  if (parameter != null && parameter.isNotEmpty) return parameter;
  return copy.count(list.entries.length);
}

class _FindCard extends StatelessWidget {
  final CuratedListView list;
  final String subtitle;
  final VoidCallback onTap;

  const _FindCard({
    required this.list,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return SizedBox(
      width: 150,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('curated-card-${list.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 150,
                  height: 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (list.coverPhotoUrl.isEmpty)
                        ColoredBox(color: colors.paper2)
                      else
                        GuidePhoto(url: list.coverPhotoUrl, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0x99000000)],
                            stops: [0.45, 1],
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: 9,
                        end: 9,
                        bottom: 7,
                        child: Text(
                          list.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: GuideType.display,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            height: 1.1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  fontSize: 12,
                  height: 1.25,
                  color: colors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final CuratedListView list;
  final String subtitle;
  final VoidCallback onTap;

  const _BookCard({
    required this.list,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
      child: Material(
        color: colors.cream,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.rule),
        ),
        child: InkWell(
          key: Key('curated-card-${list.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (list.coverPhotoUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: GuidePhoto(url: list.coverPhotoUrl, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.title,
                      style: TextStyle(
                        fontFamily: GuideType.display,
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                        height: 1.15,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: GuideType.sans,
                        fontSize: 13,
                        height: 1.2,
                        color: colors.ink2,
                      ),
                    ),
                    if (list.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        list.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GuideType.sans,
                          fontSize: 14,
                          height: 1.35,
                          color: colors.ink2,
                        ),
                      ),
                    ],
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
