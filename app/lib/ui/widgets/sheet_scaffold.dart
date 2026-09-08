import 'package:flutter/material.dart';

import '../theme/palettes.dart';
import '../theme/typography.dart';

/// The bottom-sheet shell of `styles.md`: 22 px top radius, 20 px side padding.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.palette,
    required this.children,
  });

  final ThemePalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: palette.ground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
    ),
    padding: EdgeInsets.fromLTRB(
      20,
      18,
      20,
      18 + MediaQuery.of(context).padding.bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class SheetLabel extends StatelessWidget {
  const SheetLabel({super.key, required this.text, required this.palette});

  final String text;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: manrope(
      size: 11,
      weight: 700,
      color: palette.muted,
      letterSpacing: 1.76,
    ),
  );
}

class SheetHeadline extends StatelessWidget {
  const SheetHeadline({
    super.key,
    required this.value,
    required this.palette,
    this.badge,
  });

  final String value;
  final ThemePalette palette;
  final String? badge;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Text(
          value,
          style: manrope(
            size: 44,
            weight: 800,
            color: palette.ink,
            letterSpacing: -1.2,
            height: 1.05,
          ),
        ),
      ),
      if (badge != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            badge!.toUpperCase(),
            style: manrope(
              size: 13,
              weight: 800,
              color: palette.accent,
              letterSpacing: 1.4,
            ),
          ),
        ),
    ],
  );
}

class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.label,
    required this.palette,
    this.value,
    this.valueWidget,
  });

  final String label;
  final ThemePalette palette;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: palette.hairline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: manrope(size: 15, weight: 600, color: palette.muted),
          ),
        ),
        valueWidget ??
            Text(
              value ?? '',
              style: manrope(size: 15, weight: 800, color: palette.ink),
            ),
      ],
    ),
  );
}
