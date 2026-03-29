import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/training_location.dart';
import 'package:workouts/providers/goals_provider.dart';
import 'package:workouts/providers/locations_provider.dart';
import 'package:workouts/providers/workout_generation_provider.dart';
import 'package:workouts/services/context_builder.dart';
import 'package:workouts/services/llm_service.dart';
import 'package:workouts/theme/app_theme.dart';

class WorkoutOptionsSheet extends ConsumerStatefulWidget {
  const WorkoutOptionsSheet({super.key});

  static Future<LlmWorkoutOption?> show(BuildContext context) {
    return showCupertinoModalPopup<LlmWorkoutOption>(
      context: context,
      builder: (_) => const WorkoutOptionsSheet(),
    );
  }

  @override
  ConsumerState<WorkoutOptionsSheet> createState() =>
      _WorkoutOptionsSheetState();
}

class _WorkoutOptionsSheetState extends ConsumerState<WorkoutOptionsSheet> {
  final _feedbackController = TextEditingController();
  String? _expandedOptionId;
  bool _showingForm = true;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(workoutGenerationProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _showingForm
                ? _WorkoutPreferencesForm(
                    onSubmit: _onFormSubmit,
                  )
                : generationState.when(
                    data: (response) => response == null
                        ? const _InitialView()
                        : _buildOptionsView(response),
                    loading: () => const _LoadingView(),
                    error: (error, _) => _buildErrorView(error),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderDepth1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              ref.read(workoutGenerationProvider.notifier).cancel();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          const Text('Generate Workout', style: AppTypography.title),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  void _onFormSubmit(WorkoutPreferences preferences) {
    setState(() => _showingForm = false);
    ref.read(workoutGenerationProvider.notifier).generate(
          preferences: preferences,
        );
  }

  Widget _buildOptionsView(LlmWorkoutResponse response) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDepth1),
          ),
          child: Text(
            response.explanation,
            style: AppTypography.body.copyWith(
              color: AppColors.textColor2,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        ...response.options.map(
          (option) => _WorkoutOptionCard(
            option: option,
            isExpanded: _expandedOptionId == option.id,
            onTap: () => setState(() {
              _expandedOptionId =
                  _expandedOptionId == option.id ? null : option.id;
            }),
            onSelect: () => _selectOption(option),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildRefinementSection(),
      ],
    );
  }

  Widget _buildRefinementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Not quite right?', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.sm),
        CupertinoTextField(
          controller: _feedbackController,
          placeholder: 'Tell me what to change...',
          placeholderStyle: AppTypography.body.copyWith(
            color: AppColors.textColor3,
          ),
          style: AppTypography.body,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDepth1),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: AppColors.backgroundDepth3,
            onPressed: _feedbackController.text.isEmpty
                ? null
                : () => _refine(_feedbackController.text),
            child: const Text('Refine'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(Object error) {
    final message = switch (error) {
      RateLimitedException limitedError => limitedError.toString(),
      LlmException llmError => llmError.message,
      _ => 'Something went wrong. Please try again.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: AppColors.textColor3,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            CupertinoButton.filled(
              onPressed: () =>
                  ref.read(workoutGenerationProvider.notifier).generate(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectOption(LlmWorkoutOption option) {
    Navigator.of(context).pop(option);
  }

  void _refine(String feedback) {
    _feedbackController.clear();
    ref.read(workoutGenerationProvider.notifier).refine(feedback);
  }
}

const _durationPresets = [5, 10, 15, 30, 45, 60];

class _WorkoutPreferencesForm extends ConsumerStatefulWidget {
  const _WorkoutPreferencesForm({required this.onSubmit});

  final ValueChanged<WorkoutPreferences> onSubmit;

  @override
  ConsumerState<_WorkoutPreferencesForm> createState() =>
      _WorkoutPreferencesFormState();
}

class _WorkoutPreferencesFormState
    extends ConsumerState<_WorkoutPreferencesForm> {
  int? _selectedDuration;
  final Set<String> _selectedGoalIds = {};
  String? _selectedLocationId;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _sectionLabel('Duration'),
        _durationChips(),
        const SizedBox(height: AppSpacing.xl),
        _sectionLabel('Focus Areas'),
        _goalChips(),
        const SizedBox(height: AppSpacing.xl),
        _sectionLabel('Location'),
        _locationSelector(),
        const SizedBox(height: AppSpacing.xl),
        _sectionLabel('Notes'),
        _notesField(),
        const SizedBox(height: AppSpacing.xl),
        _generateButton(),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textColor3,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _durationChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _durationPresets.map((minutes) {
        final isSelected = _selectedDuration == minutes;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedDuration = isSelected ? null : minutes;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.backgroundDepth2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.borderDepth1,
              ),
            ),
            child: Text(
              '$minutes min',
              style: AppTypography.body.copyWith(
                color: isSelected
                    ? CupertinoColors.white
                    : AppColors.textColor2,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _goalChips() {
    final goalsAsync = ref.watch(activeGoalsStreamProvider);

    return goalsAsync.when(
      data: (activeGoals) {
        if (activeGoals.isEmpty) {
          return Text(
            'No active goals. Add goals in the Library.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          );
        }
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: activeGoals.map((goal) {
            final isSelected = _selectedGoalIds.contains(goal.id);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selectedGoalIds.remove(goal.id);
                } else {
                  _selectedGoalIds.add(goal.id);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.backgroundDepth2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.borderDepth1,
                  ),
                ),
                child: Text(
                  goal.title,
                  style: AppTypography.body.copyWith(
                    color: isSelected
                        ? CupertinoColors.white
                        : AppColors.textColor2,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const CupertinoActivityIndicator(),
      error: (_, __) => Text(
        'Could not load goals.',
        style: AppTypography.body.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _locationSelector() {
    final locationsAsync = ref.watch(locationsProvider);

    return locationsAsync.when(
      data: (savedLocations) {
        if (savedLocations.isEmpty) {
          return Text(
            'No locations saved. Add locations in the Library.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          );
        }
        return Column(
          children: savedLocations.map((location) {
            final isSelected = _selectedLocationId == location.id;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedLocationId = isSelected ? null : location.id;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary.withValues(alpha: 0.12)
                      : AppColors.backgroundDepth2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.borderDepth1,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      size: 20,
                      color: isSelected
                          ? AppColors.accentPrimary
                          : AppColors.textColor3,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textColor1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (location.equipment.isNotEmpty)
                            Text(
                              location.equipment,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textColor3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const CupertinoActivityIndicator(),
      error: (_, __) => Text(
        'Could not load locations.',
        style: AppTypography.body.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _notesField() {
    return CupertinoTextField(
      controller: _notesController,
      placeholder: 'Anything else? e.g., "I\'m feeling tired", "skip legs"',
      placeholderStyle:
          AppTypography.body.copyWith(color: AppColors.textColor4),
      style: AppTypography.body.copyWith(color: AppColors.textColor1),
      padding: const EdgeInsets.all(AppSpacing.md),
      maxLines: 3,
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
    );
  }

  Widget _generateButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: _submit,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.sparkles, size: 18),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Generate',
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final goalsAsync = ref.read(activeGoalsStreamProvider);
    final locationsAsync = ref.read(locationsProvider);

    final allGoals = goalsAsync.value ?? [];
    final focusGoals = allGoals
        .where((goal) => _selectedGoalIds.contains(goal.id))
        .toList();

    final allLocations = locationsAsync.value ?? [];
    TrainingLocation? selectedLocation;
    if (_selectedLocationId != null) {
      selectedLocation = allLocations
          .where((location) => location.id == _selectedLocationId)
          .firstOrNull;
    }

    final notes = _notesController.text.trim();

    widget.onSubmit(
      WorkoutPreferences(
        durationMinutes: _selectedDuration,
        focusGoals: focusGoals,
        location: selectedLocation,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
}

class _InitialView extends StatelessWidget {
  const _InitialView();

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Text('Preparing...', style: AppTypography.body));
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CupertinoActivityIndicator(radius: 20),
          SizedBox(height: AppSpacing.lg),
          Text('Thinking about your training...', style: AppTypography.body),
        ],
      ),
    );
  }
}

class _WorkoutOptionCard extends StatelessWidget {
  const _WorkoutOptionCard({
    required this.option,
    required this.isExpanded,
    required this.onTap,
    required this.onSelect,
  });

  final LlmWorkoutOption option;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildHeader(), if (isExpanded) _buildExpandedContent()],
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleRow(),
            const SizedBox(height: AppSpacing.sm),
            _buildRationale(),
            const SizedBox(height: AppSpacing.sm),
            _buildExpandToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(option.title, style: AppTypography.subtitle)),
        Row(
          children: [
            _buildGoalBadge(),
            const SizedBox(width: AppSpacing.xs),
            _buildTimeBadge(),
          ],
        ),
      ],
    );
  }

  Widget _buildRationale() {
    return Text(
      option.rationale,
      style: AppTypography.body.copyWith(color: AppColors.textColor2),
    );
  }

  Widget _buildExpandToggle() {
    return Row(
      children: [
        Icon(
          isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
          size: 16,
          color: AppColors.textColor3,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          isExpanded ? 'Hide exercises' : 'Show exercises',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
      ],
    );
  }

  Widget _buildExpandedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: AppColors.borderDepth1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...option.blocks.map((block) => _BlockSection(block: block)),
              const SizedBox(height: AppSpacing.md),
              _buildStartButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: onSelect,
        child: const Text('Start This Workout'),
      ),
    );
  }

  Widget _buildGoalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Text(
        option.goal.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTimeBadge() {
    final totalMinutes = option.blocks.fold<int>(
      0,
      (sum, block) => sum + block.estimatedMinutes,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text('${totalMinutes}m', style: AppTypography.caption),
    );
  }
}

class _BlockSection extends StatelessWidget {
  const _BlockSection({required this.block});

  final LlmWorkoutBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Text(
                block.title,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${block.estimatedMinutes}m',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor3,
                ),
              ),
            ],
          ),
        ),
        if (block.description != null && block.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              block.description!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor2,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ...block.exercises.map((exercise) => _ExerciseRow(exercise: exercise)),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final LlmExercise exercise;

  @override
  Widget build(BuildContext context) {
    final prescription = [
      if (exercise.sets != null) '${exercise.sets} sets',
      if (exercise.reps != null) '${exercise.reps} reps',
      if (exercise.duration != null) exercise.duration,
    ].join(' x ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(exercise.name, style: AppTypography.body)),
          Text(
            prescription,
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
        ],
      ),
    );
  }
}
