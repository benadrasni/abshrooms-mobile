import 'package:flutter/material.dart';

/// Underside marks from the website key, drawn in a 72×72 box.
class KeyGlyph extends StatelessWidget {
  final String id;
  final Color color;
  final double size;

  const KeyGlyph({
    super.key,
    required this.id,
    required this.color,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(id, color),
    );
  }
}

class _Dot {
  final double x;
  final double y;
  final double r;

  const _Dot(this.x, this.y, this.r);
}

class _Glyph {
  final List<String> strokes;
  final List<_Dot> rings;
  final List<_Dot> dots;

  const _Glyph({
    this.strokes = const [],
    this.rings = const [],
    this.dots = const [],
  });
}

const _glyphs = <String, _Glyph>{
  'gills': _Glyph(
    strokes: [
      'M14 30c2-14 42-14 44 0',
      'M36 30v28',
      'M22 31v11',
      'M29 30v16',
      'M36 30v16',
      'M43 30v16',
      'M50 31v11',
    ],
  ),
  'tubes': _Glyph(
    strokes: ['M14 30c2-14 42-14 44 0', 'M36 44v14'],
    dots: [
      _Dot(24, 38, 1.7),
      _Dot(32, 38, 1.7),
      _Dot(40, 38, 1.7),
      _Dot(48, 38, 1.7),
      _Dot(28, 45, 1.7),
      _Dot(36, 45, 1.7),
      _Dot(44, 45, 1.7),
    ],
  ),
  'ridges': _Glyph(
    strokes: [
      'M16 26c6 8 10 22 20 32 10-10 14-24 20-32',
      'M28 34c4 8 6 16 8 24',
      'M44 34c-4 8-6 16-8 24',
      'M36 28v28',
    ],
  ),
  'teeth': _Glyph(
    strokes: [
      'M14 28c2-12 42-12 44 0',
      'M22 30v12',
      'M29 30v16',
      'M36 30v18',
      'M43 30v16',
      'M50 30v12',
    ],
  ),
  'pits': _Glyph(
    strokes: [
      'M24 16h24l8 14-8 14H24l-8-14z',
      'M24 16l8 14-8 14',
      'M40 16l-8 14 8 14',
      'M16 30h40',
      'M36 44v14',
    ],
  ),
  'smooth': _Glyph(
    strokes: [
      'M22 40c-6-14 4-26 14-22 6-8 18-6 20 6 8 2 10 16 2 22-2 8-12 12-20 8-10 4-18 0-16-14z',
    ],
  ),
  'gleba': _Glyph(
    strokes: ['M28 44c2 10 14 10 16 0'],
    rings: [_Dot(36, 30, 16)],
    dots: [_Dot(30, 28, 1.4), _Dot(38, 24, 1.4), _Dot(42, 32, 1.4)],
  ),
};

/// Bounds of a glyph in the 72×72 view box. Empty when [id] is unknown.
Rect glyphBounds(String id) {
  final glyph = _glyphs[id];
  if (glyph == null) return Rect.zero;
  Rect? bounds;
  void take(Rect rect) {
    if (rect.isEmpty) return;
    bounds = bounds == null ? rect : bounds!.expandToInclude(rect);
  }

  for (final stroke in glyph.strokes) {
    take(parseSvgPath(stroke).getBounds());
  }
  for (final ring in glyph.rings) {
    take(Rect.fromCircle(center: Offset(ring.x, ring.y), radius: ring.r));
  }
  for (final dot in glyph.dots) {
    take(Rect.fromCircle(center: Offset(dot.x, dot.y), radius: dot.r));
  }
  return bounds ?? Rect.zero;
}

Path parseSvgPath(String source) {
  final path = Path();
  var index = 0;
  String? command;
  var x = 0.0;
  var y = 0.0;
  var startX = 0.0;
  var startY = 0.0;

  void skip() {
    while (index < source.length) {
      final char = source[index];
      if (char != ' ' && char != ',') break;
      index += 1;
    }
  }

  double? number() {
    skip();
    if (index >= source.length) return null;
    final start = index;
    if (source[index] == '-' || source[index] == '+') index += 1;
    var digits = false;
    while (index < source.length) {
      final code = source.codeUnitAt(index);
      if (code < 48 || code > 57) break;
      digits = true;
      index += 1;
    }
    if (index < source.length && source[index] == '.') {
      digits = true;
      index += 1;
      while (index < source.length) {
        final code = source.codeUnitAt(index);
        if (code < 48 || code > 57) break;
        index += 1;
      }
    }
    if (!digits) {
      index = start;
      return null;
    }
    return double.parse(source.substring(start, index));
  }

  while (index < source.length) {
    skip();
    if (index >= source.length) break;
    final char = source[index];
    if (_commands.contains(char)) {
      command = char;
      index += 1;
    }
    if (command == null) break;
    final before = index;
    switch (command) {
      case 'M':
      case 'm':
        final nx = number();
        final ny = number();
        if (nx == null || ny == null) return path;
        if (command == 'm') {
          x += nx;
          y += ny;
        } else {
          x = nx;
          y = ny;
        }
        path.moveTo(x, y);
        startX = x;
        startY = y;
        command = command == 'm' ? 'l' : 'L';
        break;
      case 'L':
      case 'l':
        final nx = number();
        final ny = number();
        if (nx == null || ny == null) {
          if (index == before) command = null;
          break;
        }
        if (command == 'l') {
          x += nx;
          y += ny;
        } else {
          x = nx;
          y = ny;
        }
        path.lineTo(x, y);
        break;
      case 'H':
      case 'h':
        final nx = number();
        if (nx == null) {
          command = null;
          break;
        }
        x = command == 'h' ? x + nx : nx;
        path.lineTo(x, y);
        break;
      case 'V':
      case 'v':
        final ny = number();
        if (ny == null) {
          command = null;
          break;
        }
        y = command == 'v' ? y + ny : ny;
        path.lineTo(x, y);
        break;
      case 'C':
      case 'c':
        final x1 = number();
        final y1 = number();
        final x2 = number();
        final y2 = number();
        final nx = number();
        final ny = number();
        if (x1 == null ||
            y1 == null ||
            x2 == null ||
            y2 == null ||
            nx == null ||
            ny == null) {
          command = null;
          break;
        }
        if (command == 'c') {
          path.relativeCubicTo(x1, y1, x2, y2, nx, ny);
          x += nx;
          y += ny;
        } else {
          path.cubicTo(x1, y1, x2, y2, nx, ny);
          x = nx;
          y = ny;
        }
        break;
      case 'Z':
      case 'z':
        path.close();
        x = startX;
        y = startY;
        command = null;
        break;
      default:
        command = null;
        break;
    }
    if (command != null && index == before) break;
  }
  return path;
}

const _commands = 'MmLlHhVvCcZz';

class _GlyphPainter extends CustomPainter {
  final String id;
  final Color color;

  const _GlyphPainter(this.id, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final glyph = _glyphs[id];
    if (glyph == null || size.width == 0) return;
    canvas.save();
    canvas.scale(size.width / 72);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    for (final source in glyph.strokes) {
      canvas.drawPath(parseSvgPath(source), stroke);
    }
    for (final ring in glyph.rings) {
      canvas.drawCircle(Offset(ring.x, ring.y), ring.r, stroke);
    }
    for (final dot in glyph.dots) {
      canvas.drawCircle(Offset(dot.x, dot.y), dot.r, fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) {
    return oldDelegate.id != id || oldDelegate.color != color;
  }
}
