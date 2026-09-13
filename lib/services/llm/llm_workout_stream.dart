import 'dart:async';
import 'dart:convert';

import 'package:workouts/models/llm_workout_option.dart';

import 'llm_response_parser.dart';

class LlmWorkoutStream({
  required final Stream<String> tokens,
  required final Future<LlmWorkoutResponse> parsed,
}) {
  factory fromTokenDeltas(Stream<String> tokens) {
    final accumulated = StringBuffer();
    final parsedCompleter = Completer<LlmWorkoutResponse>();

    final tokenStream = tokens
        .map((delta) {
          accumulated.write(delta);
          return delta;
        })
        .handleError((Object error) {
          if (!parsedCompleter.isCompleted) {
            parsedCompleter.completeError(error);
          }
        });

    final broadcastTokens = tokenStream.asBroadcastStream(
      onCancel: (subscription) => subscription.cancel(),
    );

    broadcastTokens.drain<void>().then((_) {
      if (parsedCompleter.isCompleted) return;
      try {
        parsedCompleter.complete(
          const LlmResponseParser().parseWorkoutResponse(
            '{"choices":[{"message":{"content":${jsonEncode(accumulated.toString())}}}]}',
          ),
        );
      } catch (error) {
        parsedCompleter.completeError(error);
      }
    });

    return LlmWorkoutStream(
      tokens: broadcastTokens,
      parsed: parsedCompleter.future,
    );
  }
}
