import 'package:flutter/material.dart';

import '../app.dart';
import '../navigator.dart';
import 'screens/game_over_sheet.dart';
import 'screens/pause_sheet.dart';
import 'screens/reroll_sheet.dart';
import 'theme/typography.dart';

class WidgetNavigator implements AppNavigator {
  WidgetNavigator(this.navigatorKey, this.messengerKey, this.controller);

  static const String homeRoute = '/';
  static const String playRoute = '/play';

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final AppController controller;

  bool _sheetOpen = false;

  NavigatorState? get _navigator => navigatorKey.currentState;

  @override
  void goPlay() {
    final navigator = _navigator;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(
      playRoute,
      ModalRoute.withName(homeRoute),
    );
  }

  @override
  void goHome() => _navigator?.popUntil(ModalRoute.withName(homeRoute));

  @override
  void showGameOver() => _showSheet(
    GameOverSheet(controller: controller),
    dismissible: false,
  );

  @override
  void showPause() => _showSheet(PauseSheet(controller: controller));

  @override
  void showReroll() => _showSheet(RerollSheet(controller: controller));

  @override
  void dismissSheet() {
    if (!_sheetOpen) return;
    _sheetOpen = false;
    _navigator?.pop();
  }

  @override
  void showMessage(String text) {
    final palette = controller.palette;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: palette.empty,
        content: Text(
          text,
          style: manrope(size: 14, weight: 600, color: palette.ink),
        ),
      ),
    );
  }

  void _showSheet(Widget child, {bool dismissible = true}) {
    final context = navigatorKey.currentContext;
    if (context == null || _sheetOpen) return;
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: const Color(0x00000000),
      builder: (_) => child,
    ).whenComplete(() => _sheetOpen = false);
  }
}
