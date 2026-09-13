import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/models/cardio_workout_event.dart';
import 'package:workouts/utils/run_formatting.dart';

class const CardioSessionStructure({required final List<String> captions}) {
  factory fromEvents(List<CardioWorkoutEvent> events) {
    if (events.isEmpty) return const CardioSessionStructure(captions: []);
    final sortedEvents = [...events]
      ..sort(
        (firstEvent, secondEvent) =>
            firstEvent.occurredAt.compareTo(secondEvent.occurredAt),
      );
    final captions = <String>[];
    final consumedResumeIndexes = <int>{};
    for (var eventIndex = 0; eventIndex < sortedEvents.length; eventIndex++) {
      final event = sortedEvents[eventIndex];
      if (event.eventType == 'resume' &&
          consumedResumeIndexes.contains(eventIndex)) {
        continue;
      }
      if (event.eventType == 'pause') {
        captions.add(_pauseCaption(sortedEvents, eventIndex, consumedResumeIndexes));
        continue;
      }
      if (event.eventType == 'resume') continue;
      captions.add(_otherCaption(event));
    }
    return CardioSessionStructure(captions: captions);
  }

  bool get isEmpty => captions.isEmpty;

  static String _pauseCaption(
    List<CardioWorkoutEvent> sortedEvents,
    int pauseIndex,
    Set<int> consumedResumeIndexes,
  ) {
    final pause = sortedEvents[pauseIndex];
    for (
      var resumeIndex = pauseIndex + 1;
      resumeIndex < sortedEvents.length;
      resumeIndex++
    ) {
      if (sortedEvents[resumeIndex].eventType != 'resume') continue;
      consumedResumeIndexes.add(resumeIndex);
      final pausedFor = sortedEvents[resumeIndex].occurredAt.difference(
        pause.occurredAt,
      );
      if (pausedFor.inSeconds <= 0) {
        return 'Paused at ${Format.time(pause.occurredAt)}';
      }
      return 'Paused ${Format.restDuration(pausedFor)} at ${Format.time(pause.occurredAt)}';
    }
    final endedAt = pause.endedAt;
    if (endedAt != null && endedAt.isAfter(pause.occurredAt)) {
      return 'Paused ${Format.restDuration(endedAt.difference(pause.occurredAt))} '
          'at ${Format.time(pause.occurredAt)}';
    }
    return 'Paused at ${Format.time(pause.occurredAt)}';
  }

  static String _otherCaption(CardioWorkoutEvent event) {
    final endedAt = event.endedAt;
    if (endedAt != null && endedAt.isAfter(event.occurredAt)) {
      return '${event.eventType.camelToTitleCase} · '
          '${Format.time(event.occurredAt)}–${Format.time(endedAt)}';
    }
    return '${event.eventType.camelToTitleCase} at ${Format.time(event.occurredAt)}';
  }
}
