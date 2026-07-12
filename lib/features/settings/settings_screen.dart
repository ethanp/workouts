import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/settings/apple_health_sync_tile.dart';
import 'package:workouts/features/settings/connection_tile.dart';
import 'package:workouts/features/settings/debug_tiles.dart';
import 'package:workouts/features/settings/settings_section.dart';
import 'package:workouts/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const AppLogViewerStyle _logViewerStyle = AppLogViewerStyle(
    surface: AppColors.backgroundDepth2,
    surfaceElevated: AppColors.backgroundDepth3,
    border: AppColors.borderDepth1,
    accent: AppColors.accentPrimary,
    textPrimary: AppColors.textColor1,
    textSecondary: AppColors.textColor2,
    textTertiary: AppColors.textColor3,
    warning: AppColors.warning,
    error: AppColors.error,
    radius: AppRadius.md,
    spacingXs: AppSpacing.xs,
    spacingSm: AppSpacing.sm,
    spacingMd: AppSpacing.md,
    spacingXl: AppSpacing.xl,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            SettingsSection(
              title: 'Connection',
              children: [ConnectionTile()],
            ),
            SizedBox(height: AppSpacing.xl),
            SettingsSection(
              title: 'Apple Health',
              children: [AppleHealthSyncTile()],
            ),
            SizedBox(height: AppSpacing.xl),
            SettingsSection(
              title: 'Diagnostics',
              children: [CardioImportDebugTile(), SyncDebugTile()],
            ),
            SizedBox(height: AppSpacing.xl),
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
