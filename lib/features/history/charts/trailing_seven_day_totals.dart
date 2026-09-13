import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/features/history/charts/rolling_daily_point.dart';
import 'package:workouts/models/activity_calendar_day.dart';

class const TrailingSevenDayTotals() {
  List<RollingDailyPoint> build({
    required List<ActivityCalendarDay> days,
    required DateTime endDate,
    required double Function(ActivityCalendarDay day) dailyValue,
  }) {
    final observed = <EDailyQuantity>[];
    for (final activityDay in days) {
      if (!activityDay.hasActivity) continue;
      observed.add(
        EDailyQuantity(
          date: activityDay.date.startOfDay,
          quantity: dailyValue(activityDay),
        ),
      );
    }

    return [
      for (final point in ETrailingSevenDaySmoothedTotals.of(
        observed,
        through: endDate,
      ))
        RollingDailyPoint(
          date: point.date,
          rollingValue: point.trailingTotal,
          smoothedValue: point.smoothedTotal,
        ),
    ];
  }
}
