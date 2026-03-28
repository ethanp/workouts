import 'package:ethan_utils/ethan_utils.dart';
import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/services/context_builder.dart';
import 'package:workouts/services/llm_service.dart';
import 'package:workouts/services/repositories/template_repository_powersync.dart';

part 'workout_generation_provider.g.dart';

const _log = ELogger('WorkoutGeneration');

@riverpod
class WorkoutGenerationNotifier extends _$WorkoutGenerationNotifier {
  http.Client? _activeClient;

  @override
  AsyncValue<LlmWorkoutResponse?> build() => const AsyncValue.data(null);

  Future<void> generate() => _callLlm();

  Future<void> refine(String feedback) => _callLlm(feedback);

  void cancel() {
    if (_activeClient != null) {
      _log.log('Cancelling LLM request...');
      _activeClient!.close();
      _activeClient = null;
    }
    state = const AsyncValue.data(null);
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
    // Cancel any existing request
    _activeClient?.close();
    _activeClient = http.Client();

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        if (feedback == null) {
          _log.log('Starting workout generation...');
        } else {
          _log.log('Refining with feedback: $feedback');
        }
        final context = await ref.read(contextBuilderProvider).build();
        final response = await ref
            .read(llmServiceProvider)
            .generateWorkoutOptions(
              context: context,
              userFeedback: feedback,
              client: _activeClient,
            );
        _log.log('Generated ${response.options.length} workout options');
        return response;
      } on http.ClientException catch (clientException) {
        // Request was cancelled
        _log.log('LLM request cancelled: $clientException');
        rethrow;
      } catch (error, stackTrace) {
        _log.error('Workout generation notifier failed: $error', null, stackTrace);
        rethrow;
      } finally {
        _activeClient = null;
      }
    });
  }
}
