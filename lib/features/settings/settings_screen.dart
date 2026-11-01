import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/settings/apple_health_sync_tile.dart';
import 'package:workouts/features/settings/connection_tile.dart';
import 'package:workouts/features/settings/debug_tiles.dart';
import 'package:workouts/features/settings/health_data_inventory_screen.dart';

class const SettingsScreen() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const EAppHeader(
        title: 'Settings',
        automaticallyImplyLeading: false,
        leading: ESyncPhaseIcon(),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: ETabBarOverlay.paddingOf(context),
          children: const [
            ESettingsSection(title: 'Connection', children: [ConnectionTile()]),
            SizedBox(height: ELayout.spaceXl),
            ESettingsSection(
              title: 'Apple Health',
              children: [AppleHealthSyncTile(), HealthDataInventoryTile()],
            ),
            SizedBox(height: ELayout.spaceXl),
            ESettingsSection(
              title: 'Diagnostics',
              children: [CardioImportDebugTile(), SyncDebugTile()],
            ),
            SizedBox(height: ELayout.spaceXl),
            ESettingsSection(
              title: 'Debug log',
              children: [SizedBox(height: 360, child: EAppLogViewer())],
            ),
          ],
        ),
      ),
    );
  }
}
