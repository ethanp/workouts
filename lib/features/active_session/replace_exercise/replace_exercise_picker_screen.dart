import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/models/exercise_replacement_suggestion.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';

import 'replace_exercise_library_list.dart';
import 'replace_exercise_suggestions.dart';

/// Modal selector used during a session to swap an exercise. Surfaces an AI
/// "Suggest similar exercises" affordance above a modality-filtered library
/// list. Returns the chosen [WorkoutExercise] via `Navigator.pop`. The caller
/// cannot tell whether the result came from the library or was an AI-proposed
/// new movement — that detail belongs to the picker.
class const ReplaceExercisePickerScreen({
  required final WorkoutExercise originalExercise,
  required final Set<String> excludeIds,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(allExercisesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _appHeader(context),
      body: exercisesAsync.when(
        data: (exercises) => ReplaceExercisePickerBody(
          originalExercise: originalExercise,
          excludeIds: excludeIds,
          libraryExercises: exercises,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error: $error',
            style: EText.body.medium.copyWith(color: EColors.textTertiary),
          ),
        ),
      ),
    );
  }

  EAppHeader _appHeader(BuildContext context) {
    return EAppHeader(
      title: 'Replace ${originalExercise.name}',
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Close',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
    );
  }
}

class const ReplaceExercisePickerBody({
  required final WorkoutExercise originalExercise,
  required final Set<String> excludeIds,
  required final List<WorkoutExercise> libraryExercises,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<ReplaceExercisePickerBody> createState() =>
      _ReplaceExercisePickerBodyState();
}

class _ReplaceExercisePickerBodyState()
    extends ConsumerState<ReplaceExercisePickerBody> {
  ExerciseModality? _selectedModality;
  List<ExerciseReplacementSuggestion>? _suggestions;
  bool _isLoadingSuggestions = false;
  Object? _suggestionsError;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          ReplaceExerciseModalityFilters(
            libraryExercises: widget.libraryExercises,
            excludeIds: widget.excludeIds,
            selectedModality: _selectedModality,
            onModalitySelected: (modality) {
              setState(() => _selectedModality = modality);
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                ConnectionGatedWidget(
                  child: ReplaceExerciseSuggestions(
                    suggestions: _suggestions,
                    isLoading: _isLoadingSuggestions,
                    error: _suggestionsError,
                    onLoadSuggestions: _loadSuggestions,
                    onSuggestionSelected: (suggestion) {
                      Navigator.of(context).pop(suggestion.exercise);
                    },
                  ),
                ),
                ReplaceExerciseLibraryList(
                  libraryExercises: widget.libraryExercises,
                  excludeIds: widget.excludeIds,
                  selectedModality: _selectedModality,
                  onExerciseSelected: (exercise) {
                    Navigator.of(context).pop(exercise);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoadingSuggestions = true;
      _suggestionsError = null;
    });

    final llmService = ref.read(llmServiceProvider);
    final activeGoals = ref.read(activeGoalsStreamProvider).value ?? const [];

    try {
      final suggestions = await llmService.suggestExerciseReplacements(
        originalExercise: widget.originalExercise,
        activeGoals: activeGoals,
        libraryExercises: widget.libraryExercises,
        excludeIds: widget.excludeIds,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _suggestionsError = error;
        _isLoadingSuggestions = false;
      });
    }
  }
}
