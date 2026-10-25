import 'dart:io';

import 'package:whats_that_mushroom/data/notebook.dart';

/// The control at the end of a confirmed row.
enum SeenChip { share, review, shared, rejected, outside }

/// Share needs a confirmed catalog species and a photo on this phone.
/// A name outside the book, or one already sent, shows its state instead.
SeenChip? seenChip(
  FindRecord find, {
  required bool inBook,
  required bool catalogKnown,
}) {
  if (!find.confirmed) return null;
  switch (find.share) {
    case FindShare.review:
      return SeenChip.review;
    case FindShare.shared:
      return SeenChip.shared;
    case FindShare.rejected:
      return SeenChip.rejected;
    case FindShare.none:
      if (!catalogKnown) return null;
      if (!inBook) return SeenChip.outside;
      if (!seenPhotoOnPhone(find.photoPath)) return null;
      return SeenChip.share;
  }
}

/// The file is on this phone. A stored path from another install is not.
bool seenPhotoOnPhone(String? path) {
  if (path == null || path.isEmpty) return false;
  return File(path).existsSync();
}

/// A confirmed find already published as a Sighting.
bool seenIsShared(FindRecord find) {
  return find.confirmed && find.share == FindShare.shared;
}

int seenSharedCount(Iterable<FindRecord> finds) {
  var count = 0;
  for (final find in finds) {
    if (seenIsShared(find)) count++;
  }
  return count;
}

/// Drops confirmed public finds. To confirm, in review, and not accepted stay.
Iterable<FindRecord> seenHidingShared(Iterable<FindRecord> finds) {
  return finds.where((find) => !seenIsShared(find));
}
