import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/book/list_chrome.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/new_book.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

/// New in the book: the latest species, grouped by the day they were added.
class NewPage extends StatefulWidget {
  const NewPage({super.key});

  @override
  State<NewPage> createState() => _NewPageState();
}

class _NewPageState extends State<NewPage> {
  bool _plates = false;

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final catalog = scope.catalog.data;
    final days = catalog == null
        ? const <NewDay>[]
        : newInBook(catalog.species);
    final seen = {
      for (final find in scope.notebook.finds)
        if (find.latin != null) find.latin!,
    };
    var seenCount = 0;
    for (final day in days) {
      for (final species in day.species) {
        if (seen.contains(species.name)) seenCount += 1;
      }
    }
    final countLine = days.isEmpty ? '' : copy.newAdded(newBookCount(days));
    final meta = seenCount > 0
        ? '$countLine · ${copy.youHaveSeen(seenCount)}'
        : countLine;
    return ListPageChrome(
      backLabel: copy.find,
      eyebrow: copy.listsTitle.toUpperCase(),
      title: copy.newInBook,
      meta: meta,
      photosLabel: copy.photos,
      platesLabel: copy.plates,
      plates: _plates,
      showSwitch: days.isNotEmpty,
      onPhotos: () => setState(() => _plates = false),
      onPlates: () => setState(() => _plates = true),
      body: _body(catalog, days, seen),
    );
  }

  List<Widget> _body(Catalog? catalog, List<NewDay> days, Set<String> seen) {
    if (catalog == null || days.isEmpty) return const [];
    final rows = <Widget>[];
    final pending = <Species>[];
    void flush() {
      if (pending.isEmpty) return;
      rows.add(
        _gridRow([for (final species in pending) species], seen, catalog),
      );
      pending.clear();
    }

    for (final day in days) {
      if (day.species.isEmpty) continue;
      flush();
      rows.add(_DateHeader(day: day, first: rows.isEmpty));
      for (final species in day.species) {
        pending.add(species);
        if (pending.length == 2) flush();
      }
    }
    flush();
    return rows;
  }

  Widget _gridRow(List<Species> species, Set<String> seen, Catalog catalog) {
    final copy = GuideScope.of(context).copy;
    return speciesGridRow(
      columns: 2,
      cells: [
        for (final item in species)
          SpeciesCell(
            species: item,
            title: catalog.heading(item),
            titleIsLatin: catalog.heading(item) == item.name,
            plates: _plates,
            seen: seen.contains(item.name),
            seenLabel: copy.seenMark,
            onTap: () => openSpecies(context, item.name),
          ),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  final NewDay day;
  final bool first;

  const _DateHeader({required this.day, required this.first});

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = GuideScope.of(context).copy;
    final word = newDayWord(
      day.date,
      DateTime.now(),
      today: copy.today,
      yesterday: copy.yesterday,
    );
    final label =
        word ?? MaterialLocalizations.of(context).formatMediumDate(day.date);
    return Padding(
      padding: EdgeInsets.only(top: first ? 4 : 10, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: GuideType.sans,
          fontSize: 12,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
          color: colors.ink2,
        ),
      ),
    );
  }
}

/// A field photo when the book has one, otherwise the card plate.
String speciesPhoto(Species species) {
  if (species.photoUrls.isNotEmpty) return mediaUrl(species.photoUrls.first);
  return cardPlate(species.illustrationUrl);
}
