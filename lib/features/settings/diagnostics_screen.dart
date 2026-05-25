import 'package:flutter/cupertino.dart';
import 'package:workouts/features/settings/debug_tiles.dart';
import 'package:workouts/features/settings/hr_zones_reference_tile.dart';
import 'package:workouts/theme/app_theme.dart';

/// Sub-screen for read-only references and advanced diagnostic controls.
/// Pushed from the main settings screen so the everyday surface stays clean.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Diagnostics'),
        previousPageTitle: 'Settings',
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            HrZonesReferenceTile(),
            SizedBox(height: AppSpacing.lg),
            CardioImportDebugTile(),
            SizedBox(height: AppSpacing.lg),
            SyncDebugTile(),
          ],
        ),
      ),
    );
  }
}
