import 'package:whats_that_mushroom/data/models.dart';

/// One slice of a Lookalikes paragraph.
///
/// [latin] is the catalog species to open. It is set when [Catalog.speciesFor]
/// finds that name and the page is not already that species. A rank tail such
/// as `var. alba` stays outside the binomial, so it is its own slice.
class LookalikePiece {
  const LookalikePiece(this.text, {this.latin});

  final String text;
  final String? latin;
}

final _binomial = RegExp(r'\b([A-Z][A-Za-z-]{2,}) ([a-z][a-z-]{2,})\b');

List<LookalikePiece> lookalikePieces(
  String text,
  Catalog catalog,
  String current,
) {
  final pieces = <LookalikePiece>[];
  var start = 0;
  for (final match in _binomial.allMatches(text)) {
    if (match.start > start) {
      pieces.add(LookalikePiece(text.substring(start, match.start)));
    }
    final mention = match.group(0)!;
    final target = catalog.speciesFor(mention);
    final latin = target == null || target.name == current ? null : target.name;
    pieces.add(LookalikePiece(mention, latin: latin));
    start = match.end;
  }
  if (start < text.length) pieces.add(LookalikePiece(text.substring(start)));
  if (pieces.isEmpty) pieces.add(const LookalikePiece(''));
  return pieces;
}
