import 'package:ethan_utils/ethan_utils.dart';

const metersPerMile = 1609.344;

enum DistanceBucket(final double meters, final String label) {
  fourHundredMeters(400, '400m'),
  halfMile(metersPerMile / 2, '1/2 mi'),
  oneMile(metersPerMile, '1 mi'),
  fiveK(5000, '5k'),
  fiveMiles(metersPerMile * 5, '5 mi');

  static DistanceBucket? fromMeters(double meters) {
    for (final bucket in values) {
      if ((bucket.meters - meters).abs() < 0.01) return bucket;
    }
    return null;
  }
}

extension DistanceMetersFormatting on num {
  double get asMiles => this / metersPerMile;

  String get milesCaption => '${asMiles.toStringAsFixed(2)} mi';

  String milePaceCaption(Duration elapsed) => elapsed.pacePerMile(this);
}

extension DurationMilePace on Duration {
  String pacePerMile(num distanceMeters) {
    if (distanceMeters <= 0) return '--:-- /mi';
    final paceSeconds = inSeconds / (distanceMeters / metersPerMile);
    return '${Duration(seconds: paceSeconds.round()).formattedMinutesSeconds} /mi';
  }
}

extension PaceSecondsCaption on num {
  String get paceCaption => Duration(seconds: round()).formattedMinutesSeconds;
}
