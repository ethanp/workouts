/// A single plotted day: the trailing 7-day total ([rollingValue]) and its
/// double-smoothed counterpart ([smoothedValue]).
class const RollingDailyPoint({
  required final DateTime date,
  required final double rollingValue,
  required final double smoothedValue,
});
