import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/shell/widgets.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

class TaxonPage extends StatelessWidget {
  final String kind;
  final String name;

  const TaxonPage({super.key, required this.kind, required this.name});

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
    final rows = catalog.speciesIn(kind, name);
    final title = catalog.taxonTitle(name);
    final lede = switch (kind) {
      'family' => copy.familyLede,
      'genus' => copy.genusLede,
      _ => '',
    };
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        title: Text(
          title,
          style: title == name
              ? GuideType.latin(colors, size: 22)
              : GuideType.spoken(colors, size: 22),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (lede.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(lede, style: GuideType.muted(colors)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(copy.count(rows.length), style: GuideType.body(colors)),
          ),
          if (title != name)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(name, style: GuideType.latin(colors, size: 16)),
            ),
          for (final species in rows)
            SpeciesRow(
              catalog: catalog,
              species: species,
              onTap: () => openSpecies(
                context,
                species.name,
                source: GuideMushroomSource.list,
              ),
            ),
        ],
      ),
    );
  }
}
