import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/settings/apple_health_sync_tile.dart';
import 'package:workouts/features/settings/connection_tile.dart';
import 'package:workouts/features/settings/debug_tiles.dart';
import 'package:workouts/features/settings/health_data_inventory_screen.dart';
import 'package:workouts/features/settings/settings_section.dart';

class const SettingsScreen() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const EAppHeader(title: 'Settings', automaticallyImplyLeading: false),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(ELayout.spaceLg).withOverlaidTabBar(context),
          children: const [
            SettingsSection(title: 'Connection', children: [ConnectionTile()]),
            SizedBox(height: ELayout.spaceXl),
            SettingsSection(
              title: 'Apple Health',
              children: [AppleHealthSyncTile(), HealthDataInventoryTile()],
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
                  child: EAppLogViewer(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
