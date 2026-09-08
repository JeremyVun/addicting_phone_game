import 'package:flutter/material.dart';

import '../../core/board.dart';
import '../../core/piece.dart';
import '../play/play_host.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';
import '../widgets/format.dart';

/// Stand-in for the Flame play screen: tap a tray slot, then tap a cell.
/// Integration replaces this route wholesale (docs/contracts/app-shell.md).
class PlayRoute extends StatefulWidget {
  const PlayRoute({super.key, required this.host});

  final PlayHost host;

  @override
  State<PlayRoute> createState() => _PlayRouteState();
}

class _PlayRouteState extends State<PlayRoute> {
  int? _selectedSlot;

  PlayHost get host => widget.host;

  void _tapCell(int row, int col) {
    final slot = _selectedSlot;
    if (slot == null) return;
    final piece = host.state.set[slot];
    if (piece == null || !host.state.board.canPlace(piece, row, col)) return;
    final result = host.place(slot, row, col);
    setState(() => _selectedSlot = null);
    if (result.gameOver) {
      Future<void>.delayed(const Duration(milliseconds: 500), host.onGameOver);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: host,
    builder: (context, _) {
      final palette = host.palette;
      final state = host.state;
      return Scaffold(
        backgroundColor: palette.ground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Text(
                  S.standInPlayBanner,
                  style: PlayType.hint(1, palette.faint),
                ),
                _Hud(host: host),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final side = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final inner = (side - 14 - 4 * 7) / 8;
                        final row =
                            ((details.localPosition.dy - 7) / (inner + 4))
                                .floor();
                        final col =
                            ((details.localPosition.dx - 7) / (inner + 4))
                                .floor();
                        if (row < 0 || row > 7 || col < 0 || col > 7) return;
                        _tapCell(row, col);
                      },
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: CustomPaint(
                          painter: _BoardPainter(state.board, palette),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: host.requestReroll,
                      child: Text(
                        '${S.playReroll} · ${host.rewardedRerollAvailable ? '▶' : host.rerollCoinPrice}',
                        style: PlayType.pill(1, palette.accent),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 106,
                  child: Row(
                    children: [
                      for (var slot = 0; slot < 3; slot++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: state.set[slot] == null
                                ? null
                                : () => setState(() => _selectedSlot = slot),
                            child: _TraySlot(
                              piece: state.set[slot],
                              palette: palette,
                              selected: _selectedSlot == slot,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Hud extends StatelessWidget {
  const _Hud({required this.host});

  final PlayHost host;

  @override
  Widget build(BuildContext context) {
    final palette = host.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.playScore.toUpperCase(), style: PlayType.label(1, palette.muted)),
            const SizedBox(height: 4),
            Text(
              formatCount(host.state.score),
              style: PlayType.score(1, palette.ink),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(S.playBest.toUpperCase(), style: PlayType.label(1, palette.faint)),
            const SizedBox(height: 4),
            Text(
              formatCount(host.bestScore),
              style: PlayType.best(1, palette.muted),
            ),
          ],
        ),
        IconButton(
          onPressed: host.requestPause,
          icon: Icon(Icons.pause_rounded, color: palette.muted),
        ),
      ],
    );
  }
}

class _TraySlot extends StatelessWidget {
  const _TraySlot({
    required this.piece,
    required this.palette,
    required this.selected,
  });

  final Piece? piece;
  final ThemePalette palette;
  final bool selected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: selected ? palette.accent : const Color(0x00000000),
      ),
    ),
    child: SizedBox.expand(
      child: CustomPaint(painter: _PiecePainter(piece, palette)),
    ),
  );
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter(this.board, this.palette);

  final Board board;
  final ThemePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    const pad = 7.0;
    final well = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    canvas.drawRRect(well, Paint()..color = palette.well);
    final cell = (size.width - pad * 2 - gap * 7) / 8;
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final colourIndex = board.cellAt(row, col);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              pad + col * (cell + gap),
              pad + row * (cell + gap),
              cell,
              cell,
            ),
            const Radius.circular(5),
          ),
          Paint()
            ..color = colourIndex == null
                ? palette.empty
                : palette.block(colourIndex),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.board != board || old.palette != palette;
}

class _PiecePainter extends CustomPainter {
  const _PiecePainter(this.piece, this.palette);

  final Piece? piece;
  final ThemePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = piece;
    if (shape == null) {
      canvas.drawCircle(
        size.center(Offset.zero),
        4,
        Paint()..color = palette.faint,
      );
      return;
    }
    const gap = 3.0;
    final cell =
        (size.shortestSide * 0.72 - gap * 4) / (shape.width > shape.height
            ? shape.width
            : shape.height);
    final originX =
        (size.width - (shape.width * (cell + gap) - gap)) / 2;
    final originY =
        (size.height - (shape.height * (cell + gap) - gap)) / 2;
    final paint = Paint()..color = palette.block(shape.colourIndex);
    for (final offset in shape.cells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            originX + offset.col * (cell + gap),
            originY + offset.row * (cell + gap),
            cell,
            cell,
          ),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.piece != piece || old.palette != palette;
}
