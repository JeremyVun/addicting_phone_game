import 'package:flutter/material.dart';

import '../app.dart';
import 'navigation.dart';
import 'screens/achievements_screen.dart';
import 'screens/home_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/play_route.dart';
import 'screens/themes_screen.dart';
import 'strings.dart';
import 'theme/palettes.dart';
import 'theme/typography.dart';

class SettleApp extends StatefulWidget {
  const SettleApp(this.controller, {super.key});

  final AppController controller;

  @override
  State<SettleApp> createState() => _SettleAppState();
}

class _SettleAppState extends State<SettleApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    widget.controller.navigator = WidgetNavigator(
      _navigatorKey,
      _messengerKey,
      widget.controller,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.controller.resumeFromLaunch(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Design 10: the reminder is recomputed on every background and dropped on
  /// every open, so it never fires at a player who is already here.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        widget.controller.scheduleReminderIfEnabled();
      case AppLifecycleState.resumed:
        widget.controller.cancelReminder();
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final palette = widget.controller.palette;
      return MaterialApp(
        title: S.appName,
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        debugShowCheckedModeBanner: false,
        theme: settleTheme(palette),
        initialRoute: WidgetNavigator.homeRoute,
        routes: {
          WidgetNavigator.homeRoute: (_) =>
              HomeScreen(controller: widget.controller),
          WidgetNavigator.playRoute: (_) =>
              PlayRoute(host: widget.controller),
          '/shop': (_) =>
              PlaceholderScreen(title: S.shopTitle, palette: palette),
          '/themes': (_) => ThemesScreen(controller: widget.controller),
          '/settings': (_) =>
              PlaceholderScreen(title: S.settingsTitle, palette: palette),
          '/achievements': (_) =>
              AchievementsScreen(controller: widget.controller),
        },
      );
    },
  );
}

ThemeData settleTheme(ThemePalette palette) => ThemeData(
  useMaterial3: true,
  fontFamily: 'Manrope',
  scaffoldBackgroundColor: palette.ground,
  canvasColor: palette.ground,
  splashFactory: InkRipple.splashFactory,
  colorScheme: ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: palette.lightGround ? Brightness.light : Brightness.dark,
    surface: palette.ground,
    primary: palette.accent,
    onPrimary: palette.onAccent,
  ),
  textTheme: TextTheme(
    bodyMedium: manrope(size: 15, weight: 500, color: palette.ink),
  ),
);
