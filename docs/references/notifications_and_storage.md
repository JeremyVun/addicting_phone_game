<!-- Retrieved 2026-09-08 | flutter_local_notifications 22.3.0 / shared_preferences 2.5.5 / path_provider 2.1.6 / games_services 5.3.0 -->

## Sources
- https://pub.dev/packages/flutter_local_notifications
- https://pub.dev/packages/flutter_local_notifications/changelog
- https://pub.dev/packages/flutter_local_notifications/versions
- https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/FlutterLocalNotificationsPlugin-class.html
- https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/AndroidScheduleMode.html
- https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/AndroidNotificationChannel-class.html
- https://raw.githubusercontent.com/MaikuB/flutter_local_notifications/master/flutter_local_notifications/README.md
- https://pub.dev/packages/timezone
- https://pub.dev/packages/flutter_timezone
- https://pub.dev/packages/shared_preferences
- https://pub.dev/packages/shared_preferences/versions
- https://pub.dev/documentation/shared_preferences/latest/shared_preferences/SharedPreferencesAsync-class.html
- https://pub.dev/documentation/shared_preferences/latest/shared_preferences/SharedPreferencesAsync/SharedPreferencesAsync.html
- https://pub.dev/documentation/shared_preferences/latest/shared_preferences/SharedPreferencesWithCache-class.html
- https://pub.dev/documentation/shared_preferences/latest/shared_preferences/SharedPreferencesWithCache/create.html
- https://pub.dev/documentation/shared_preferences/latest/shared_preferences/SharedPreferencesWithCacheOptions-class.html
- https://pub.dev/packages/path_provider
- https://pub.dev/documentation/path_provider/latest/path_provider/path_provider-library.html
- https://pub.dev/documentation/path_provider/latest/path_provider/getApplicationDocumentsDirectory.html
- https://pub.dev/documentation/path_provider/latest/path_provider/getApplicationSupportDirectory.html
- https://pub.dev/packages/games_services
- https://pub.dev/documentation/games_services/latest/games_services/games_services-library.html
- https://pub.dev/documentation/games_services/latest/games_services/GamesServices-class.html
- https://pub.dev/documentation/games_services/latest/games_services/Score-class.html
- https://pub.dev/documentation/games_services/latest/games_services/Achievement-class.html
- https://developer.android.com/develop/background-work/services/alarms/schedule
- https://support.google.com/googleplay/android-developer/answer/13161072
- https://developer.android.com/games/pgs/console/setup
- https://developer.android.com/games/pgs/android/android-signin
- https://developer.android.com/guide/topics/data/autobackup

## Versions
pub.dev only exposes relative timestamps, so exact publish dates are `UNVERIFIED`; dates below are derived from them on 2026-09-08.
- flutter_local_notifications **22.3.0** (~2026-08-08, "31 days ago"); 22.2.0 ~2026-07-25, 22.1.0 ~2026-07-19, 22.0.0 ~2026-06
- timezone **0.11.1** (~2026-07) / flutter_timezone **5.1.0** (~2026-06)
- shared_preferences **2.5.5** (~2026-04) / path_provider **2.1.6** (~2026-07) / games_services **5.3.0** (~2026-08-03)

SDK floors: flutter_local_notifications 21.0.0+ needs Flutter 3.38.1 / Dart 3.10 / Android API 24; games_services 5.3.0 needs Dart 3.12.

## flutter_local_notifications 22.x — initialization

```dart
final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');
const InitializationSettings initSettings = InitializationSettings(android: androidInit);

await plugin.initialize(settings: initSettings,
    onDidReceiveNotificationResponse: onTap,
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground);
```

Exact signature (v20+ made these params **named**; pre-20 positional code will not compile):
```dart
Future<bool?> initialize({required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse})
```

Background handler must be a **top-level or static** function with the pragma, else tree-shaking removes it:
```dart
@pragma('vm:entry-point')  // separate isolate; no access to UI isolate state
void notificationTapBackground(NotificationResponse notificationResponse) {}
```

- `@mipmap/ic_launcher` always exists, but a white-on-transparent `@drawable/ic_notification` is better: Android silhouettes the icon, so a colour launcher icon renders as a white blob.
- `getNotificationAppLaunchDetails()` → `Future<NotificationAppLaunchDetails?>` — check on cold start for launch-by-notification.

## Permissions (runtime)

```dart
final android = plugin.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin>();
final bool? granted = await android?.requestNotificationsPermission();   // Android 13+ POST_NOTIFICATIONS
final bool? exact   = await android?.requestExactAlarmsPermission();     // opens Alarms & reminders settings
await android?.areNotificationsEnabled();
```

- `requestNotificationsPermission()` — renamed from `requestPermission()` in **16.0.0**. Any snippet using `requestPermission()` on Android is stale.
- Other Android methods: `requestFullScreenIntentPermission()`, `requestNotificationPolicyAccess()`, and (22.3.0) `openAppNotificationSettings()` to deep-link the system settings page after a hard denial.
- `resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>()` returns `T?` (null off-platform, so always `?.`). On Android <13 `POST_NOTIFICATIONS` does not exist and the request is a no-op.

## Notification channels

```dart
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'lives_v1',            // id
  'Lives & reminders',   // user-visible name in system settings
  description: 'Tells you when your lives are full again.',
  importance: Importance.defaultImportance,
  playSound: true, enableVibration: true, showBadge: true);

await plugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
```

- Constructor params (all final): `id`, `name` positional; named `description`, `groupId`, `importance`, `playSound`, `sound`, `enableVibration`, `vibrationPattern`, `enableLights`, `ledColor`, `showBadge`, `bypassDnd`, `audioAttributesUsage`.
- **Channel settings are immutable after creation.** README: "For Android 8.0+, sounds and vibrations are associated with notification channels and can only be configured when they are first created." Re-calling `createNotificationChannel` with the same id does nothing. To change importance/sound, **bump the channel id** (`lives_v1` → `lives_v2`) and delete the old one via `deleteNotificationChannel(id)`.
- Users can mute any channel and the app cannot override that; use few, well-named channels (lives vs daily puzzle) so muting one does not mute all.
- `Importance.max/high` = heads-up popup; `defaultImportance` = sound, no popup; `low` = silent. `Priority` on `AndroidNotificationDetails` only matters pre-Android 8.

## show()

```dart
Future<void> show({required int id, String? title, String? body,
    NotificationDetails? notificationDetails, String? payload})
```

```dart
await plugin.show(
  id: 1, title: 'Lives full', body: 'All 5 lives are back.',
  notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails('lives_v1', 'Lives & reminders',
          channelDescription: 'Tells you when your lives are full again.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority)),
  payload: 'lives');
```

Common `AndroidNotificationDetails` fields: `channelId`, `channelName` (positional), `channelDescription`, `importance`, `priority`, `icon`, `largeIcon`, `color`, `styleInformation`, `playSound`, `sound`, `enableVibration`, `groupKey`, `setAsGroupSummary`, `ongoing`, `autoCancel` (default true), `showWhen`, `when`, `actions`, `ticker`, `category`, `fullScreenIntent`, `visibility`, `timeoutAfter`, `tag`, `onlyAlertOnce`.

## zonedSchedule()

```dart
Future<void> zonedSchedule({required int id, required TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title, String? body, String? payload,
    DateTimeComponents? matchDateTimeComponents})
```

```dart
await plugin.zonedSchedule(
  id: 42, title: 'Daily puzzle', body: 'A new board is waiting.',
  scheduledDate: _nextInstanceOf(hour: 19, minute: 0),
  notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails('daily_v1', 'Daily puzzle')),
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time); // repeats daily
```

- `androidScheduleMode` is **required** since 18.0.0, which removed `androidAllowWhileIdle`.
- `uiLocalNotificationDateInterpretation` and the `UILocalNotificationDateInterpretation` enum were **removed in 19.0.0**. Passing either is a compile error.
- `matchDateTimeComponents`: `DateTimeComponents.time` (daily), `.dayOfWeekAndTime` (weekly), `.dayOfMonthAndTime` (monthly), `.dateAndTime` (yearly). Omit for one-shot.
- `periodicallyShow({required int id, required RepeatInterval repeatInterval, required NotificationDetails notificationDetails, required AndroidScheduleMode androidScheduleMode, String? title, String? body, String? payload})` — `RepeatInterval` is coarse (everyMinute/hourly/daily/weekly) and not timezone-aware; prefer `zonedSchedule` + `matchDateTimeComponents`.
- The pub.dev README's `zonedSchedule` sample still shows a stale mixed positional/named form; the dartdoc signature above is authoritative.

### AndroidScheduleMode
| value | meaning (verbatim from dartdoc) |
|---|---|
| `alarmClock` | exact time AND executes while device is in low-power idle mode; "Requires SCHEDULE_EXACT_ALARM permission" |
| `exact` | exact time "but may not execute whilst device is in low-power idle mode" |
| `exactAllowWhileIdle` | exact time and executes while idle |
| `inexact` | "roughly specified time but may not execute whilst device is in low-power idle mode" |
| `inexactAllowWhileIdle` | roughly specified time and executes while idle |

## Timezone setup

```dart
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

tzdata.initializeTimeZones();
final TimezoneInfo info = await FlutterTimezone.getLocalTimezone(); // 5.x returns TimezoneInfo, not String
tz.setLocalLocation(tz.getLocation(info.identifier));               // field name `UNVERIFIED` — check TimezoneInfo dartdoc
```

- `timezone` alone always reports `tz.local == UTC` until `setLocalLocation` is called; the package explicitly states device-timezone detection "is not a goal of this package". `flutter_timezone` 5.1.0 supplies the IANA name.
- Build `TZDateTime` for the schedule:

```dart
tz.TZDateTime _nextInstanceOf({required int hour, required int minute}) {
  final now = tz.TZDateTime.now(tz.local);
  var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  return at.isBefore(now) ? at.add(const Duration(days: 1)) : at;
}
```
- `tz.TZDateTime.from(DateTime, Location)` converts an existing `DateTime`. Never pass a plain `DateTime` — `zonedSchedule` requires `TZDateTime`.
- DB variants: `data/latest.dart` (361kb, default), `data/latest_all.dart` (443kb), `data/latest_10y.dart` (85kb). A game should use `latest_10y` unless it schedules far-future dates.

## Exact vs inexact alarms + Play policy

- Android 12 (API 31)+: scheduling an exact alarm without `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM` throws `SecurityException`.
- Android 13 (API 33)+: apps choose between the two. Android 14: `SCHEDULE_EXACT_ALARM` is **not pre-granted on fresh installs** (only preserved on upgrade if already held); it is also denied after backup-restore.
- `USE_EXACT_ALARM` is auto-granted and non-revocable, but Play policy restricts it to apps whose "core, user facing functionality requires precisely-timed actions" — alarm clocks, timers, calendar event notifications. Requesting it otherwise triggers review and **rejection from Google Play**.
- **A puzzle game's "lives refilled" / "daily puzzle" reminder does not qualify.** Ship with no `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` in the manifest at all, `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`, and copy that never promises a precise minute ("your lives are back", not "at 7:00 PM sharp").
- Inexact guarantee (Android 12+): never fires early; the system delivers within ~1 hour of the trigger time unless battery restrictions apply. Windowed alarms clamp to a 10-minute minimum window.
- If a genuinely exact alarm is ever needed, gate it: `canScheduleExactAlarms()` (surfaced by the plugin as `canScheduleExactNotifications()` — name `UNVERIFIED`), request via `requestExactAlarmsPermission()`, and listen for `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` to reschedule when revoked.

## AndroidManifest.xml

Since **16.0.0** the plugin's own manifest declares only the bare minimum (`POST_NOTIFICATIONS`, `VIBRATE`); it does **not** merge the scheduling receivers. Apps that schedule must add them themselves. Still true in 22.x.
```xml
<manifest ...>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <uses-permission android:name="android.permission.VIBRATE"/>
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <!-- Do NOT add SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM for a puzzle game. -->
  <application ...>
    <receiver android:exported="false"
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
    <receiver android:exported="false"
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
      <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
      </intent-filter>
    </receiver>
    <!-- only if using notification actions -->
    <receiver android:exported="false"
        android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
  </application>
</manifest>
```

Desugaring is **mandatory** since plugin v10 for scheduled notifications:
```gradle
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
dependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4' }
```

## What silently breaks scheduled notifications
- **Reboot** — all alarms are cleared by the OS. `ScheduledNotificationBootReceiver` + `RECEIVE_BOOT_COMPLETED` restores them; without both, everything scheduled is lost.
- **App update** — `MY_PACKAGE_REPLACED` in the same receiver covers this; omit the action and reminders vanish on every Play update.
- **Force stop** (user swipes away from Settings, or some OEM task killers) — puts the app in a stopped state; alarms are cancelled and nothing runs until the user opens the app again. Not recoverable in code.
- **Battery optimisation / OEM aggressive killers** (Xiaomi, Huawei, Oppo, Samsung) — delay or drop inexact alarms indefinitely. Treat reminders as best-effort; never make game state depend on one firing.
- **Doze** — plain `exact`/`inexact` are deferred until the maintenance window; the `*AllowWhileIdle` variants are rate-limited (roughly one per app per ~9 minutes historically; `UNVERIFIED` for current versions).
- **Timezone/DST change after scheduling** — the pending alarm keeps its original absolute instant. Reschedule on app resume.
- Revoked POST_NOTIFICATIONS or a muted channel — the alarm fires, nothing is displayed.

## Cancelling / inspecting

```dart
await plugin.cancel(id: 42);            // `Future<void> cancel({required int id, String? tag})`
await plugin.cancelAll();
final List<PendingNotificationRequest> pending =
    await plugin.pendingNotificationRequests(); // id, title, body, payload
```
- Rescheduling the same `id` replaces the previous alarm; keep a const map of ids.
- `pendingNotificationRequests()` is the only reliable way to assert "the daily reminder is actually armed".

## shared_preferences 2.5.5

`SharedPreferencesAsync` and `SharedPreferencesWithCache` are the **current** APIs. The docs state `SharedPreferences` (the `getInstance()` API) "is a legacy API that will be deprecated in the future" — soft-deprecated: still works, still shipped, not yet annotated `@Deprecated`. New code should not use it.
```dart
// SharedPreferencesAsync({SharedPreferencesOptions options = const SharedPreferencesOptions()})
final prefs = SharedPreferencesAsync();
await prefs.setInt('coins', 120);
final int? coins = await prefs.getInt('coins');
await prefs.setStringList('unlocked_levels', <String>['1', '2']);
final List<String>? levels = await prefs.getStringList('unlocked_levels');
final bool has = await prefs.containsKey('coins');
final Set<String> keys = await prefs.getKeys();
final Map<String, Object?> all = await prefs.getAll();
await prefs.remove('coins');   await prefs.clear();
```
- Typed accessors: `getBool/setBool`, `getInt/setInt`, `getDouble/setDouble`, `getString/setString`, `getStringList/setStringList`. Getters return nullable futures; setters return `Future<void>`. Supported types: `int`, `double`, `bool`, `String`, `List<String>` — nothing else (encode objects as JSON strings).
- No cache: every get hits platform storage, so it is correct across isolates and engines — the right default for a game with a background notification isolate.

```dart
final cached = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: <String>{'coins', 'best_score', 'sound_on'}));
final int? best = cached.getInt('best_score'); // synchronous after create()
await cached.setInt('best_score', 900);
await cached.reloadCache();
```
```dart
static Future<SharedPreferencesWithCache> create({
  SharedPreferencesOptions sharedPreferencesOptions = const SharedPreferencesOptions(),
  required SharedPreferencesWithCacheOptions cacheOptions, Map<String, Object?>? cache})

SharedPreferencesWithCacheOptions({Set<String>? allowList})
```
- `allowList` "specifies what data will be fetched during `get` and `init` methods, what data can be `set`, as well as what data will be removed by `clear`." A key outside the allowList is invisible and unwritable, and `clear()` will not delete it — useful to stop a settings reset from nuking save data.
- Cached values go stale if another isolate writes; call `reloadCache()` before reads or use `SharedPreferencesAsync`.

### Android backend
```dart
const SharedPreferencesAsyncAndroidOptions options = SharedPreferencesAsyncAndroidOptions(
  backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
  originalSharedPreferencesOptions:
      AndroidSharedPreferencesStoreOptions(fileName: 'the_name_of_a_file'),
);
```
- Default Android backend is **DataStore Preferences**. Pass the options above only to read/write the legacy `SharedPreferences` XML file (e.g. to reach data written by the legacy API or by native code).

### Migration / prefix
- Legacy API prefixes every key with `flutter.` on the platform side; `SharedPreferences.setPrefix('')` must be called **before** `getInstance()` and before any other prefs call, else it throws.
- `SharedPreferencesAsync`/`WithCache` do **not** apply the `flutter.` prefix. Reading legacy data therefore needs the legacy key including its prefix, or a one-time migration pass. Verify against your own data before assuming keys line up.
- Migration: on first launch of the new build, read via the legacy API, write via `SharedPreferencesAsync`, set a `migrated_v2` flag.

## path_provider 2.1.6

| function | returns | Android |
|---|---|---|
| `getTemporaryDirectory()` | `Future<Directory>` | supported; cache dir, not backed up, **OS deletes at will** |
| `getApplicationCacheDirectory()` | `Future<Directory>` | supported; cache, not backed up, clearable |
| `getApplicationSupportDirectory()` | `Future<Directory>` | supported; Flutter engine `PathUtils.getFilesDir` |
| `getApplicationDocumentsDirectory()` | `Future<Directory>` | supported; Flutter engine `PathUtils.getDataDirectory` |
| `getExternalStorageDirectory()` | `Future<Directory?>` | supported; app-specific external dir, wiped on uninstall |
| `getExternalStorageDirectories({StorageDirectory? type})` / `getExternalCacheDirectories()` / `getDownloadsDirectory()` | `Future<List<Directory>?>` / `Future<Directory?>` | supported |

- All throw `MissingPlatformDirectoryException` if the platform cannot supply the path; `getLibraryDirectory()` is Android-invalid.
- **Right choice for save files: `getApplicationSupportDirectory()`** — internal, private, not user-visible, survives updates. Its dartdoc: "Use this for files you don't want exposed to the user. Your app should not use this directory for user data files." Save state is app data, not user documents.
- Use `getApplicationDocumentsDirectory()` only for user-generated exportable content; its dartdoc redirects everything else to support/cache/external.
- Backup: Android Auto Backup includes `getFilesDir()`, `getDir()`, databases, shared prefs and `getExternalFilesDir()`; it excludes `getCacheDir()`, `getCodeCacheDir()`, `getNoBackupFilesDir()`. Quota 25 MB per app per user; over quota, `onQuotaExceeded()` fires and nothing is uploaded. Restore happens after install, before first launch.
  Consequence: support-dir saves and shared_preferences **are** restored onto a new device, coins and lives timers included; only server-authoritative state defends against that.
- Never store saves in temporary/cache dirs — silently deleted under storage pressure.

## games_services 5.3.0

```dart
static Future<String?> signIn()
static Future<bool> get isSignedIn
static Future<String?> getPlayerID()
static Future<String?> getPlayerName()
static Stream<PlayerData?> get player
static Future<String?> submitScore({required Score score})
static Future<String?> showLeaderboards({String iOSLeaderboardID = "", String androidLeaderboardID = "",
    TimeScope timeScope = TimeScope.allTime, PlayerScope playerScope = PlayerScope.global})
static Future<int?> getPlayerScore({String iOSLeaderboardID = "", String androidLeaderboardID = ""})
static Future<List<LeaderboardScoreData>?> loadLeaderboardScores({String iOSLeaderboardID = "", String androidLeaderboardID = "", bool playerCentered = false, required PlayerScope scope, required TimeScope timeScope, bool forceRefresh = false, required int maxResults})
static Future<String?> unlock({required Achievement achievement})
static Future<String?> increment({required Achievement achievement})
static Future<String?> setSteps({required Achievement achievement})
static Future<String?> showAchievements()
static Future<List<AchievementItemData>?> loadAchievements({bool forceRefresh = false, bool ignoreImages = false})
static Future<String?> saveGame({required String data, required String name})
static Future<String?> loadGame({required String name})
static Future<List<SavedGame>?> getSavedGames({bool forceRefresh = false, bool ignoreImages = false})
static Future<String?> deleteGame({required String name})
static Future<SavedGame?> showSavedGames({required String title, bool allowNew = true, bool allowDelete = true, int? maxResults})
static Future<String?> showAccessPoint(AccessPointLocation location)  // + hideAccessPoint(), getAuthCode(String clientID), resetAchievements()

Score({String? iOSLeaderboardID, String? androidLeaderboardID, int? value, String? token})
Achievement({String androidID = "", String iOSID = "", bool showsCompletionBanner = true,
             double percentComplete = 100, int steps = 0})
```
- Most methods return `Future<String?>`: **null means success**, a non-null string is the error message. There are no exceptions to catch — ignoring the return value hides every failure.
- Classes exported: `Achievement, AchievementItemData, Achievements, GameAuth, GamesServices, IdentityVerificationSignature, Leaderboards, LeaderboardScoreData, NewSave, Player, PlayerData, SavedGame, SaveGame, Score`. Enums: `AccessPointLocation, PlayerScope, TimeScope`. The dartdoc notes `GamesServices` is a catch-all support class and recommends the specialised classes (`Leaderboards`, `Achievements`, `SaveGame`, `Player`) in new code.

```dart
await GamesServices.signIn();
if (await GamesServices.isSignedIn) {
  final err = await GamesServices.submitScore(
      score: Score(androidLeaderboardID: 'CgkI...', value: 12345));
  await GamesServices.showLeaderboards(androidLeaderboardID: 'CgkI...');
  await GamesServices.unlock(
      achievement: Achievement(androidID: 'CgkI...', percentComplete: 100));
}
```

### Android / Play Console setup
1. Play Console → **Grow users > Play Games Services > Setup and management > Configuration**. Create the PGS project (new, or linked to an existing Google Cloud project with `games.googleapis.com` enabled).
2. **Edit properties**: display name is required even for testing; description, category and graphics are required to publish.
3. **OAuth consent screen** must include the `games`, `games_lite` and `drive.appdata` scopes (the last is needed for saved games).
4. **Add credential → Android**: package name (must match the manifest exactly) + SHA-1. Create **two** credentials with the same package name — one for the debug keystore, one for the release/Play-signing cert:
   ```
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   keytool -list -v -keystore <release.keystore>
   ```
   With App Signing by Google Play, the release SHA-1 to register is the one from Play Console → App signing (the **app signing key**, not just the upload key). Registering only the upload key breaks the Play-distributed build.
5. Create leaderboards and achievements; their IDs look like `CgkI...` and are what `androidLeaderboardID` / `androidID` take. Do not hardcode display names.
6. **Testers** tab: add every test account (including your own publisher account) and add the internal/closed/open test tracks. Non-testers get OAuth/404 errors until the PGS config is published with **Publish Game**.
7. Publish the PGS configuration *before* publishing the app.

Manifest wiring (required; PGS sign-in fails without it):
```xml
<application>
  <meta-data android:name="com.google.android.gms.games.APP_ID"
             android:value="@string/game_services_project_id"/>
</application>
<!-- android/app/src/main/res/values/strings.xml -->
<resources>
  <string translatable="false" name="game_services_project_id">123456789012</string>
</resources>
```
- The project ID is the 12+ digit number at the top of the PGS Configuration page. If it is put in as a raw `android:value="123456789012"` rather than a string resource, Android parses it as an integer and PGS misreads it — always use `@string/`.
- PGS retries auth automatically on launch; only show a manual sign-in button if retries fail.

## Gotchas
1. **Exact alarms will get the app rejected.** `USE_EXACT_ALARM` is Play-restricted to alarm/timer/calendar apps; a "lives refilled" reminder does not qualify and requesting it is a review rejection. Ship `inexactAllowWhileIdle` and never promise a precise time in the copy.
2. **PGS sign-in fails silently on a SHA-1 mismatch.** Debug builds work while the Play build does not (or vice versa) because only one certificate is registered. Register debug **and** the Play app-signing SHA-1 as two credentials under the same package name, and remember Play re-signs your upload.
3. **Notification channel settings are frozen at creation.** Changing `importance`/sound in code after the first run does nothing on any device that already ran the app; you must ship a new channel id.
4. **No boot receiver = no reminders after a reboot or a Play update.** The plugin stopped merging `ScheduledNotificationBootReceiver` in v16; add it plus `RECEIVE_BOOT_COMPLETED`, `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED` yourself. Force-stop still kills alarms permanently until next launch — reschedule on every app start.
5. **v20 turned the plugin's positional params named, v19 deleted `uiLocalNotificationDateInterpretation`, v16 renamed `requestPermission()` to `requestNotificationsPermission()`.** Nearly every blog snippet online predates this and will not compile.
6. **`SharedPreferences.getInstance()` is legacy** and its `flutter.` key prefix does not carry over to `SharedPreferencesAsync`; a naive swap silently reads nothing and looks like data loss.
7. **`getTemporaryDirectory()` for saves = deleted saves.** Use `getApplicationSupportDirectory()`; note it *is* included in Auto Backup, so progress restores onto a new device (25 MB quota).
8. **games_services returns errors as `Future<String?>`, not exceptions.** `await GamesServices.submitScore(...)` with a discarded result swallows every failure.
9. **`tz.local` is UTC until you set it.** Without `flutter_timezone` + `setLocalLocation`, a "7 PM" daily reminder fires at 7 PM UTC.
10. **Desugaring is mandatory** (`coreLibraryDesugaringEnabled true` + `desugar_jdk_libs`), otherwise scheduled notifications fail to build or run.
