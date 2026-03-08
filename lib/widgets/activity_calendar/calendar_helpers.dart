import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/activity_calendar/calendar_constants.dart';

Color intensityColor(double intensity) {
  return Color.lerp(
    AppColors.accentPrimary.withValues(alpha: 0.15),
    AppColors.accentPrimary.withValues(alpha: 0.9),
    intensity,
  )!;
}

double intensityForDay({
  required double runMeters,
  required int sessionMinutes,
  required WeekMax globalMax,
}) {
  if (runMeters > 0 && globalMax.maxRunMeters > 0) {
    return (runMeters / globalMax.maxRunMeters).clamp(0.0, 1.0);
  }
  if (sessionMinutes > 0 && globalMax.maxSessionMinutes > 0) {
    return (sessionMinutes / globalMax.maxSessionMinutes).clamp(0.0, 1.0) * 0.5;
  }
  return 0.0;
}

