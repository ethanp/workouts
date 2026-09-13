import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/models/cardio_workout_event.dart';

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
        return 'Paused at ${pause.occurredAt.clockTime}';
      }
      return 'Paused ${pausedFor.formattedMinutesOrSeconds} at ${pause.occurredAt.clockTime}';
    }
    final endedAt = pause.endedAt;
    if (endedAt != null && endedAt.isAfter(pause.occurredAt)) {
      return 'Paused ${endedAt.difference(pause.occurredAt).formattedMinutesOrSeconds} '
          'at ${pause.occurredAt.clockTime}';
    }
    return 'Paused at ${pause.occurredAt.clockTime}';
  }

  static String _otherCaption(CardioWorkoutEvent event) {
    final endedAt = event.endedAt;
    if (endedAt != null && endedAt.isAfter(event.occurredAt)) {
      return '${event.eventType.camelToTitleCase} · '
          '${event.occurredAt.clockTime}–${endedAt.clockTime}';
    }
    return '${event.eventType.camelToTitleCase} at ${event.occurredAt.clockTime}';
  }
}
