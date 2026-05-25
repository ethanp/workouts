import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/settings/apple_health_sync_tile.dart';
import 'package:workouts/features/settings/connection_tile.dart';
import 'package:workouts/features/settings/diagnostics_screen.dart';
import 'package:workouts/features/settings/settings_section.dart';
import 'package:workouts/features/settings/settings_tiles.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';
import 'package:workouts/features/library/template_version_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(healthKitPermissionProvider);
    final versionAsync = ref.watch(templateVersionControllerProvider);
    final unitSystem = ref.watch(unitSystemProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SettingsSection(
              title: 'Preferences',
              children: [UnitSystemTile(unitSystem: unitSystem, ref: ref)],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SettingsSection(
              title: 'Connection',
              children: [ConnectionTile()],
            ),
            const SizedBox(height: AppSpacing.xl),
            SettingsSection(
              title: 'Health & Templates',
              children: [
                PermissionStatusTile(
                  permissionAsync: permissionAsync,
                  ref: ref,
                ),
                TemplateVersionTile(versionAsync: versionAsync, ref: ref),
                const AppleHealthSyncTile(),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SettingsSection(
              title: 'Diagnostics',
              children: [_DiagnosticsRow()],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => const DiagnosticsScreen(),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundDepth3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                CupertinoIcons.wrench,
                color: AppColors.textColor2,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Open diagnostics',
                    style: AppTypography.subtitle,
                  ),
                  Text(
                    'Heart rate zone reference, import counts, sync controls',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textColor3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textColor4,
            ),
          ],
        ),
      ),
    );
  }
}
