import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/foundation.dart';

import '../../core/board.dart';
import '../../core/cell.dart';
import '../../core/game.dart';
import '../../core/game_state.dart';
import '../../core/piece.dart';
import '../../services/audio.dart';
import '../../services/haptics.dart';
import 'board_component.dart';
import 'held_piece_component.dart';
import 'play_geometry.dart';
import 'play_host.dart';
import 'score_popup_component.dart';
import 'tile_painter.dart';
import 'tray_component.dart';

/// The well, the tray, the drag layer and every animation of design 9.3.
/// Text lives in Flutter widgets above this; everything the finger touches
/// lives here.
class SettlePlayGame extends FlameGame with DragCallbacks {
  SettlePlayGame({
    required this.host,
    required this.audio,
    required this.haptics,
    required PlayGeometry geometry,
  })  : geom = geometry,
        painter = TilePainter(host.palette);

  static const scoreRollDuration = 0.3;
  static const gameOverHold = 0.5;
  static const gameOverDim = 0.25;

  final PlayHost host;
  final AudioService audio;
  final HapticsService haptics;

  PlayGeometry geom;
  TilePainter painter;

  late BoardComponent board;
  late TrayComponent tray;
  HeldPieceComponent? _held;
  int _heldSlot = -1;
  int? _pointer;
  int _hoverRow = -1;
  int _hoverCol = -1;

  /// The score the HUD shows; it rolls up to the real one over 300 ms.
  final displayScore = ValueNotifier<int>(0);

  /// 0 when no banner is due, else the combo count to typeset in the gutter.
  final combo = ValueNotifier<int>(0);

  /// 0 while playing, 1 once the game over dim has finished.
  final dim = ValueNotifier<double>(0);

  final _rng = math.Random();
  String _stateId = '';
  Board _lastBoard = Board.empty();
  double _scoreT = 0;
  int _scoreFrom = 0;
  int _scoreTo = 0;
  double _dimT = -1;
  bool _locked = false;

  /// The anchor the current drag is aiming at, or (-1, -1).
  @visibleForTesting
  (int, int) get hoverAnchor => (_hoverRow, _hoverCol);

  bool get isBusy =>
      board.isAnimating || tray.isAnimating || _held != null || _scoreT > 0;

  @override
  Color backgroundColor() => host.palette.ground;

  @override
  Future<void> onLoad() async {
    board = BoardComponent(geom: geom, painter: painter);
    tray = TrayComponent(geom: geom, painter: painter);
    await addAll([board, tray]);
    _hardReset();
  }

  void applyGeometry(PlayGeometry next) {
    if (next.size == geom.size) return;
    geom = next;
    _cancelHold();
    board.removeFromParent();
    tray.removeFromParent();
    board = BoardComponent(geom: geom, painter: painter);
    tray = TrayComponent(geom: geom, painter: painter);
    addAll([board, tray]);
    _hardReset();
  }

  // ---------------------------------------------------------------- host sync

  /// Called on every `PlayHost` notification: re-read `state` and animate the
  /// difference. A new `state.id` is a new game and is never animated, so a
  /// restart shows its board on the next frame.
  void syncFromHost() {
    if (painter.palette != host.palette) {
      painter = TilePainter(host.palette);
      board.painter = painter;
      tray.painter = painter;
      _held?.painter = painter;
    }
    final state = host.state;
    if (state.id != _stateId) {
      _hardReset();
      return;
    }
    final before = _lastBoard;
    final cleared = <Cell>[];
    final placed = <Cell>[];
    for (var r = 0; r < Board.size; r++) {
      for (var c = 0; c < Board.size; c++) {
        final was = before.cellAt(r, c);
        final now = state.board.cellAt(r, c);
        if (was != null && now == null) cleared.add(Cell(r, c));
        if (was == null && now != null) placed.add(Cell(r, c));
      }
    }
    board.syncColours(state.board);
    if (placed.isNotEmpty) board.animatePlace(placed);
    if (cleared.isNotEmpty) {
      board.animateClear(cleared, before, _centroid(cleared));
      _burst(cleared, before);
      audio.play(Sfx.clear1);
    }
    _syncTray(animateNew: true);
    _rollScoreTo(state.score);
    combo.value = state.comboCount >= 2 ? state.comboCount : 0;
    if (state.status == GameStatus.playing) {
      _locked = false;
      dim.value = 0;
      _dimT = -1;
    }
    _lastBoard = state.board;
  }

  void _hardReset() {
    final state = host.state;
    _cancelHold();
    board.reset(state.board);
    _syncTray();
    displayScore.value = state.score;
    _scoreT = 0;
    _scoreTo = state.score;
    combo.value = state.comboCount >= 2 ? state.comboCount : 0;
    dim.value = 0;
    _dimT = -1;
    _locked = state.status == GameStatus.over;
    _stateId = state.id;
    _lastBoard = state.board;
  }

  void _syncTray({bool animateNew = false}) {
    final state = host.state;
    final fits = [
      for (final p in state.set) p == null || state.board.anyPlacement(p),
    ];
    tray.setSlots(state.set, fits, animateNew: animateNew);
  }

  // -------------------------------------------------------------------- input

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_locked || _held != null || _pointer != null) return;
    final p = event.canvasPosition.toOffset();
    final slot = geom.traySlotAt(p);
    if (slot == null) return;
    final piece = host.state.set[slot];
    if (piece == null) return;
    _pointer = event.pointerId;
    _heldSlot = slot;
    tray.hide(slot);
    final held = HeldPieceComponent(
      geom: geom,
      painter: painter,
      piece: piece,
      from: geom.traySlot(slot).center,
    );
    _held = held;
    add(held);
    held.follow(p);
    _hoverRow = -1;
    _hoverCol = -1;
    _updateHover();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (event.pointerId != _pointer) return;
    // canvasEndPosition is globalPosition + delta, one move ahead of the
    // finger; canvasStartPosition is where the finger actually is.
    _held?.follow(event.canvasStartPosition.toOffset());
    _updateHover();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (event.pointerId != _pointer) return;
    _pointer = null;
    _drop();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (event.pointerId != _pointer) return;
    _pointer = null;
    _drop(force: true);
  }

  void _cancelHold() {
    _held?.removeFromParent();
    _held = null;
    _heldSlot = -1;
    _pointer = null;
    tray.showAll();
    board.clearHover();
  }

  void _updateHover() {
    final held = _held;
    if (held == null) return;
    final lead = held.leadCellCentre;
    if (!geom.nearBoard(lead)) {
      if (_hoverRow != -1) {
        _hoverRow = -1;
        _hoverCol = -1;
        board.clearHover();
      }
      return;
    }
    final piece = held.piece;
    final (row, col) = geom.anchorFor(lead, piece.height, piece.width);
    if (row == _hoverRow && col == _hoverCol) return;
    _hoverRow = row;
    _hoverCol = col;
    final b = host.state.board;
    if (!b.canPlace(piece, row, col)) {
      board.clearHover();
      return;
    }
    final lines = b.place(piece, row, col).fullLines();
    board.setHover(
      [for (final c in piece.cells) Cell(row + c.row, col + c.col)],
      piece.colourIndex,
      lines.rows,
      lines.cols,
    );
  }

  void _drop({bool force = false}) {
    final held = _held;
    if (held == null) return;
    final slot = _heldSlot;
    final piece = held.piece;
    if (!force && _hoverRow >= 0) {
      final b = host.state.board;
      if (b.canPlace(piece, _hoverRow, _hoverCol)) {
        _held = null;
        _heldSlot = -1;
        held.removeFromParent();
        board.clearHover();
        tray.showAll();
        _commit(slot, piece, _hoverRow, _hoverCol);
        return;
      }
    }
    _held = null;
    _heldSlot = -1;
    board.clearHover();
    _hoverRow = -1;
    held.flyBackTo(geom.traySlot(slot).center, tray.showAll);
  }

  // -------------------------------------------------------------- placement

  void _commit(int slot, Piece piece, int row, int col) {
    final before = host.state.board;
    audio.play(Sfx.place);
    haptics.fire(HapticEvent.place);
    final result = host.place(slot, row, col);
    _applyResult(result, before.place(piece, row, col));
  }

  void _applyResult(PlacementResult result, Board beforeClear) {
    board.syncColours(result.state.board);
    board.animatePlace(result.cellsPlaced);

    if (result.cellsCleared.isNotEmpty) {
      final origin = _centroid(result.cellsPlaced);
      board.animateClear(result.cellsCleared, beforeClear, origin);
      _burst(result.cellsCleared, beforeClear);
      board.shake(result.linesCleared);
      audio.play(Sfx.clearFor(result.multiplier));
      haptics.fire(result.linesCleared >= 2
          ? HapticEvent.clearManyLines
          : HapticEvent.clearOneLine);
      final stinger = Sfx.stingerFor(result.comboCount);
      if (stinger != null) {
        audio.play(stinger);
        haptics.fire(HapticEvent.combo);
      }
      if (result.boardCleared) audio.play(Sfx.boardClear);
      add(ScorePopupComponent(
        points: result.pointsAwarded,
        at: _centroid(result.cellsCleared),
        scale: geom.s,
        bounds: geom.well.deflate(4 * geom.s),
      ));
    }

    combo.value = result.comboCount >= 2 ? result.comboCount : 0;
    _rollScoreTo(result.state.score);
    _syncTray(animateNew: result.newSetGenerated);
    _lastBoard = result.state.board;
    if (result.gameOver) _beginGameOver();
  }

  void _beginGameOver() {
    _locked = true;
    add(TimerComponent(
      period: gameOverHold,
      removeOnFinish: true,
      onTick: () {
        audio.play(Sfx.gameOver);
        haptics.fire(HapticEvent.gameOver);
        _dimT = 0;
      },
    ));
  }

  void _rollScoreTo(int score) {
    if (score == displayScore.value) {
      _scoreT = 0;
      _scoreTo = score;
      return;
    }
    _scoreFrom = displayScore.value;
    _scoreTo = score;
    _scoreT = scoreRollDuration;
  }

  Offset _centroid(List<Cell> cells) {
    var x = 0.0, y = 0.0;
    for (final c in cells) {
      final p = geom.cellCentre(c.row, c.col);
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / cells.length, y / cells.length);
  }

  void _burst(List<Cell> cells, Board beforeClear) {
    for (final c in cells) {
      final colour = painter.blockColour(beforeClear.cellAt(c.row, c.col) ?? 0);
      final centre = geom.cellCentre(c.row, c.col);
      add(ParticleSystemComponent(
        priority: 25,
        position: Vector2(centre.dx, centre.dy),
        particle: Particle.generate(
          count: 8,
          lifespan: 0.45,
          generator: (_) => AcceleratedParticle(
            speed: Vector2(
              (_rng.nextDouble() - 0.5) * 150 * geom.s,
              -(20 + _rng.nextDouble() * 120) * geom.s,
            ),
            acceleration: Vector2(0, 620 * geom.s),
            child: CircleParticle(
              paint: Paint()..color = colour,
              radius: (1.2 + _rng.nextDouble() * 1.4) * geom.s,
            ),
          ),
        ),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_scoreT > 0) {
      _scoreT -= dt;
      final p = _scoreT <= 0 ? 1.0 : 1.0 - _scoreT / scoreRollDuration;
      displayScore.value =
          _scoreFrom + ((_scoreTo - _scoreFrom) * p * p * (3 - 2 * p)).round();
      if (_scoreT <= 0) {
        _scoreT = 0;
        displayScore.value = _scoreTo;
      }
    }
    if (_dimT >= 0) {
      _dimT += dt;
      final p = (_dimT / gameOverDim).clamp(0.0, 1.0);
      dim.value = p;
      if (p >= 1) {
        _dimT = -1;
        host.onGameOver();
      }
    }
  }
}
