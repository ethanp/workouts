import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/providers/workout_generation_provider.dart';
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

  @override
  void initState() {
    super.initState();
    // Start generation when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workoutGenerationProvider.notifier).generate();
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutGenerationProvider);

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
            child: state.when(
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
              ref.read(workoutGenerationProvider.notifier).clear();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          const Text('Generate Workout', style: AppTypography.title),
          const SizedBox(width: 60), // Balance the header
        ],
      ),
    );
  }

  Widget _buildOptionsView(LlmWorkoutResponse response) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Explanation
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

        // Options
        ...response.options.map(
          (option) => _WorkoutOptionCard(
            option: option,
            isExpanded: _expandedOptionId == option.id,
            onTap: () => setState(() {
              _expandedOptionId = _expandedOptionId == option.id
                  ? null
                  : option.id;
            }),
            onSelect: () => _selectOption(option),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Refinement section
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
      RateLimitedException e => e.toString(),
      LlmException e => e.message,
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
            _regenerateSuggestionsButton(),
          ],
        ),
      ),
    );
  }

  Widget _regenerateSuggestionsButton() {
    return CupertinoButton.filled(
      onPressed: () {
        ref.read(workoutGenerationProvider.notifier).generate();
      },
      child: const Text('Try Again'),
    );
  }

  void _selectOption(LlmWorkoutOption option) {
    ref.read(workoutGenerationProvider.notifier).clear();
    Navigator.of(context).pop(option);
  }

  void _refine(String feedback) {
    _feedbackController.clear();
    ref.read(workoutGenerationProvider.notifier).refine(feedback);
  }
}

class _InitialView extends StatelessWidget {
  const _InitialView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Preparing...', style: AppTypography.body));
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
        children: [
          // Header (always visible)
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          option.title,
                          style: AppTypography.subtitle,
                        ),
                      ),
                      estimatedTime(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    option.rationale,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textColor2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  toggleExpanded(),
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            Container(height: 1, color: AppColors.borderDepth1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...option.exercises.map(
                    (exercise) => _ExerciseRow(exercise: exercise),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: onSelect,
                      child: const Text('Start This Workout'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Row toggleExpanded() {
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

  Widget estimatedTime() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text('${option.estimatedMinutes}m', style: AppTypography.caption),
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
