import 'package:flutter/painting.dart';

/// A collage template. Each cell is a fractional rect (0..1) within the square
/// canvas, so the same layout drives both the on-screen preview and the
/// full-resolution export.
class CollageLayout {
  const CollageLayout(this.id, this.name, this.cells);

  final String id;
  final String name;
  final List<Rect> cells;

  int get count => cells.length;

  static const catalog = <CollageLayout>[
    CollageLayout('h2', 'Side by side', [
      Rect.fromLTRB(0, 0, 0.5, 1),
      Rect.fromLTRB(0.5, 0, 1, 1),
    ]),
    CollageLayout('v2', 'Stacked', [
      Rect.fromLTRB(0, 0, 1, 0.5),
      Rect.fromLTRB(0, 0.5, 1, 1),
    ]),
    CollageLayout('grid4', 'Grid', [
      Rect.fromLTRB(0, 0, 0.5, 0.5),
      Rect.fromLTRB(0.5, 0, 1, 0.5),
      Rect.fromLTRB(0, 0.5, 0.5, 1),
      Rect.fromLTRB(0.5, 0.5, 1, 1),
    ]),
    CollageLayout('big2', 'Big + 2', [
      Rect.fromLTRB(0, 0, 0.62, 1),
      Rect.fromLTRB(0.62, 0, 1, 0.5),
      Rect.fromLTRB(0.62, 0.5, 1, 1),
    ]),
    CollageLayout('h3', 'Triptych', [
      Rect.fromLTRB(0, 0, 1 / 3, 1),
      Rect.fromLTRB(1 / 3, 0, 2 / 3, 1),
      Rect.fromLTRB(2 / 3, 0, 1, 1),
    ]),
  ];
}
