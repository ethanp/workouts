import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/health_data_inventory.dart';

void main() {
  test('jsonEmailBody is indented JSON of workouts and source matrix', () {
    final inventory = HealthDataInventory.fromMap({
      'requestedTypes': [
        {'id': 'heartRate', 'shareStatus': 'sharingAuthorized'},
      ],
      'workouts': [
        {
          'externalWorkoutId': 'w1',
          'activityType': 'indoorWalk',
          'startDate': '2026-09-01T12:00:00.000Z',
          'endDate': '2026-09-01T12:30:00.000Z',
          'durationSeconds': 1800,
          'sourceName': 'Apple Watch',
          'deviceName': 'Apple Watch',
          'machineLinked': false,
          'signals': [
            {
              'type': 'HKQuantityTypeIdentifierHeartRate',
              'sampleCount': 120,
              'hasCondensed': false,
              'coverageSeconds': 1800,
              'associated': true,
              'kind': 'quantity',
            },
          ],
          'statistics': [
            {
              'type': 'HKQuantityTypeIdentifierRunningSpeed',
              'source': 'workoutStatistics',
              'unit': 'm/s',
              'average': 2.4,
            },
          ],
          'metadata': {'HKIndoorWorkout': 'true'},
        },
      ],
    });

    expect(inventory.jsonEmailBody, contains('"activityType": "indoorWalk"'));
    expect(inventory.jsonEmailBody, contains('"sourceName": "Apple Watch"'));
    expect(inventory.jsonEmailBody, contains('"type": "HKQuantityTypeIdentifierHeartRate"'));
    expect(inventory.jsonEmailBody, contains('"type": "HKQuantityTypeIdentifierRunningSpeed"'));
    expect(inventory.jsonEmailBody, contains('"HKIndoorWorkout": "true"'));
    expect(inventory.workouts.single.statistics.single.shortType, 'RunningSpeed');
    expect(inventory.jsonEmailBody, contains('\n  '));
  });

  test('inspect progress names the current workout count', () {
    final inspectProgress = HealthInventoryInspectProgress.fromMap({
      'caption': 'Inspecting indoorWalk · Apple Watch (3 of 40)',
      'completedWorkouts': 2,
      'totalWorkouts': 40,
    });
    expect(inspectProgress.caption, contains('indoorWalk'));
    expect(inspectProgress.fraction, 2 / 40);
  });
}
