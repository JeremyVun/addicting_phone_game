import 'player_profile.dart';

enum ThemeUnlockKind { defaultUnlocked, level, coins }

/// Design 7.3. Colours belong to the UI, not here.
class ThemeSlot {
  const ThemeSlot(this.slot, this.name, this.unlockKind, this.requirement);

  final int slot;
  final String name;
  final ThemeUnlockKind unlockKind;

  /// Level or coin price, 0 for the default theme.
  final int requirement;
}

class Themes {
  const Themes._();

  static const List<ThemeSlot> all = [
    ThemeSlot(1, 'Obsidian', ThemeUnlockKind.defaultUnlocked, 0),
    ThemeSlot(2, 'Dawn', ThemeUnlockKind.level, 2),
    ThemeSlot(3, 'Meadow', ThemeUnlockKind.level, 4),
    ThemeSlot(4, 'Coral', ThemeUnlockKind.level, 6),
    ThemeSlot(5, 'Glacier', ThemeUnlockKind.level, 9),
    ThemeSlot(6, 'Desert', ThemeUnlockKind.level, 12),
    ThemeSlot(7, 'Storm', ThemeUnlockKind.level, 16),
    ThemeSlot(8, 'Lavender', ThemeUnlockKind.level, 20),
    ThemeSlot(9, 'Ember', ThemeUnlockKind.level, 25),
    ThemeSlot(10, 'Plum', ThemeUnlockKind.level, 30),
    ThemeSlot(11, 'Pearl', ThemeUnlockKind.coins, 1500),
    ThemeSlot(12, 'Lagoon', ThemeUnlockKind.coins, 3000),
  ];

  static const int count = 12;

  static ThemeSlot bySlot(int slot) => all[slot - 1];

  static Set<int> unlockedBy(PlayerProfile profile) {
    if (profile.themePackOwned) {
      return {for (final theme in all) theme.slot};
    }
    final level = profile.level;
    return {
      for (final theme in all)
        if (theme.unlockKind == ThemeUnlockKind.defaultUnlocked ||
            (theme.unlockKind == ThemeUnlockKind.level &&
                level >= theme.requirement) ||
            profile.unlockedThemes.contains(theme.slot))
          theme.slot,
    };
  }

  static bool isUnlocked(PlayerProfile profile, int slot) =>
      unlockedBy(profile).contains(slot);

  static bool canBuy(PlayerProfile profile, int slot) {
    final theme = bySlot(slot);
    return theme.unlockKind == ThemeUnlockKind.coins &&
        !isUnlocked(profile, slot) &&
        profile.coins >= theme.requirement;
  }

  static PlayerProfile buy(PlayerProfile profile, int slot) {
    if (!canBuy(profile, slot)) return profile;
    final theme = bySlot(slot);
    return profile.copyWith(
      coins: profile.coins - theme.requirement,
      unlockedThemes: {...profile.unlockedThemes, slot},
    );
  }

  static PlayerProfile select(PlayerProfile profile, int slot) =>
      isUnlocked(profile, slot)
      ? profile.copyWith(selectedTheme: slot)
      : profile;
}
