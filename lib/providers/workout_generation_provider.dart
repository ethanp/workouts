import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/services/context_builder.dart';
import 'package:workouts/services/llm_service.dart';

part 'workout_generation_provider.g.dart';

final _log = Logger('WorkoutGeneration');

@riverpod
class WorkoutGenerationNotifier extends _$WorkoutGenerationNotifier {
  @override
  AsyncValue<LlmWorkoutResponse?> build() => const AsyncValue.data(null);

  Future<void> generate() => _callLlm();

  Future<void> refine(String feedback) => _callLlm(feedback);

  void clear() => state = const AsyncValue.data(null);

  Future<void> _callLlm([String? feedback]) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (feedback == null) {
        _log.info('Starting workout generation...');
      } else {
        _log.info('Refining with feedback: $feedback');
      }
      final context = await ref.read(contextBuilderProvider).build();
      final response = await ref
          .read(llmServiceProvider)
          .generateWorkoutOptions(context: context, userFeedback: feedback);
      _log.info('Generated ${response.options.length} workout options');
      return response;
    });
  }
}
