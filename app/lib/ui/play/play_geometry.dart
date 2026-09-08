import 'dart:math' as math;
import 'dart:ui';

import '../../core/board.dart';

/// The whole screen laid out from its width, so 320, 360 and 411 px frames all
/// show 64 cells with the tray above the fold. Every number is the `styles.md`
/// ladder at 360 CSS px multiplied by [s].
class PlayGeometry {
  PlayGeometry._({
    required this.size,
    required this.s,
    required this.pad,
    required this.cell,
    required this.gap,
    required this.cellRadius,
    required this.well,
    required this.wellRadius,
    required this.gridOrigin,
    required this.pauseButton,
    required this.hudTop,
    required this.scoreTop,
    required this.ruleY,
    required this.gutter,
    required this.band,
    required this.tray,
  });

  factory PlayGeometry.of(Size size, {double safeTop = 0, double safeBottom = 0}) {
    final s = size.width / 360.0;
    final pad = 10.0 * s;
    final wellPad = 7.0 * s;
    final gap = 4.0 * s;
    final wellWidth = size.width - 2 * pad;
    final cell = (wellWidth - 2 * wellPad - 7 * gap) / 8;
    final gridSide = 8 * cell + 7 * gap;
    final wellHeight = gridSide + 2 * wellPad;

    const labelLine = 13.2, scoreLine = 33.1, hudGap = 3.0, hudBottom = 12.0;
    final hudHeight = (labelLine + hudGap + scoreLine) * s;
    final gutterHeight = 22.0 * s;
    final bandHeight = 44.0 * s;
    final trayHeight = 106.0 * s;
    final bottomPad = 14.0 * s + safeBottom;

    final pauseSide = 44.0 * s;
    final pauseTop = safeTop + 6.0 * s;
    final pause = Rect.fromLTWH(
      size.width - pad - pauseSide,
      pauseTop,
      pauseSide,
      pauseSide,
    );

    final midHeight =
        hudHeight + hudBottom * s + 1 + gutterHeight + wellHeight;
    final availTop = pause.bottom + 8 * s;
    final availBottom = size.height - bottomPad - trayHeight - bandHeight;
    final hudTop = math.max(
      availTop,
      availTop + (availBottom - availTop - midHeight) / 2,
    );

    final ruleY = hudTop + hudHeight + hudBottom * s;
    final gutter = Rect.fromLTWH(pad, ruleY + 1, wellWidth, gutterHeight);
    final well = Rect.fromLTWH(pad, gutter.bottom, wellWidth, wellHeight);
    final band = Rect.fromLTWH(pad, well.bottom, wellWidth, bandHeight);
    final tray = Rect.fromLTWH(pad, band.bottom, wellWidth, trayHeight);

    return PlayGeometry._(
      size: size,
      s: s,
      pad: pad,
      cell: cell,
      gap: gap,
      cellRadius: 5.0 * s,
      well: well,
      wellRadius: Radius.circular(16.0 * s),
      gridOrigin: Offset(well.left + wellPad, well.top + wellPad),
      pauseButton: pause,
      hudTop: hudTop,
      scoreTop: hudTop + (labelLine + hudGap) * s,
      ruleY: ruleY,
      gutter: gutter,
      band: band,
      tray: tray,
    );
  }

  final Size size;

  /// Width scale against the 360 CSS px reference.
  final double s;
  final double pad;
  final double cell;
  final double gap;
  final double cellRadius;
  final Rect well;
  final Radius wellRadius;
  final Offset gridOrigin;
  final Rect pauseButton;
  final double hudTop;
  final double scoreTop;
  final double ruleY;
  final Rect gutter;
  final Rect band;
  final Rect tray;

  double get pitch => cell + gap;

  /// Tray pieces are drawn at 60% of a grid cell (`styles.md`).
  double get trayCell => cell * 0.60;
  double get trayGap => 3.0 * s;
  double get trayCellRadius => 4.0 * s;

  double get gridSide => 8 * cell + 7 * gap;

  Rect cellRect(int row, int col) => Rect.fromLTWH(
        gridOrigin.dx + col * pitch,
        gridOrigin.dy + row * pitch,
        cell,
        cell,
      );

  Offset cellCentre(int row, int col) => Offset(
        gridOrigin.dx + col * pitch + cell / 2,
        gridOrigin.dy + row * pitch + cell / 2,
      );

  Rect traySlot(int slot) => Rect.fromLTWH(
        tray.left + slot * tray.width / 3,
        tray.top,
        tray.width / 3,
        tray.height,
      );

  int? traySlotAt(Offset p) {
    if (!tray.inflate(4 * s).contains(p)) return null;
    final i = ((p.dx - tray.left) / (tray.width / 3)).floor();
    return i < 0 || i > 2 ? null : i;
  }

  /// The anchor the piece would take: the grid cell under the piece's top-left
  /// cell after rounding (design 9.2), clamped so an edge drag still lands.
  (int, int) anchorFor(Offset topLeftCellCentre, int pieceHeight, int pieceWidth) {
    final col = ((topLeftCellCentre.dx - gridOrigin.dx - cell / 2) / pitch)
        .round()
        .clamp(0, Board.size - pieceWidth);
    final row = ((topLeftCellCentre.dy - gridOrigin.dy - cell / 2) / pitch)
        .round()
        .clamp(0, Board.size - pieceHeight);
    return (row, col);
  }

  /// A drag only aims at the board while the piece's leading cell is near it.
  bool nearBoard(Offset topLeftCellCentre) =>
      well.inflate(cell).contains(topLeftCellCentre);
}
