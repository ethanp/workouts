import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/influences_provider.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/providers/template_version_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/settings/debug_tiles.dart';
import 'package:workouts/widgets/settings/settings_tiles.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(healthKitPermissionProvider);
    final versionAsync = ref.watch(templateVersionControllerProvider);
    final syncStatus = ref.watch(powerSyncStatusProvider);
    final influencesAsync = ref.watch(activeInfluencesProvider);
    final unitSystem = ref.watch(unitSystemProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            UnitSystemTile(unitSystem: unitSystem, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            const MaxHeartRateTile(),
            const SizedBox(height: AppSpacing.lg),
            const RestingHeartRateTile(),
            const SizedBox(height: AppSpacing.lg),
            TrainingInfluencesTile(influencesAsync: influencesAsync),
            const SizedBox(height: AppSpacing.lg),
            SyncStatusTile(syncStatus: syncStatus),
            const SizedBox(height: AppSpacing.lg),
            TemplateVersionTile(versionAsync: versionAsync, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            PermissionStatusTile(permissionAsync: permissionAsync, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            const HealthRunImportTile(),
            const SizedBox(height: AppSpacing.lg),
            const RunImportDebugTile(),
            const SizedBox(height: AppSpacing.lg),
            const SyncDebugTile(),
          ],
        ),
      ),
    );
  }
}
