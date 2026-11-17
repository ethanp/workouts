import 'package:ethan_ui/ethan_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/features/cardio/same_type_comparison_card.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/same_type_workout_comparison.dart';

void main() {
  testWidgets('charts peers and reads out this workout by default', (
    tester,
  ) async {
    await _pumpCard(tester);

    expect(find.text('Indoor Cycle sessions'), findsOneWidget);
    expect(find.textContaining('this workout'), findsOneWidget);
    expect(find.text('Avg HR'), findsOneWidget);
    expect(find.text('120 bpm'), findsOneWidget);
    expect(find.text('Flights'), findsNothing);
  });

  testWidgets('tapping another session reads out its values', (tester) async {
    await _pumpCard(tester);
    final chartBox = tester.getRect(find.byType(EChart<String>));
    final plotWidth = chartBox.width - 8;
    final plotHeight = chartBox.height - 30;
    await tester.tapAt(
      Offset(
        chartBox.left + 4 + plotWidth / 16,
        chartBox.top + 8 + plotHeight * 0.92,
      ),
    );
    await tester.pump();

    expect(find.textContaining('this workout'), findsNothing);
    expect(find.text('2026-11-01'), findsOneWidget);
    expect(find.text('104 bpm'), findsOneWidget);
  });
}

Future<void> _pumpCard(WidgetTester tester) async {
  final catalog = [
    for (var day = 1; day <= 8; day++)
      _ride('ride-$day', day, heartRate: 100.0 + day * 4),
  ];
  final comparison = SameTypeWorkoutComparison.fromCatalog(
    thisWorkout: catalog[4],
    catalog: catalog,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SameTypeComparisonCard(comparison: comparison),
        ),
      ),
    ),
  );
}

CardioWorkout _ride(String id, int day, {required double heartRate}) {
  return CardioWorkout(
    id: id,
    externalWorkoutId: id,
    activityType: CardioType.indoorCycle,
    startedAt: DateTime.utc(2026, 11, day, 10),
    endedAt: DateTime.utc(2026, 11, day, 10, 12),
    durationSeconds: 600 + day * 30,
    distanceMeters: 4000.0 + day * 150,
    averageHeartRateBpm: heartRate,
    averageMets: 5.5 + day * 0.2,
    routeAvailable: false,
    sourceName: 'Apple Health',
  );
}
