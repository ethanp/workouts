import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/health_export_summary.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/screens/settings_screen.dart';

import 'support/fake_health_kit_bridge.dart';

class _StaticPermissionNotifier extends HealthKitPermissionNotifier {
  _StaticPermissionNotifier(this._status);

  final HealthPermissionStatus _status;

  @override
  Future<HealthPermissionStatus> build() async => _status;
}

class _TestExportController extends HealthExportController {
  _TestExportController(this.summary, this.onDelete);

  final HealthExportSummary summary;
  final VoidCallback onDelete;

  @override
  Future<HealthExportSummary> build() async {
    return summary;
  }

  @override
  Future<void> deleteAllExports() async {
    onDelete();
    state = AsyncValue.data(
      summary.copyWith(exportedWorkoutUUIDs: const [], clearError: true),
    );
  }
}

void main() {
  testWidgets('settings screen surfaces export button with count', (
    tester,
  ) async {
    final bridge = FakeHealthKitBridge();
    var deleteInvoked = false;
    final summary = const HealthExportSummary(
      exportedWorkoutUUIDs: ['one', 'two', 'three'],
    );

    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthKitBridgeProvider.overrideWithValue(bridge),
          healthKitPermissionNotifierProvider.overrideWith(
            () => _StaticPermissionNotifier(HealthPermissionStatus.authorized),
          ),
          healthExportControllerProvider.overrideWith(
            () => _TestExportController(summary, () => deleteInvoked = true),
          ),
        ],
        child: const CupertinoApp(home: SettingsScreen()),
      ),
    );

    // Ensure the widget is fully built
    await tester.pumpAndSettle();

    expect(find.text('Remove 3 exported workouts'), findsOneWidget);

    await tester.tap(find.text('Remove 3 exported workouts'));
    await tester.pumpAndSettle();

    expect(find.text('Remove from Health'), findsOneWidget);

    await tester.tap(find.text('Remove from Health'));
    await tester.pumpAndSettle();

    expect(deleteInvoked, isTrue);
  });
}
