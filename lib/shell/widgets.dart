import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

class GuidePhoto extends StatelessWidget {
  final String url;
  final String? label;
  final BoxFit fit;
  final Color? background;

  const GuidePhoto({
    super.key,
    required this.url,
    this.label,
    this.fit = BoxFit.contain,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return ColoredBox(
      color: background ?? colors.plateWell,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url.isEmpty)
            const SizedBox.shrink()
          else
            CachedNetworkImage(
              imageUrl: url,
              fit: fit,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) =>
                  Icon(Icons.hide_image_outlined, color: colors.ink2),
            ),
          if (label != null)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.cream.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      label!,
                      style: GuideType.muted(colors, size: 12),
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

class SpeciesTile extends StatelessWidget {
  final String title;
  final bool titleLatin;
  final String latin;
  final String third;
  final bool thirdSpoken;
  final String imageUrl;
  final VoidCallback onTap;

  const SpeciesTile({
    super.key,
    required this.title,
    required this.titleLatin,
    required this.latin,
    required this.third,
    required this.thirdSpoken,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final nameStyle = titleLatin
        ? GuideType.latin(colors, size: 20)
        : GuideType.spoken(colors, size: 20);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 96,
                child: GuidePhoto(url: imageUrl),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: nameStyle),
                  if (!titleLatin)
                    Text(latin, style: GuideType.latin(colors, size: 15)),
                  if (third.isNotEmpty)
                    Text(
                      third,
                      style: GuideType.muted(colors).copyWith(
                        fontStyle: thirdSpoken
                            ? FontStyle.normal
                            : FontStyle.italic,
                        fontFamily: thirdSpoken
                            ? GuideType.sans
                            : GuideType.display,
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

class SpeciesRow extends StatelessWidget {
  final Catalog catalog;
  final Species species;
  final VoidCallback onTap;

  const SpeciesRow({
    super.key,
    required this.catalog,
    required this.species,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = catalog.heading(species);
    final family = species.family.isEmpty
        ? ''
        : catalog.taxonTitle(species.family);
    final familySpoken = family.isNotEmpty && family != species.family;
    return SpeciesTile(
      title: title,
      titleLatin: title == species.name,
      latin: species.name,
      third: family,
      thirdSpoken: familySpoken,
      imageUrl: cardPlate(species.illustrationUrl),
      onTap: onTap,
    );
  }
}

class CatalogMessage extends StatelessWidget {
  final Copy copy;
  final Object? error;
  final VoidCallback onRetry;

  const CatalogMessage({
    super.key,
    required this.copy,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final denied = catalogDenied(error ?? '');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            denied ? copy.catalogClosed : copy.catalogError,
            style: GuideType.body(colors),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: Text(copy.retry)),
        ],
      ),
    );
  }
}

class KeyChoice extends StatelessWidget {
  final String label;
  final String example;
  final int count;
  final bool selected;
  final bool enabled;
  final Widget? mark;
  final VoidCallback? onTap;

  const KeyChoice({
    super.key,
    required this.label,
    required this.example,
    required this.count,
    required this.selected,
    required this.enabled,
    this.mark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final fill = selected ? colors.moss : colors.cream;
    final ink = selected ? colors.onMoss : colors.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? colors.moss : colors.rule),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: enabled ? 1 : 0.38,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (mark != null) ...[mark!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: GuideType.sans,
                            fontSize: 17,
                            color: ink,
                          ),
                        ),
                        if (example.isNotEmpty)
                          Text(
                            example,
                            style: TextStyle(
                              fontFamily: GuideType.sans,
                              fontSize: 13,
                              color: selected ? colors.onMoss : colors.ink2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: GuideType.sans,
                      fontSize: 16,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
