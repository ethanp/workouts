import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/widgets/heart_rate_timeline_card.dart';

void main() {
  testWidgets('renders avg/max summary and chart', (tester) async {
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
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: HeartRateTimelineCard(samples: samples),
        ),
      ),
    );

    expect(find.text('Heart Rate'), findsOneWidget);
    expect(find.text('Avg 105 BPM · Max 120 BPM'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
