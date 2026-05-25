import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/settings/apple_health_sync_tile.dart';
import 'package:workouts/features/settings/connection_tile.dart';
import 'package:workouts/features/settings/debug_tiles.dart';
import 'package:workouts/features/settings/settings_section.dart';
import 'package:workouts/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
          ],
        ),
      ),
    );
  }
}
