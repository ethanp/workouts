import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/models/exercise_replacement_suggestion.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/llm/llm_service.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';

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
        data: (exercises) => _ReplacePickerBody(
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

class const _ReplacePickerBody({
  required final WorkoutExercise originalExercise,
  required final Set<String> excludeIds,
  required final List<WorkoutExercise> libraryExercises,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ReplacePickerBody> createState() => _ReplacePickerBodyState();
}

class _ReplacePickerBodyState() extends ConsumerState<_ReplacePickerBody> {
  ExerciseModality? _selectedModality;
  List<ExerciseReplacementSuggestion>? _suggestions;
  bool _isLoadingSuggestions = false;
  Object? _suggestionsError;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _filterChips(),
          Expanded(child: _scrollableBody()),
        ],
      ),
    );
  }

  Widget _scrollableBody() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ConnectionGatedWidget(child: _aiSuggestionsSection()),
        ..._libraryListItems(),
      ],
    );
  }

  Widget _aiSuggestionsSection() {
    if (_isLoadingSuggestions) return _suggestionsLoading();
    if (_suggestionsError != null) {
      return _suggestionsErrorBanner(_suggestionsError!);
    }
    final suggestions = _suggestions;
    if (suggestions == null) return _suggestPromptButton();
    if (suggestions.isEmpty) return _suggestionsEmptyBanner();
    return _suggestionsList(suggestions);
  }

  Widget _suggestPromptButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceSm,
      ),
      child: InkWell(
        onTap: _loadSuggestions,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: ELayout.spaceMd,
            horizontal: ELayout.spaceLg,
          ),
          decoration: BoxDecoration(
            color: EColors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(ELayout.radiusMd),
            border: Border.all(color: EColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: EColors.warning),
              const SizedBox(width: ELayout.spaceSm),
              Text(
                'Suggest similar exercises',
                style: EText.body.medium.copyWith(
                  color: EColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionsLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceSm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: ELayout.spaceMd,
          horizontal: ELayout.spaceLg,
        ),
        decoration: BoxDecoration(
          color: EColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(color: EColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: ELayout.spaceMd),
            Expanded(
              child: Text(
                'Finding alternatives…',
                style: EText.body.medium.copyWith(color: EColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionsErrorBanner(Object error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(ELayout.spaceMd),
            decoration: BoxDecoration(
              color: EColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ELayout.radiusMd),
            ),
            child: Text(
              'Suggestions failed: $error',
              style: EText.caption.copyWith(color: EColors.danger),
            ),
          ),
          const SizedBox(height: ELayout.spaceSm),
          TextButton(
            onPressed: _loadSuggestions,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _suggestionsEmptyBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceSm,
      ),
      child: Container(
        padding: const EdgeInsets.all(ELayout.spaceMd),
        decoration: BoxDecoration(
          color: EColors.backgroundLift,
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(color: EColors.border),
        ),
        child: Text(
          'No AI suggestions found. Pick from the library below.',
          style: EText.caption.copyWith(color: EColors.textTertiary),
        ),
      ),
    );
  }

  Widget _suggestionsList(List<ExerciseReplacementSuggestion> suggestions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('AI SUGGESTIONS'),
        ...suggestions.map(_suggestionRow),
      ],
    );
  }

  Widget _suggestionRow(ExerciseReplacementSuggestion suggestion) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EColors.border)),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(suggestion.exercise),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceLg,
            vertical: ELayout.spaceMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: EColors.warning,
                ),
              ),
              const SizedBox(width: ELayout.spaceMd),
              Expanded(child: _suggestionDetails(suggestion)),
              const SizedBox(width: ELayout.spaceSm),
              const Icon(
                Icons.add_circle_outline,
                color: EColors.accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionDetails(ExerciseReplacementSuggestion suggestion) {
    final exercise = suggestion.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                exercise.name,
                style: EText.body.medium.copyWith(color: EColors.textPrimary),
              ),
            ),
            if (!suggestion.isFromLibrary) _newBadge(),
          ],
        ),
        if (suggestion.reason.isNotEmpty) ...[
          const SizedBox(height: ELayout.spaceXs),
          Text(
            suggestion.reason,
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
        ],
        const SizedBox(height: ELayout.spaceXs),
        _exerciseBadges(exercise),
      ],
    );
  }

  Widget _newBadge() => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: ELayout.spaceSm,
      vertical: ELayout.spaceXs,
    ),
    decoration: BoxDecoration(
      color: EColors.accent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(ELayout.radiusSm),
    ),
    child: Text(
      'NEW',
      style: EText.caption.copyWith(
        color: EColors.accent,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  );

  List<Widget> _libraryListItems() {
    final groups = _groupedFilteredLibrary();
    if (groups.isEmpty) {
      return [
        _sectionHeader('LIBRARY'),
        Padding(
          padding: const EdgeInsets.all(ELayout.spaceLg),
          child: Center(
            child: Text(
              'No exercises available',
              style: EText.body.medium.copyWith(color: EColors.textTertiary),
            ),
          ),
        ),
      ];
    }

    final modalities = groups.keys.toList().sortedOn(
      (modality) => modality.name,
    );

    return [
      _sectionHeader('LIBRARY'),
      for (final modality in modalities)
        _modalitySection(modality, groups[modality]!),
    ];
  }

  Widget _filterChips() {
    final modalities = _availableLibraryModalities().toList().sortedOn(
      (modality) => modality.name,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceLg,
        vertical: ELayout.spaceMd,
      ),
      child: Row(
        children: [
          _filterChip(null, 'All'),
          ...modalities.map(
            (modality) => _filterChip(modality, modality.name.toUpperCase()),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ExerciseModality? modality, String label) {
    final isSelected = _selectedModality == modality;
    return Padding(
      padding: const EdgeInsets.only(right: ELayout.spaceSm),
      child: InkWell(
        onTap: () => setState(() => _selectedModality = modality),
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceMd,
            vertical: ELayout.spaceSm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? EColors.accent : EColors.surface,
            borderRadius: BorderRadius.circular(ELayout.radiusMd),
          ),
          child: Text(
            label,
            style: EText.caption.copyWith(
              color: isSelected ? EColors.textPrimary : EColors.textTertiary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _modalitySection(
    ExerciseModality modality,
    List<WorkoutExercise> exercises,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ELayout.spaceLg,
            ELayout.spaceMd,
            ELayout.spaceLg,
            ELayout.spaceSm,
          ),
          child: Text(
            modality.name.toUpperCase(),
            style: EText.caption.copyWith(
              color: EColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...exercises.map(_libraryRow),
      ],
    );
  }

  Widget _libraryRow(WorkoutExercise exercise) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EColors.border)),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(exercise),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceLg,
            vertical: ELayout.spaceMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: EText.body.medium.copyWith(
                        color: EColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: ELayout.spaceXs),
                    _exerciseBadges(exercise),
                  ],
                ),
              ),
              const Icon(
                Icons.add_circle_outline,
                color: EColors.accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exerciseBadges(WorkoutExercise exercise) {
    return Wrap(
      spacing: ELayout.spaceSm,
      runSpacing: ELayout.spaceXs,
      children: [
        _modalityBadge(exercise.modality),
        if (exercise.equipment != null && exercise.equipment!.isNotEmpty)
          _equipmentBadge(exercise.equipment!),
      ],
    );
  }

  Widget _modalityBadge(ExerciseModality modality) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        modality.name,
        style: EText.caption.copyWith(
          color: EColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _equipmentBadge(String equipment) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: EColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_in_ar, size: 12, color: EColors.warning),
          const SizedBox(width: ELayout.spaceXs),
          Text(
            equipment,
            style: EText.caption.copyWith(color: EColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceXs,
      ),
      child: Text(
        label,
        style: EText.caption.copyWith(
          color: EColors.textMuted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  List<WorkoutExercise> _filteredLibrary() {
    final available = widget.libraryExercises.whereL(
      (exercise) => !widget.excludeIds.contains(exercise.id),
    );
    if (_selectedModality == null) return available;
    return available.whereL(
      (exercise) => exercise.modality == _selectedModality,
    );
  }

  Set<ExerciseModality> _availableLibraryModalities() {
    return widget.libraryExercises
        .where((exercise) => !widget.excludeIds.contains(exercise.id))
        .map((exercise) => exercise.modality)
        .toSet();
  }

  Map<ExerciseModality, List<WorkoutExercise>> _groupedFilteredLibrary() {
    final grouped = <ExerciseModality, List<WorkoutExercise>>{};
    for (final exercise in _filteredLibrary()) {
      grouped.putIfAbsent(exercise.modality, () => []).add(exercise);
    }
    return grouped;
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
