import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/workout_generation/workout_generation_provider.dart';
import 'package:workouts/features/workout_generation/workout_generation_status_views.dart';
import 'package:workouts/features/workout_generation/workout_option_card.dart';
import 'package:workouts/features/workout_generation/workout_preferences_form.dart';
import 'package:workouts/models/llm_workout_option.dart';
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

enum _RefinementMode { refine, ask }

class _WorkoutOptionsSheetState extends ConsumerState<WorkoutOptionsSheet> {
  final _feedbackController = TextEditingController();
  String? _expandedOptionId;
  bool _showingForm = true;
  _RefinementMode _refinementMode = _RefinementMode.refine;

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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        children: [
          _header(),
          Expanded(
            child: _showingForm
                ? WorkoutPreferencesForm(onSubmit: _onFormSubmit)
                : switch (generationState) {
                    GenerationIdle() =>
                      const WorkoutGenerationPreparingView(),
                    GenerationStreaming(:final partialText) =>
                      WorkoutGenerationStreamingView(partialText: partialText),
                    GenerationComplete(:final response) =>
                      _optionsView(response),
                    GenerationFollowup(
                      :final response,
                      :final partialAnswer,
                      :final answering,
                    ) =>
                      _followupView(response, partialAnswer, answering),
                    GenerationFailed(:final error) => _errorView(error),
                  },
          ),
        ],
      ),
    );
  }

  Widget _header() {
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

  Widget _optionsView(LlmWorkoutResponse response, {String? followupAnswer}) {
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
          (option) => WorkoutOptionCard(
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
        _refinementSection(followupAnswer: followupAnswer),
      ],
    );
  }

  Widget _refinementSection({String? followupAnswer}) {
    final isAskMode = _refinementMode == _RefinementMode.ask;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<_RefinementMode>(
            groupValue: _refinementMode,
            onValueChanged: (mode) {
              if (mode != null) {
                setState(() => _refinementMode = mode);
                _feedbackController.clear();
              }
            },
            children: const {
              _RefinementMode.refine: Text('Refine'),
              _RefinementMode.ask: Text('Ask'),
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (followupAnswer != null && followupAnswer.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundDepth2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDepth1),
            ),
            child: Text(
              followupAnswer,
              style: AppTypography.body.copyWith(color: AppColors.textColor2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        CupertinoTextField(
          controller: _feedbackController,
          placeholder: isAskMode
              ? 'Ask about this workout...'
              : 'Tell me what to change...',
          placeholderStyle:
              AppTypography.body.copyWith(color: AppColors.textColor3),
          style: AppTypography.body,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDepth1),
          ),
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: AppColors.backgroundDepth3,
            onPressed: _feedbackController.text.isEmpty
                ? null
                : isAskMode
                    ? () => _askFollowup(_feedbackController.text)
                    : () => _refine(_feedbackController.text),
            child: Text(isAskMode ? 'Ask' : 'Refine'),
          ),
        ),
      ],
    );
  }

  Widget _errorView(Object error) {
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
            Text(message, style: AppTypography.body, textAlign: TextAlign.center),
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

  Widget _followupView(
    LlmWorkoutResponse response,
    String partialAnswer,
    bool answering,
  ) {
    if (answering) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ...response.options.map(
            (option) => WorkoutOptionCard(
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
          if (partialAnswer.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundDepth2,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderDepth1),
              ),
              child: Text(
                partialAnswer,
                style: AppTypography.body.copyWith(color: AppColors.textColor2),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          const Center(child: CupertinoActivityIndicator()),
        ],
      );
    }

    return _optionsView(response, followupAnswer: partialAnswer);
  }

  void _selectOption(LlmWorkoutOption option) {
    Navigator.of(context).pop(option);
  }

  void _refine(String feedback) {
    _feedbackController.clear();
    ref.read(workoutGenerationProvider.notifier).refine(feedback);
  }

  void _askFollowup(String question) {
    _feedbackController.clear();
    ref.read(workoutGenerationProvider.notifier).askFollowup(question);
  }
}
