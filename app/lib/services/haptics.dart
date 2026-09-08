import 'package:flutter/services.dart';

/// The events of design 9.4. Naming the event rather than the feedback keeps
/// the mapping in one place.
enum HapticEvent {
  place,
  clearOneLine,
  clearManyLines,
  combo,
  gameOver,
  button,
}

abstract class HapticsService {
  void fire(HapticEvent event);
  void setEnabled(bool enabled);
}

class NoopHapticsService implements HapticsService {
  const NoopHapticsService();

  @override
  void fire(HapticEvent event) {}

  @override
  void setEnabled(bool enabled) {}
}

class PlatformHapticsService implements HapticsService {
  PlatformHapticsService({bool enabled = true}) : _enabled = enabled;

  static const gameOverGap = Duration(milliseconds: 120);

  bool _enabled;

  @override
  void setEnabled(bool enabled) => _enabled = enabled;

  @override
  void fire(HapticEvent event) {
    if (!_enabled) return;
    switch (event) {
      case HapticEvent.place:
      case HapticEvent.button:
        HapticFeedback.selectionClick();
      case HapticEvent.clearOneLine:
        HapticFeedback.lightImpact();
      case HapticEvent.clearManyLines:
        HapticFeedback.mediumImpact();
      case HapticEvent.combo:
        HapticFeedback.heavyImpact();
      case HapticEvent.gameOver:
        HapticFeedback.heavyImpact();
        Future<void>.delayed(gameOverGap, HapticFeedback.heavyImpact);
    }
  }
}
