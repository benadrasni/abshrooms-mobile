import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/text.dart';

/// A plate, its card size, and a few photos. The plants guide uses the same
/// per-species estimate and rounds it the same way.
const offlineMbPerSpecies = 0.70;

/// Storage path for a catalog URL. Other hosts and parent segments are refused.
String? offlineRelative(String url) {
  var value = url.trim();
  if (value.isEmpty) return null;
  if (value.startsWith(storageRoot)) {
    value = value.substring(storageRoot.length);
  } else if (value.startsWith('http://') || value.startsWith('https://')) {
    return null;
  }
  final query = value.indexOf('?');
  if (query >= 0) value = value.substring(0, query);
  final fragment = value.indexOf('#');
  if (fragment >= 0) value = value.substring(0, fragment);
  while (value.startsWith('/')) {
    value = value.substring(1);
  }
  if (value.isEmpty || value.contains('..') || value.contains('\\')) {
    return null;
  }
  return value;
}

/// Plate at both sizes the app opens, plus the species photos. Sorted and unique.
List<String> speciesMedia(Species species) {
  final paths = <String>{};
  void add(String raw) {
    final relative = offlineRelative(raw);
    if (relative != null) paths.add(relative);
  }

  add(species.illustrationUrl);
  if (species.illustrationUrl.contains('@1600.webp')) {
    add(species.illustrationUrl.replaceAll('@1600.webp', '@400.webp'));
  }
  for (final photo in species.photoUrls) {
    add(photo);
  }
  final list = paths.toList()..sort();
  return list;
}

String familyMedia(String family) => 'families/$family.webp';

/// Family icons are optional: a missing icon does not fail the book.
bool offlineOptional(String path) => path.startsWith('families/');

/// Every picture the book shows, including one icon per family.
List<String> bookMedia(Iterable<Species> species) {
  final paths = <String>{};
  for (final item in species) {
    paths.addAll(speciesMedia(item));
    if (item.family.isNotEmpty) paths.add(familyMedia(item.family));
  }
  final list = paths.toList()..sort();
  return list;
}

/// Species that still have a picture missing from this phone.
int offlineMissingSpecies(
  Iterable<Species> species, {
  required Set<String> saved,
  required Set<String> skipped,
}) {
  var count = 0;
  for (final item in species) {
    final paths = speciesMedia(item);
    if (item.family.isNotEmpty) paths.add(familyMedia(item.family));
    final missing = paths.any(
      (path) => !saved.contains(path) && !skipped.contains(path),
    );
    if (missing) count++;
  }
  return count;
}

/// Rounded picture size. At 1,000 MB and above the text is gigabytes.
/// Counts under 10 MB keep one decimal so a short book does not read as zero.
class OfflineAmount {
  final bool gigabytes;
  final String amount;

  const OfflineAmount._(this.gigabytes, this.amount);

  static OfflineAmount ofSpecies(int count) {
    if (count <= 0) return const OfflineAmount._(false, '0');
    final mb = count * offlineMbPerSpecies;
    if (mb >= 1000) {
      final tenths = (mb / 100).round();
      return OfflineAmount._(true, (tenths / 10).toStringAsFixed(1));
    }
    if (mb >= 10) {
      final rounded = (mb / 10).round() * 10;
      return OfflineAmount._(false, '$rounded');
    }
    final tenths = (mb * 10).round();
    final shown = tenths <= 0 ? 1 : tenths;
    return OfflineAmount._(false, (shown / 10).toStringAsFixed(1));
  }

  static OfflineAmount ofBytes(int bytes) {
    if (bytes <= 0) return const OfflineAmount._(false, '0');
    final mb = bytes / 1000000;
    if (mb >= 1000) {
      final tenths = (mb / 100).round();
      return OfflineAmount._(true, (tenths / 10).toStringAsFixed(1));
    }
    if (mb >= 1) return OfflineAmount._(false, '${mb.round()}');
    final tenths = (mb * 10).round();
    final shown = tenths <= 0 ? 1 : tenths;
    return OfflineAmount._(false, (shown / 10).toStringAsFixed(1));
  }

  /// Megabytes for a download bar. A gigabyte label stays in megabytes here.
  int get barMb {
    final value = double.parse(amount);
    if (gigabytes) return (value * 1000).round();
    if (value <= 0) return 0;
    return value < 1 ? 1 : value.round();
  }
}

int offlineUpdateBytes(int species) =>
    (species * offlineMbPerSpecies * 1000000).round();

String offlineAbout(Copy copy, OfflineAmount amount) {
  return amount.gigabytes
      ? copy.offlineAboutGb(amount.amount)
      : copy.offlineAboutMb(amount.amount);
}

/// What this phone still has to fetch for the whole book.
class OfflineView {
  final int species;
  final bool canDownload;
  final bool stored;
  final List<String> pending;
  final int alreadyDone;
  final int totalFiles;
  final int missingSpecies;

  /// The published words are newer than the copy on this phone.
  final bool catalogStale;

  /// Size of those words, from the manifest.
  final int catalogBytes;

  const OfflineView({
    required this.species,
    required this.canDownload,
    required this.stored,
    required this.pending,
    required this.alreadyDone,
    required this.totalFiles,
    required this.missingSpecies,
    this.catalogStale = false,
    this.catalogBytes = 0,
  });

  bool get hasUpdate => stored && (pending.isNotEmpty || catalogStale);

  OfflineView copyWith({bool? canDownload, bool? stored}) {
    return OfflineView(
      species: species,
      canDownload: canDownload ?? this.canDownload,
      stored: stored ?? this.stored,
      pending: pending,
      alreadyDone: alreadyDone,
      totalFiles: totalFiles,
      missingSpecies: missingSpecies,
      catalogStale: catalogStale,
      catalogBytes: catalogBytes,
    );
  }
}

/// Picture estimate plus the text snapshot, when that snapshot is newer.
int offlinePackUpdateBytes(OfflineView view) {
  final pictures = offlineUpdateBytes(view.missingSpecies);
  final words = view.catalogStale ? view.catalogBytes : 0;
  final total = pictures + words;
  if (total > 0) return total;
  return view.catalogStale ? 1 : 0;
}

OfflineView offlineViewOf({
  required List<Species> species,
  required bool canDownload,
  required bool stored,
  required Set<String> saved,
  required Set<String> skipped,
  bool catalogStale = false,
  int catalogBytes = 0,
}) {
  final files = bookMedia(species);
  final pending = [
    for (final path in files)
      if (!saved.contains(path) && !skipped.contains(path)) path,
  ];
  return OfflineView(
    species: species.length,
    canDownload: canDownload,
    stored: stored,
    pending: pending,
    alreadyDone: files.length - pending.length,
    totalFiles: files.length,
    missingSpecies: offlineMissingSpecies(
      species,
      saved: saved,
      skipped: skipped,
    ),
    catalogStale: catalogStale,
    catalogBytes: catalogBytes,
  );
}

/// Person row subtitle. A missing catalog omits the size.
String offlineMenuLine(
  Copy copy, {
  required bool canDownload,
  required bool stored,
  required int? species,
  required int updateSpecies,
  int updateBytes = 0,
}) {
  final size = species == null
      ? null
      : offlineAbout(copy, OfflineAmount.ofSpecies(species));
  final String line;
  if (stored) {
    line = size == null ? copy.offlineOnPhone : copy.offlineMenuStored(size);
  } else if (!canDownload) {
    line = size == null ? copy.offlineWithGuide : copy.offlineMenuUpsell(size);
  } else {
    line = size == null ? copy.offlineWholeBook : copy.offlineMenuBook(size);
  }
  final pictures = updateSpecies > 0 ? offlineUpdateBytes(updateSpecies) : 0;
  final total = pictures + (updateBytes > 0 ? updateBytes : 0);
  if (!stored || total <= 0) return line;
  final update = offlineAbout(copy, OfflineAmount.ofBytes(total));
  return copy.offlineMenuUpdate(line, update);
}
