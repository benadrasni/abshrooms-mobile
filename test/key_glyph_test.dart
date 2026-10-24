import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/key_filter.dart';
import 'package:whats_that_mushroom/find/key_glyph.dart';

void main() {
  test('each underside glyph draws inside the 72 box', () {
    for (final id in underChoices) {
      final bounds = glyphBounds(id);
      expect(bounds.width, greaterThan(8), reason: id);
      expect(bounds.left, greaterThanOrEqualTo(0), reason: id);
      expect(bounds.top, greaterThanOrEqualTo(0), reason: id);
      expect(bounds.right, lessThanOrEqualTo(72), reason: id);
      expect(bounds.bottom, lessThanOrEqualTo(72), reason: id);
    }
  });
}
