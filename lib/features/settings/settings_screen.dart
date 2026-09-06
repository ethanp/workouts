import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/settings/apple_health_sync_tile.dart';
import 'package:workouts/features/settings/connection_tile.dart';
import 'package:workouts/features/settings/debug_tiles.dart';
import 'package:workouts/features/settings/settings_section.dart';

class const SettingsScreen() extends ConsumerWidget {
  static const AppLogViewerStyle _logViewerStyle = AppLogViewerStyle(
    surface: EColors.backgroundLift,
    surfaceElevated: EColors.surface,
    border: EColors.border,
    accent: EColors.accent,
    textPrimary: EColors.textPrimary,
    textSecondary: EColors.textSecondary,
    textTertiary: EColors.textTertiary,
    warning: EColors.warning,
    error: EColors.danger,
    radius: ELayout.radiusMd,
    spacingXs: ELayout.spaceXs,
    spacingSm: ELayout.spaceSm,
    spacingMd: ELayout.spaceMd,
    spacingXl: ELayout.spaceXl,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const EAppHeader(title: 'Settings', automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(ELayout.spaceLg),
          children: const [
            SettingsSection(title: 'Connection', children: [ConnectionTile()]),
            SizedBox(height: ELayout.spaceXl),
            SettingsSection(
              title: 'Apple Health',
              children: [AppleHealthSyncTile()],
            ),
            SizedBox(height: ELayout.spaceXl),
            SettingsSection(
              title: 'Diagnostics',
              children: [CardioImportDebugTile(), SyncDebugTile()],
            ),
            SizedBox(height: ELayout.spaceXl),
            SettingsSection(
              title: 'Debug log',
              children: [
                SizedBox(
                  height: 360,
                  child: AppLogViewer(style: _logViewerStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
