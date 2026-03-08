import 'package:workouts/providers/unit_system_provider.dart';

const metersPerMile = 1609.344;
const _kmhToMph = 0.621371;

class Format {
  Format._();

  /// "3.21 mi" or "3.21 km".
  static String distance(double meters, UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.imperial) {
      return '${(meters / metersPerMile).toStringAsFixed(2)} mi';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  /// "3.2mi" or "3.2km" — no space, fewer decimals.
  static String distanceCompact(double meters, UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.imperial) {
      final miles = meters / metersPerMile;
      if (miles >= 10) return '${miles.round()}mi';
      return '${miles.toStringAsFixed(1)}mi';
    }
    final km = meters / 1000;
    if (km >= 10) return '${km.round()}km';
    return '${km.toStringAsFixed(1)}km';
  }

  /// "8:30 /mi" or "8:30 /km".
  static String pace(
      int durationSeconds, double distanceMeters, UnitSystem unitSystem) {
    if (distanceMeters <= 0) {
      return unitSystem == UnitSystem.imperial ? '--:-- /mi' : '--:-- /km';
    }
    final double paceSeconds;
    final String label;
    if (unitSystem == UnitSystem.imperial) {
      paceSeconds = durationSeconds / (distanceMeters / metersPerMile);
      label = '/mi';
    } else {
      paceSeconds = durationSeconds / (distanceMeters / 1000);
      label = '/km';
    }
    return '${minSec(paceSeconds.round())} $label';
  }

  /// Bare pace value: "8:30".
  static String paceValue(double paceSeconds) => minSec(paceSeconds.round());

  /// "8.5 mph" or "8.5 km/h".
  static String speed(double speedKmh, UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.imperial) {
      return '${(speedKmh * _kmhToMph).toStringAsFixed(1)} mph';
    }
    return '${speedKmh.toStringAsFixed(1)} km/h';
  }

  /// "1h 02m 30s" or "5m 30s".
  static String duration(int durationSeconds) {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${_pad(minutes)}m ${_pad(seconds)}s';
    }
    return '${minutes}m ${_pad(seconds)}s';
  }

  /// "1h 02m" or "5m 30s".
  static String durationShort(int durationSeconds) {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) return '${hours}h ${_pad(minutes)}m';
    return '${minutes}m ${_pad(seconds)}s';
  }

  /// "2m 30s" or "45s" — for rest intervals.
  static String restDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// "01:02:30" or "05:30" — for timer display.
  static String timerDisplay(Duration d) {
    final safe = d.isNegative ? Duration.zero : d;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);
    if (hours > 0) {
      return '${_pad(hours)}:${_pad(minutes)}:${_pad(seconds)}';
    }
    return '${_pad(minutes)}:${_pad(seconds)}';
  }

  /// "2026-03-04".
  static String dateIso(DateTime dateTime) {
    final d = dateTime.toLocal();
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  }

  /// "March 4, 2026".
  static String dateFull(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// "Today", "Yesterday", or "03/04/2026".
  static String dateRelative(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(local.year, local.month, local.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return '${_pad(local.month)}/${_pad(local.day)}/${local.year}';
  }

  /// "3/4/2026 at 2:30 PM".
  static String dateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} '
        'at $hour:${_pad(local.minute)} $period';
  }

  /// "2:30 PM".
  static String time(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${_pad(local.minute)} $period';
  }

  /// "8:30" — bare m:ss.
  static String minSec(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${_pad(seconds)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
