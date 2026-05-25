import 'dart:convert';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workouts/features/active_session/exercise_timer_panel.dart';

const _log = ELogger('ActiveTimerStore');
const _prefsKey = 'active_interval_timer';

/// Identifies which exercise card a persisted timer record belongs to.
/// Encoded into the store record on write and compared on restore.
class TimerIdentity {
  const TimerIdentity({
    required this.sessionId,
    required this.blockId,
    required this.exerciseId,
  });

  final String sessionId;
  final String blockId;
  final String exerciseId;

  bool matches(ActiveTimerRecord record) =>
      record.sessionId == sessionId &&
      record.blockId == blockId &&
      record.exerciseId == exerciseId;

  @override
  bool operator ==(Object other) =>
      other is TimerIdentity &&
      other.sessionId == sessionId &&
      other.blockId == blockId &&
      other.exerciseId == exerciseId;

  @override
  int get hashCode => Object.hash(sessionId, blockId, exerciseId);
}

/// Immutable snapshot of a single running or paused interval timer that
/// outlives the widget's lifetime. Exactly one of [endsAt] /
/// [pausedRemaining] should be populated:
/// - while running, [endsAt] is the wall-clock instant the phase ends
/// - while paused, [pausedRemaining] is what was left at pause time
class ActiveTimerRecord {
  const ActiveTimerRecord({
    required this.sessionId,
    required this.blockId,
    required this.exerciseId,
    required this.phase,
    this.endsAt,
    this.pausedRemaining,
  });

  final String sessionId;
  final String blockId;
  final String exerciseId;
  final TimerPhase phase;
  final DateTime? endsAt;
  final Duration? pausedRemaining;

  bool get isPaused => pausedRemaining != null;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'blockId': blockId,
        'exerciseId': exerciseId,
        'phase': phase.name,
        if (endsAt != null) 'endsAtIso': endsAt!.toIso8601String(),
        if (pausedRemaining != null)
          'pausedRemainingMs': pausedRemaining!.inMilliseconds,
      };

  static ActiveTimerRecord? tryFromJson(Map<String, dynamic> json) {
    try {
      final phaseName = json['phase'] as String?;
      final phase = TimerPhase.values.firstWhere(
        (timerPhase) => timerPhase.name == phaseName,
        orElse: () => TimerPhase.idle,
      );
      final endsAtRaw = json['endsAtIso'] as String?;
      final pausedRaw = json['pausedRemainingMs'] as int?;
      return ActiveTimerRecord(
        sessionId: json['sessionId'] as String,
        blockId: json['blockId'] as String,
        exerciseId: json['exerciseId'] as String,
        phase: phase,
        endsAt: endsAtRaw == null ? null : DateTime.parse(endsAtRaw),
        pausedRemaining: pausedRaw == null
            ? null
            : Duration(milliseconds: pausedRaw),
      );
    } catch (error, stackTrace) {
      _log.error('Failed to decode timer record', error, stackTrace);
      return null;
    }
  }
}

/// Tiny synchronous wrapper around [SharedPreferences] that holds the
/// single active interval-timer record. Synchronous reads matter because
/// `ExerciseIntervalTimer.initState` needs to know within the same frame
/// whether a quit-survived timer should be restored — async would force
/// a flicker through `idle` first.
class ActiveTimerStore {
  ActiveTimerStore(this._prefs);

  final SharedPreferences _prefs;

  ActiveTimerRecord? read() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return ActiveTimerRecord.tryFromJson(decoded);
    } catch (error, stackTrace) {
      _log.error('Failed to read timer record', error, stackTrace);
      return null;
    }
  }

  Future<void> write(ActiveTimerRecord record) async {
    try {
      await _prefs.setString(_prefsKey, jsonEncode(record.toJson()));
    } catch (error, stackTrace) {
      _log.error('Failed to write timer record', error, stackTrace);
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.remove(_prefsKey);
    } catch (error, stackTrace) {
      _log.error('Failed to clear timer record', error, stackTrace);
    }
  }
}
