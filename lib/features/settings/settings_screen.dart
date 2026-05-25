import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/settings/apple_health_sync_tile.dart';
import 'package:workouts/features/settings/connection_tile.dart';
import 'package:workouts/features/settings/debug_tiles.dart';
import 'package:workouts/features/settings/settings_section.dart';
import 'package:workouts/features/settings/settings_tiles.dart';
import 'package:workouts/features/library/template_version_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(templateVersionControllerProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SettingsSection(
              title: 'Connection',
              children: [ConnectionTile()],
            ),
            const SizedBox(height: AppSpacing.xl),
            SettingsSection(
              title: 'Health & Templates',
              children: [
                TemplateVersionTile(versionAsync: versionAsync, ref: ref),
                const AppleHealthSyncTile(),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SettingsSection(
              title: 'Diagnostics',
              children: [CardioImportDebugTile(), SyncDebugTile()],
            ),
          ],
        ),
      ),
    );
  }
}
