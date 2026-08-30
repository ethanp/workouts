/// A single plotted day in a rolling daily series: the trailing 7-day total
/// ([rollingValue]) and its smoothed counterpart ([smoothedValue]).
class const RollingDailyPoint({
  required final DateTime date,
  required final double rollingValue,
  required final double smoothedValue,
});
