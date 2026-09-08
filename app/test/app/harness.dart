import 'package:settle/app.dart';
import 'package:settle/bootstrap.dart';
import 'package:settle/core/board.dart';
import 'package:settle/core/game_state.dart' as core;
import 'package:settle/navigator.dart';
import 'package:settle/services/ads.dart';
import 'package:settle/services/analytics.dart';
import 'package:settle/services/clock.dart';
import 'package:settle/services/notifications.dart';
import 'package:settle/services/purchases.dart';
import 'package:settle/services/storage.dart';

class RecordingNavigator implements AppNavigator {
  final List<String> calls = [];

  @override
  void goPlay() => calls.add('goPlay');

  @override
  void goHome() => calls.add('goHome');

  @override
  void showGameOver() => calls.add('showGameOver');

  @override
  void showPause() => calls.add('showPause');

  @override
  void showReroll() => calls.add('showReroll');

  @override
  void dismissSheet() => calls.add('dismissSheet');

  @override
  void showMessage(String text) => calls.add('message:$text');
}

class Harness {
  Harness({String? saved, DateTime? now})
    : storage = MemoryStorage(saved),
      clock = FixedClock(now ?? DateTime(2026, 9, 8, 12)) {
    controller = AppController(
      AppServices(
        storage: storage,
        clock: clock,
        ads: ads,
        purchases: purchases,
        analytics: analytics,
        notifications: notifications,
      ),
    )..navigator = navigator;
  }

  final MemoryStorage storage;
  final FixedClock clock;
  final FakeAdsService ads = FakeAdsService(
    showDuration: const Duration(milliseconds: 1),
  );
  final FakePurchaseService purchases = FakePurchaseService(
    delay: const Duration(milliseconds: 1),
  );
  final RecordingAnalytics analytics = RecordingAnalytics();
  final RecordingNotifications notifications = RecordingNotifications();
  final RecordingNavigator navigator = RecordingNavigator();
  late final AppController controller;

  Future<void> start() => controller.start();
}

/// Drives the current game to game over with the first legal move each turn.
Future<void> playToGameOver(AppController controller, {int maxMoves = 600}) async {
  for (var move = 0; move < maxMoves; move++) {
    if (controller.state.status == core.GameStatus.over) return;
    if (!_placeAnything(controller)) return;
    await controller.idle;
  }
}

bool _placeAnything(AppController controller) {
  final state = controller.state;
  for (var slot = 0; slot < 3; slot++) {
    final piece = state.set[slot];
    if (piece == null) continue;
    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        if (state.board.canPlace(piece, row, col)) {
          controller.place(slot, row, col);
          return true;
        }
      }
    }
  }
  return false;
}
