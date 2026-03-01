import 'package:workouts/providers/unit_system_provider.dart';

const _metersPerMile = 1609.344;
const _kmhToMph = 0.621371;

String formatDistance(double meters, UnitSystem unitSystem) {
  if (unitSystem == UnitSystem.imperial) {
    return '${(meters / _metersPerMile).toStringAsFixed(2)} mi';
  }
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

String formatPace(int durationSeconds, double distanceMeters, UnitSystem unitSystem) {
  if (distanceMeters <= 0) {
    return unitSystem == UnitSystem.imperial ? '--:-- /mi' : '--:-- /km';
  }
  final double paceSeconds;
  final String label;
  if (unitSystem == UnitSystem.imperial) {
    paceSeconds = durationSeconds / (distanceMeters / _metersPerMile);
    label = '/mi';
  } else {
    paceSeconds = durationSeconds / (distanceMeters / 1000);
    label = '/km';
  }
  final rounded = paceSeconds.round();
  final minutes = rounded ~/ 60;
  final seconds = rounded % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')} $label';
}

String formatSpeed(double speedKmh, UnitSystem unitSystem) {
  if (unitSystem == UnitSystem.imperial) {
    return '${(speedKmh * _kmhToMph).toStringAsFixed(1)} mph';
  }
  return '${speedKmh.toStringAsFixed(1)} km/h';
}
