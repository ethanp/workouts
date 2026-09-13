import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/features/history/activity_list/history_activity_list_tab.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';

const _phoneSize = Size(390, 844);

void main() {
  setUpAll(() async {
    await ETheme.loadFontsForWidgetTests();
  });

  testWidgets('writes history list for README', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_phoneSize);

    try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityListProvider.overrideWith(
            (ref) => Stream.value(_overviewCardio()),
          ),
          powerSyncDatabaseProvider.overrideWith(
            (ref) => Future<Never>.error(StateError('unused in README screenshot')),
          ),
        ],
        child: MaterialApp(
          theme: ETheme.material3Dark,
          debugShowCheckedModeBanner: false,
          home: EScaffoldShell(
            contentMaxWidth: double.infinity,
            appBar: const EAppHeader(
              title: 'History',
              automaticallyImplyLeading: false,
            ),
            bottomBar: ETabBar(
              selectedIndex: 0,
              tabs: const [
                ETab(icon: Icons.history, label: 'History'),
                ETab(icon: Icons.menu_book_outlined, label: 'Library'),
                ETab(icon: Icons.settings_outlined, label: 'Settings'),
              ],
              onSelected: (_) {},
            ),
            body: const HistoryActivityListTab(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshots/history.png'),
    );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

List<ActivityItem> _overviewCardio() {
  return [
    ActivityCardio(
      CardioWorkout(
        id: 'run-1',
        externalWorkoutId: 'ext-run-1',
        activityType: CardioType.outdoorRun,
        startedAt: DateTime(2026, 9, 11, 6, 32),
        endedAt: DateTime(2026, 9, 11, 7, 18),
        durationSeconds: 46 * 60,
        distanceMeters: 8200,
        averageHeartRateBpm: 148,
        hasHrSamples: true,
        zoneTime: const HrZoneTime(zone1: 240, zone2: 1680, zone3: 840),
        routeAvailable: true,
        sourceName: 'Apple Watch',
      ),
    ),
    ActivityCardio(
      CardioWorkout(
        id: 'run-2',
        externalWorkoutId: 'ext-run-2',
        activityType: CardioType.outdoorRun,
        startedAt: DateTime(2026, 9, 9, 6, 40),
        endedAt: DateTime(2026, 9, 9, 7, 12),
        durationSeconds: 32 * 60,
        distanceMeters: 5400,
        averageHeartRateBpm: 142,
        hasHrSamples: true,
        zoneTime: const HrZoneTime(zone1: 360, zone2: 1260, zone3: 300),
        routeAvailable: true,
        sourceName: 'Apple Watch',
      ),
    ),
    ActivityCardio(
      CardioWorkout(
        id: 'walk-1',
        externalWorkoutId: 'ext-walk-1',
        activityType: CardioType.outdoorWalk,
        startedAt: DateTime(2026, 9, 8, 18, 10),
        endedAt: DateTime(2026, 9, 8, 19, 5),
        durationSeconds: 55 * 60,
        distanceMeters: 4200,
        routeAvailable: true,
        sourceName: 'Apple Watch',
      ),
    ),
    ActivityCardio(
      CardioWorkout(
        id: 'ellip-1',
        externalWorkoutId: 'ext-ellip-1',
        activityType: CardioType.elliptical,
        startedAt: DateTime(2026, 9, 6, 7, 0),
        endedAt: DateTime(2026, 9, 6, 7, 35),
        durationSeconds: 35 * 60,
        distanceMeters: 6100,
        averageHeartRateBpm: 131,
        routeAvailable: false,
        sourceName: 'Apple Watch',
      ),
    ),
  ];
}
