import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../config.dart';
import '../strings.dart';
import '../theme/palettes.dart';
import '../theme/typography.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final palette = controller.palette;
      final profile = controller.profile;
      return Scaffold(
        backgroundColor: palette.ground,
        appBar: AppBar(
          backgroundColor: palette.ground,
          foregroundColor: palette.ink,
          elevation: 0,
          title: Text(
            S.settingsTitle,
            style: manrope(size: 18, weight: 800, color: palette.ink),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              _SwitchRow(
                label: S.settingsSound,
                value: profile.soundEnabled,
                palette: palette,
                onChanged: controller.setSound,
              ),
              _SwitchRow(
                label: S.settingsHaptics,
                value: profile.hapticsEnabled,
                palette: palette,
                onChanged: controller.setHaptics,
              ),
              _SwitchRow(
                label: S.settingsReminder,
                value: profile.remindersEnabled,
                palette: palette,
                onChanged: controller.setRemindersEnabled,
              ),
              if (controller.privacyOptionsRequired)
                _TapRow(
                  label: S.settingsPrivacyOptions,
                  palette: palette,
                  onTap: controller.showPrivacyOptions,
                ),
              _TapRow(
                label: S.settingsRestore,
                palette: palette,
                onTap: () async {
                  await controller.restorePurchases();
                  controller.navigator.showMessage(S.shopRestored);
                },
              ),
              _TapRow(
                label: S.settingsPrivacyPolicy,
                palette: palette,
                onTap: () => launchUrl(
                  Uri.parse(kPrivacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _VersionRow(palette: palette),
            ],
          ),
        ),
      );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.palette, this.trailing});

  final String label;
  final ThemePalette palette;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: palette.hairline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: manrope(size: 16, weight: 700, color: palette.ink),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ThemePalette palette;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) => _Row(
    label: label,
    palette: palette,
    trailing: Switch(
      value: value,
      activeThumbColor: palette.onAccent,
      activeTrackColor: palette.accent,
      onChanged: onChanged,
    ),
  );
}

class _TapRow extends StatelessWidget {
  const _TapRow({
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final ThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: _Row(
      label: label,
      palette: palette,
      trailing: Icon(Icons.chevron_right_rounded, color: palette.muted),
    ),
  );
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.palette});

  final ThemePalette palette;

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    builder: (context, snapshot) {
      final version = snapshot.data?.version;
      if (version == null) return const SizedBox.shrink();
      return _Row(label: S.settingsVersion(version), palette: palette);
    },
  );
}
