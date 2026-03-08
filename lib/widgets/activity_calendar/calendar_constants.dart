const double calendarCellSize = 39;
const double calendarCellMargin = 2;
const double calendarSummaryWidth = 60;
const double calendarDaysBadgeWidth = 18;
const double calendarSummaryFontSize = 10;
const int daysPerWeek = 7;

class WeekMax {
  const WeekMax({required this.maxRunMeters, required this.maxSessionMinutes});

  final double maxRunMeters;
  final int maxSessionMinutes;
}
