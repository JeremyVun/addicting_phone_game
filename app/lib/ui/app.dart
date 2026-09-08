import 'package:flutter/material.dart';

import '../app.dart';
import 'navigation.dart';
import 'screens/home_screen.dart';
import 'screens/placeholder_screen.dart';
import 'play/play_screen.dart';
import 'strings.dart';
import 'theme/palettes.dart';
import 'theme/typography.dart';

class SettleApp extends StatefulWidget {
  const SettleApp(this.controller, {super.key});

  final AppController controller;

  @override
  State<SettleApp> createState() => _SettleAppState();
}

class _SettleAppState extends State<SettleApp> {
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.controller.resumeFromLaunch(),
    );
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
          WidgetNavigator.playRoute: (_) => PlayScreen(
            host: widget.controller,
            audio: widget.controller.services.audio,
            haptics: widget.controller.services.haptics,
          ),
          '/shop': (_) =>
              PlaceholderScreen(title: S.shopTitle, palette: palette),
          '/themes': (_) =>
              PlaceholderScreen(title: S.themesTitle, palette: palette),
          '/settings': (_) =>
              PlaceholderScreen(title: S.settingsTitle, palette: palette),
          '/achievements': (_) =>
              PlaceholderScreen(title: S.achievementsTitle, palette: palette),
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
