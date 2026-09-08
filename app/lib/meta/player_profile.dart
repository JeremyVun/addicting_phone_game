import 'package:collection/collection.dart';
import 'economy.dart';
import 'levels.dart';

const _deepEquals = DeepCollectionEquality();

/// All persisted player state (design 4's `AppData.profile`).
class PlayerProfile {
  PlayerProfile({
    this.coins = 0,
    this.xp = 0,
    this.gamesCompleted = 0,
    this.bestClassic = 0,
    this.bestDaily = 0,
    this.skill = Economy.initialSkill,
    Set<int> unlockedThemes = const {},
    this.selectedTheme = 1,
    Set<String> achievements = const {},
    this.rewardCycleDay = 1,
    this.lastRewardClaimOrdinal,
    this.rewardDismissedOrdinal,
    this.streak = 0,
    this.lastCompletedOrdinal,
    this.streakReconciledOrdinal,
    this.freezesHeld = 0,
    Map<int, int> dailyBest = const {},
    Map<int, int> dailyAttempts = const {},
    this.dailySecondAttemptUsed,
    this.lastFirstGameOfDayOrdinal,
    this.adFree = false,
    this.themePackOwned = false,
    Set<String> pendingPurchaseTokens = const {},
    List<String> completedPurchaseTokens = const [],
    this.lastFinishedGameId,
    this.gamesSinceInterstitial = 0,
    this.lastInterstitialClosedAt = 0,
    this.lastRewardedClosedAt = 0,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.remindersEnabled = false,
    this.reminderPermissionAsked = false,
    this.analyticsUnitId = '',
    this.createdAtMs = 0,
  }) : unlockedThemes = Set.unmodifiable({defaultThemeSlot, ...unlockedThemes}),
       achievements = Set.unmodifiable(achievements),
       dailyBest = Map.unmodifiable(dailyBest),
       dailyAttempts = Map.unmodifiable(dailyAttempts),
       pendingPurchaseTokens = Set.unmodifiable(pendingPurchaseTokens),
       completedPurchaseTokens = List.unmodifiable(completedPurchaseTokens);

  factory PlayerProfile.initial({
    required String analyticsUnitId,
    required DateTime now,
  }) => PlayerProfile(
    analyticsUnitId: analyticsUnitId,
    createdAtMs: now.millisecondsSinceEpoch,
  );

  static const int version = 1;
  static const int defaultThemeSlot = 1;

  final int coins;
  final int xp;
  final int gamesCompleted;
  final int bestClassic;
  final int bestDaily;
  final double skill;
  final Set<int> unlockedThemes;
  final int selectedTheme;
  final Set<String> achievements;
  final int rewardCycleDay;
  final int? lastRewardClaimOrdinal;
  final int? rewardDismissedOrdinal;
  final int streak;
  final int? lastCompletedOrdinal;
  final int? streakReconciledOrdinal;
  final int freezesHeld;
  final Map<int, int> dailyBest;
  final Map<int, int> dailyAttempts;
  final int? dailySecondAttemptUsed;
  final int? lastFirstGameOfDayOrdinal;
  final bool adFree;
  final bool themePackOwned;
  final Set<String> pendingPurchaseTokens;
  final List<String> completedPurchaseTokens;
  final String? lastFinishedGameId;
  final int gamesSinceInterstitial;
  final int lastInterstitialClosedAt;
  final int lastRewardedClosedAt;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool remindersEnabled;
  final bool reminderPermissionAsked;
  final String analyticsUnitId;
  final int createdAtMs;

  int get level => Levels.levelFor(xp);

  double get levelProgress => Levels.progressWithinLevel(xp);

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  PlayerProfile copyWith({
    int? coins,
    int? xp,
    int? gamesCompleted,
    int? bestClassic,
    int? bestDaily,
    double? skill,
    Set<int>? unlockedThemes,
    int? selectedTheme,
    Set<String>? achievements,
    int? rewardCycleDay,
    int? lastRewardClaimOrdinal,
    int? rewardDismissedOrdinal,
    int? streak,
    int? lastCompletedOrdinal,
    int? streakReconciledOrdinal,
    int? freezesHeld,
    Map<int, int>? dailyBest,
    Map<int, int>? dailyAttempts,
    int? dailySecondAttemptUsed,
    int? lastFirstGameOfDayOrdinal,
    bool? adFree,
    bool? themePackOwned,
    Set<String>? pendingPurchaseTokens,
    List<String>? completedPurchaseTokens,
    String? lastFinishedGameId,
    int? gamesSinceInterstitial,
    int? lastInterstitialClosedAt,
    int? lastRewardedClosedAt,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? remindersEnabled,
    bool? reminderPermissionAsked,
    String? analyticsUnitId,
    int? createdAtMs,
  }) => PlayerProfile(
    coins: coins ?? this.coins,
    xp: xp ?? this.xp,
    gamesCompleted: gamesCompleted ?? this.gamesCompleted,
    bestClassic: bestClassic ?? this.bestClassic,
    bestDaily: bestDaily ?? this.bestDaily,
    skill: skill ?? this.skill,
    unlockedThemes: unlockedThemes ?? this.unlockedThemes,
    selectedTheme: selectedTheme ?? this.selectedTheme,
    achievements: achievements ?? this.achievements,
    rewardCycleDay: rewardCycleDay ?? this.rewardCycleDay,
    lastRewardClaimOrdinal:
        lastRewardClaimOrdinal ?? this.lastRewardClaimOrdinal,
    rewardDismissedOrdinal:
        rewardDismissedOrdinal ?? this.rewardDismissedOrdinal,
    streak: streak ?? this.streak,
    lastCompletedOrdinal: lastCompletedOrdinal ?? this.lastCompletedOrdinal,
    streakReconciledOrdinal:
        streakReconciledOrdinal ?? this.streakReconciledOrdinal,
    freezesHeld: freezesHeld ?? this.freezesHeld,
    dailyBest: dailyBest ?? this.dailyBest,
    dailyAttempts: dailyAttempts ?? this.dailyAttempts,
    dailySecondAttemptUsed:
        dailySecondAttemptUsed ?? this.dailySecondAttemptUsed,
    lastFirstGameOfDayOrdinal:
        lastFirstGameOfDayOrdinal ?? this.lastFirstGameOfDayOrdinal,
    adFree: adFree ?? this.adFree,
    themePackOwned: themePackOwned ?? this.themePackOwned,
    pendingPurchaseTokens: pendingPurchaseTokens ?? this.pendingPurchaseTokens,
    completedPurchaseTokens:
        completedPurchaseTokens ?? this.completedPurchaseTokens,
    lastFinishedGameId: lastFinishedGameId ?? this.lastFinishedGameId,
    gamesSinceInterstitial:
        gamesSinceInterstitial ?? this.gamesSinceInterstitial,
    lastInterstitialClosedAt:
        lastInterstitialClosedAt ?? this.lastInterstitialClosedAt,
    lastRewardedClosedAt: lastRewardedClosedAt ?? this.lastRewardedClosedAt,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderPermissionAsked:
        reminderPermissionAsked ?? this.reminderPermissionAsked,
    analyticsUnitId: analyticsUnitId ?? this.analyticsUnitId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );

  Map<String, dynamic> toJson() => {
    'v': version,
    'coins': coins,
    'xp': xp,
    'gamesCompleted': gamesCompleted,
    'bestClassic': bestClassic,
    'bestDaily': bestDaily,
    'skill': skill,
    'unlockedThemes': unlockedThemes.toList()..sort(),
    'selectedTheme': selectedTheme,
    'achievements': achievements.toList()..sort(),
    'rewardCycleDay': rewardCycleDay,
    'lastRewardClaimOrdinal': lastRewardClaimOrdinal,
    'rewardDismissedOrdinal': rewardDismissedOrdinal,
    'streak': streak,
    'lastCompletedOrdinal': lastCompletedOrdinal,
    'streakReconciledOrdinal': streakReconciledOrdinal,
    'freezesHeld': freezesHeld,
    'dailyBest': _ordinalMapToJson(dailyBest),
    'dailyAttempts': _ordinalMapToJson(dailyAttempts),
    'dailySecondAttemptUsed': dailySecondAttemptUsed,
    'lastFirstGameOfDayOrdinal': lastFirstGameOfDayOrdinal,
    'adFree': adFree,
    'themePackOwned': themePackOwned,
    'pendingPurchaseTokens': pendingPurchaseTokens.toList()..sort(),
    'completedPurchaseTokens': completedPurchaseTokens,
    'lastFinishedGameId': lastFinishedGameId,
    'gamesSinceInterstitial': gamesSinceInterstitial,
    'lastInterstitialClosedAt': lastInterstitialClosedAt,
    'lastRewardedClosedAt': lastRewardedClosedAt,
    'soundEnabled': soundEnabled,
    'hapticsEnabled': hapticsEnabled,
    'remindersEnabled': remindersEnabled,
    'reminderPermissionAsked': reminderPermissionAsked,
    'analyticsUnitId': analyticsUnitId,
    'createdAtMs': createdAtMs,
  };

  static PlayerProfile fromJson(Map<String, dynamic> json) => PlayerProfile(
    coins: json['coins'] as int? ?? 0,
    xp: json['xp'] as int? ?? 0,
    gamesCompleted: json['gamesCompleted'] as int? ?? 0,
    bestClassic: json['bestClassic'] as int? ?? 0,
    bestDaily: json['bestDaily'] as int? ?? 0,
    skill: (json['skill'] as num?)?.toDouble() ?? Economy.initialSkill,
    unlockedThemes: _intSet(json['unlockedThemes']),
    selectedTheme: json['selectedTheme'] as int? ?? defaultThemeSlot,
    achievements: _stringList(json['achievements']).toSet(),
    rewardCycleDay: json['rewardCycleDay'] as int? ?? 1,
    lastRewardClaimOrdinal: json['lastRewardClaimOrdinal'] as int?,
    rewardDismissedOrdinal: json['rewardDismissedOrdinal'] as int?,
    streak: json['streak'] as int? ?? 0,
    lastCompletedOrdinal: json['lastCompletedOrdinal'] as int?,
    streakReconciledOrdinal: json['streakReconciledOrdinal'] as int?,
    freezesHeld: json['freezesHeld'] as int? ?? 0,
    dailyBest: _ordinalMapFromJson(json['dailyBest']),
    dailyAttempts: _ordinalMapFromJson(json['dailyAttempts']),
    dailySecondAttemptUsed: json['dailySecondAttemptUsed'] as int?,
    lastFirstGameOfDayOrdinal: json['lastFirstGameOfDayOrdinal'] as int?,
    adFree: json['adFree'] as bool? ?? false,
    themePackOwned: json['themePackOwned'] as bool? ?? false,
    pendingPurchaseTokens: _stringList(json['pendingPurchaseTokens']).toSet(),
    completedPurchaseTokens: _stringList(json['completedPurchaseTokens']),
    lastFinishedGameId: json['lastFinishedGameId'] as String?,
    gamesSinceInterstitial: json['gamesSinceInterstitial'] as int? ?? 0,
    lastInterstitialClosedAt: json['lastInterstitialClosedAt'] as int? ?? 0,
    lastRewardedClosedAt: json['lastRewardedClosedAt'] as int? ?? 0,
    soundEnabled: json['soundEnabled'] as bool? ?? true,
    hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
    remindersEnabled: json['remindersEnabled'] as bool? ?? false,
    reminderPermissionAsked: json['reminderPermissionAsked'] as bool? ?? false,
    analyticsUnitId: json['analyticsUnitId'] as String? ?? '',
    createdAtMs: json['createdAtMs'] as int? ?? 0,
  );

  static Map<String, int> _ordinalMapToJson(Map<int, int> map) => {
    for (final key in map.keys.toList()..sort()) '$key': map[key]!,
  };

  static Map<int, int> _ordinalMapFromJson(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        int.parse(entry.key as String): (entry.value as num).toInt(),
    };
  }

  static Set<int> _intSet(Object? raw) =>
      raw is List ? raw.map((e) => (e as num).toInt()).toSet() : const {};

  static List<String> _stringList(Object? raw) =>
      raw is List ? raw.map((e) => e as String).toList() : const [];

  List<Object?> get _props => [
    coins,
    xp,
    gamesCompleted,
    bestClassic,
    bestDaily,
    skill,
    unlockedThemes,
    selectedTheme,
    achievements,
    rewardCycleDay,
    lastRewardClaimOrdinal,
    rewardDismissedOrdinal,
    streak,
    lastCompletedOrdinal,
    streakReconciledOrdinal,
    freezesHeld,
    dailyBest,
    dailyAttempts,
    dailySecondAttemptUsed,
    lastFirstGameOfDayOrdinal,
    adFree,
    themePackOwned,
    pendingPurchaseTokens,
    completedPurchaseTokens,
    lastFinishedGameId,
    gamesSinceInterstitial,
    lastInterstitialClosedAt,
    lastRewardedClosedAt,
    soundEnabled,
    hapticsEnabled,
    remindersEnabled,
    reminderPermissionAsked,
    analyticsUnitId,
    createdAtMs,
  ];

  @override
  bool operator ==(Object other) =>
      other is PlayerProfile && _deepEquals.equals(_props, other._props);

  @override
  int get hashCode => _deepEquals.hash(_props);

  @override
  String toString() =>
      'PlayerProfile(coins $coins, xp $xp, level $level, games $gamesCompleted)';
}
