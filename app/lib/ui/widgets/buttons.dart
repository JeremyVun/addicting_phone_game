import 'package:flutter/material.dart';

import '../theme/palettes.dart';
import '../theme/typography.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.palette,
    this.height = 52,
    this.showPlayIcon = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final ThemePalette? palette;
  final double height;
  final bool showPlayIcon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colours = palette ?? ThemePalette.obsidian;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Material(
          color: colours.accent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showPlayIcon) ...[
                  Icon(
                    Icons.play_arrow_rounded,
                    color: colours.onAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: manrope(
                      size: height >= 60 ? 22 : 18,
                      weight: 800,
                      color: colours.onAccent,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    trailing!,
                    style: manrope(
                      size: 13,
                      weight: 700,
                      color: colours.onAccent.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.palette,
    this.height = 52,
    this.showPlayIcon = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final ThemePalette? palette;
  final double height;
  final bool showPlayIcon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colours = palette ?? ThemePalette.obsidian;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colours.hairline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showPlayIcon) ...[
                Icon(Icons.play_arrow_rounded, color: colours.ink, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: manrope(
                  size: 17,
                  weight: 800,
                  color: colours.ink,
                  letterSpacing: -0.2,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                Text(
                  trailing!,
                  style: manrope(size: 13, weight: 700, color: colours.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.palette,
  });

  final String label;
  final VoidCallback? onPressed;
  final ThemePalette? palette;

  @override
  Widget build(BuildContext context) {
    final colours = palette ?? ThemePalette.obsidian;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: manrope(size: 16, weight: 700, color: colours.muted),
        ),
      ),
    );
  }
}
