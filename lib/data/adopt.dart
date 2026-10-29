import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';

/// Rewrites Not in the book finds once [catalog] contains them.
///
/// Returns [finds] unchanged when every row already sits on its catalog
/// name. A published Sighting is not created.
List<FindRecord> adoptBookFinds(List<FindRecord> finds, Catalog catalog) {
  var changed = false;
  final next = <FindRecord>[];
  for (final find in finds) {
    final adopted = adoptBookFind(find, catalog);
    if (!identical(adopted, find)) changed = true;
    next.add(adopted);
  }
  if (!changed) return finds;
  return next;
}

/// One phone find. A name already in the book stays as stored.
FindRecord adoptBookFind(FindRecord find, Catalog catalog) {
  final latin = find.latin?.trim() ?? '';
  if (latin.isNotEmpty && catalog.byName(latin) != null) return find;
  final outside = find.outsideName?.trim() ?? '';
  final species = catalog.speciesFor(outside) ?? catalog.speciesFor(latin);
  if (species == null) return find;
  return find.copyWith(
    latin: species.name,
    dropOutside: true,
    dropSpoken: true,
  );
}

/// Writes the notebook when a newly loaded catalog contains an outside name.
Future<void> adoptOutsideFinds(Notebook notebook, Catalog? catalog) async {
  if (catalog == null) return;
  final next = adoptBookFinds(notebook.finds, catalog);
  if (identical(next, notebook.finds)) return;
  await notebook.replaceAll(next);
}
