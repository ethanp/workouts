import 'dart:async';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/services/context_builder.dart';
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';

part 'workout_generation_provider.g.dart';

const _log = ELogger('WorkoutGeneration');

sealed class WorkoutGenerationState {}

class GenerationIdle extends WorkoutGenerationState {}

class GenerationStreaming extends WorkoutGenerationState {
  final String partialText;
  GenerationStreaming(this.partialText);
}

class GenerationComplete extends WorkoutGenerationState {
  final LlmWorkoutResponse response;
  GenerationComplete(this.response);
}

class GenerationFailed extends WorkoutGenerationState {
  final Object error;
  GenerationFailed(this.error);
}

class GenerationFollowup extends WorkoutGenerationState {
  final LlmWorkoutResponse response;
  final String partialAnswer;
  final bool answering;
  GenerationFollowup(
    this.response,
    this.partialAnswer, {
    this.answering = true,
  });
}

@riverpod
class WorkoutGenerationNotifier extends _$WorkoutGenerationNotifier {
  http.Client? _activeClient;
  WorkoutPreferences? _lastPreferences;
  StreamSubscription<String>? _tokenSubscription;

  @override
  WorkoutGenerationState build() => GenerationIdle();

  Future<void> generate({WorkoutPreferences? preferences}) {
    _lastPreferences = preferences;
    return _callLlm();
  }

  Future<void> refine(String feedback) => _callLlm(feedback);

  Future<void> askFollowup(String question) async {
    final currentState = state;
    final LlmWorkoutResponse response;
    if (currentState is GenerationComplete) {
      response = currentState.response;
    } else if (currentState is GenerationFollowup) {
      response = currentState.response;
    } else {
      return;
    }

    _tokenSubscription?.cancel();
    _activeClient?.close();
    _activeClient = http.Client();

    _log.log('Asking followup: $question');
    state = GenerationFollowup(response, '', answering: true);

    try {
      final tokenStream = ref
          .read(llmServiceProvider)
          .streamFollowup(
            workoutResponse: response,
            question: question,
            httpClient: _activeClient!,
          );

      final accumulated = StringBuffer();
      final tokenCompleter = Completer<void>();

      _tokenSubscription = tokenStream.listen(
        (delta) {
          accumulated.write(delta);
          state = GenerationFollowup(response, accumulated.toString());
        },
        onError: (Object error) {
          if (!tokenCompleter.isCompleted) tokenCompleter.completeError(error);
        },
        onDone: () {
          if (!tokenCompleter.isCompleted) tokenCompleter.complete();
        },
      );

      await tokenCompleter.future;
      _log.log('Followup answer complete');
      state = GenerationFollowup(
        response,
        accumulated.toString(),
        answering: false,
      );
    } on http.ClientException catch (clientException) {
      _log.log('Followup request cancelled: $clientException');
      state = GenerationComplete(response);
    } catch (error, stackTrace) {
      _log.error('Followup failed: $error', null, stackTrace);
      state = GenerationComplete(response);
    } finally {
      _tokenSubscription = null;
      _activeClient = null;
    }
  }

  void cancel() {
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
    if (_activeClient != null) {
      _log.log('Cancelling LLM request...');
      _activeClient!.close();
      _activeClient = null;
    }
    state = GenerationIdle();
  }

  Future<void> select(LlmWorkoutOption option) async {
    _log.log('Selecting workout option: ${option.title}');
    final template = await ref
        .read(templateRepositoryPowerSyncProvider)
        .createFromLlmOption(option);
    await ref.read(activeSessionProvider.notifier).start(template.id);
    cancel();
  }

  Future<void> _callLlm([String? feedback]) async {
    _tokenSubscription?.cancel();
    _activeClient?.close();
    final client = http.Client();
    _activeClient = client;

    if (feedback == null) {
      _log.log('Starting workout generation...');
    } else {
      _log.log('Refining with feedback: $feedback');
    }

    state = GenerationStreaming('');

    try {
      final workoutContext = await ref.read(contextBuilderProvider).build();
      final contextWithPrefs = WorkoutContext(
        goals: workoutContext.goals,
        backgroundNotes: workoutContext.backgroundNotes,
        recentSessions: workoutContext.recentSessions,
        influences: workoutContext.influences,
        knownExerciseNames: workoutContext.knownExerciseNames,
        preferences: _lastPreferences,
      );

      final (:tokens, :parsed) = ref
          .read(llmServiceProvider)
          .streamWorkoutOptions(
            context: contextWithPrefs,
            userFeedback: feedback,
            httpClient: client,
          );

      // The live token stream only drives the streaming UI. Completion and
      // errors — including the ClientException raised when cancel() closes
      // the connection — are delivered through `parsed`, so awaiting it is
      // the single completion signal. (Coordinating via a subscription
      // completer here would deadlock: cancel() cancels the subscription
      // before onDone/onError can fire, and the parsed error would then go
      // unawaited and surface as an uncaught zone error.)
      final accumulated = StringBuffer();
      _tokenSubscription = tokens.listen(
        (delta) {
          if (!identical(_activeClient, client)) return;
          accumulated.write(delta);
          state = GenerationStreaming(accumulated.toString());
        },
        onError: (_) {},
      );

      final response = await parsed;
      if (!identical(_activeClient, client)) return;
      _log.log('Generated ${response.options.length} workout options');
      state = GenerationComplete(response);
    } on http.ClientException catch (clientException) {
      // A closed connection is expected once this request has been cancelled
      // or superseded; only the still-active request treats it as a failure.
      if (!identical(_activeClient, client)) return;
      _log.error('Workout generation request failed: $clientException');
      state = GenerationFailed(clientException);
    } catch (error, stackTrace) {
      if (!identical(_activeClient, client)) return;
      _log.error(
        'Workout generation notifier failed: $error',
        null,
        stackTrace,
      );
      state = GenerationFailed(error);
    } finally {
      if (identical(_activeClient, client)) {
        _tokenSubscription = null;
        _activeClient = null;
      }
    }
  }
}
