import 'package:flutter/material.dart';

import '../../app.dart';
import '../../meta/meta.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';
import '../widgets/coin_chip.dart';
import '../widgets/format.dart';

/// Design 7.3. Selecting re-themes the whole app because `SettleApp` rebuilds
/// on `controller.palette`.
class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final palette = controller.palette;
      return Scaffold(
        backgroundColor: palette.ground,
        appBar: AppBar(
          backgroundColor: palette.ground,
          foregroundColor: palette.ink,
          elevation: 0,
          title: Text(
            S.themesTitle,
            style: manrope(size: 18, weight: 800, color: palette.ink),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: CoinChip(
                  coins: controller.profile.coins,
                  palette: palette,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        body: GridView.count(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: [
            for (final slot in Themes.all)
              _ThemeTile(controller: controller, slot: slot),
          ],
        ),
      );
    },
  );
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.controller, required this.slot});

  final AppController controller;
  final ThemeSlot slot;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final chrome = controller.palette;
    final colours = ThemePalette.all[slot.slot - 1];
    final unlocked = Themes.isUnlocked(profile, slot.slot);
    final selected = profile.selectedTheme == slot.slot;
    final buyable = Themes.canBuy(profile, slot.slot);
    final state = selected
        ? S.themesSelected
        : unlocked
        ? S.themesGet
        : slot.unlockKind == ThemeUnlockKind.level
        ? S.themesLevelLock(slot.requirement)
        : buyable
        ? S.themesBuy(formatCount(slot.requirement))
        : S.themesCoinLock(formatCount(slot.requirement));
    final onTap = selected
        ? null
        : unlocked
        ? () => controller.selectTheme(slot.slot)
        : buyable
        ? () => controller.buyTheme(slot.slot)
        : null;
    return Opacity(
      opacity: unlocked || buyable ? 1 : 0.5,
      child: Material(
        color: colours.well,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? chrome.accent : chrome.hairline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Swatch(colours: colours)),
                const SizedBox(height: 10),
                Text(
                  slot.name,
                  style: manrope(size: 15, weight: 800, color: colours.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  state,
                  style: manrope(
                    size: 12,
                    weight: 700,
                    color: selected ? chrome.accent : colours.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colours});

  final ThemePalette colours;

  static const List<int> _shown = [0, 2, 4, 6];

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: colours.ground,
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final index in _shown)
              _Tile(colour: colours.block(index), radius: 4),
            _Tile(colour: colours.accent, radius: 9),
          ],
        ),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.colour, required this.radius});

  final Color colour;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: colour,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
