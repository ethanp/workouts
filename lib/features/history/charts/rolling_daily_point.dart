/// A single plotted day in a rolling daily series: the trailing 7-day total
/// ([rollingValue]) and its smoothed counterpart ([smoothedValue]).
class RollingDailyPoint {
  const RollingDailyPoint({
    required this.date,
    required this.rollingValue,
    required this.smoothedValue,
  });

  final DateTime date;
  final double rollingValue;
  final double smoothedValue;
}
