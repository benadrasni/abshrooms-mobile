import 'package:whats_that_mushroom/data/adopt.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';

/// Reloads the open book from the server, then updates the notebook.
///
/// New species show up in New in the book. An outside name that now has
/// a page moves into Seen and Seen lately. [syncSightings] copies this
/// account's Sightings onto the phone. A failed catalog read keeps the
/// book already on screen and still syncs Sightings.
Future<void> refreshOpenGuide({
  required CatalogRepository catalog,
  required Notebook notebook,
  Future<void> Function(Notebook notebook)? syncSightings,
}) async {
  await catalog.refresh();
  await adoptOutsideFinds(notebook, catalog.data);
  final sync = syncSightings;
  if (sync != null) await sync(notebook);
}
