import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/widgets/run_metrics_card.dart';

void main() {
  testWidgets('renders avg/max summary and chart', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final samples = [
      HeartRateSample(
        id: 's1',
        sessionId: 'session-1',
        timestamp: DateTime(2026, 1, 18, 10, 0, 0),
        bpm: 90,
        source: 'watch',
      ),
      HeartRateSample(
        id: 's2',
        sessionId: 'session-1',
        timestamp: DateTime(2026, 1, 18, 10, 0, 5),
        bpm: 120,
        source: 'watch',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: RunMetricsCard(samples: samples),
          ),
        ),
      ),
    );

    expect(find.text('Avg 105 · Max 120'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
