import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/workout_generation/options/workout_followup_answer.dart';
import 'package:workouts/features/workout_generation/workout_generation_provider.dart';
import 'package:workouts/features/workout_generation/workout_generation_status_views.dart';
import 'package:workouts/features/workout_generation/options/workout_options_list.dart';
import 'package:workouts/features/workout_generation/options/workout_refinement_panel.dart';
import 'package:workouts/features/workout_generation/workout_preferences_form.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/services/context_builder.dart';
import 'package:workouts/services/llm/llm_errors.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';

class WorkoutOptionsSheet extends ConsumerStatefulWidget {
  const WorkoutOptionsSheet({super.key});

  static Future<LlmWorkoutOption?> show(BuildContext context) {
    return Navigator.of(context).push<LlmWorkoutOption>(
      CupertinoPageRoute(builder: (_) => const WorkoutOptionsSheet()),
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
  RefinementMode _refinementMode = RefinementMode.refine;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(workoutGenerationProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundDepth1,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundDepth1,
        border: const Border(bottom: BorderSide(color: AppColors.borderDepth1)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            ref.read(workoutGenerationProvider.notifier).cancel();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        middle: const Text('Generate Workout', style: AppTypography.subtitle),
      ),
      child: SafeArea(
        child: _showingForm
            ? WorkoutPreferencesForm(onSubmit: _onFormSubmit)
            : switch (generationState) {
                GenerationIdle() => const WorkoutGenerationPreparingView(),
                GenerationStreaming(:final partialText) =>
                  WorkoutGenerationStreamingView(partialText: partialText),
                GenerationComplete(:final response) => _optionsView(response),
                GenerationFollowup(
                  :final response,
                  :final partialAnswer,
                  :final answering,
                ) =>
                  _followupView(response, partialAnswer, answering),
                GenerationFailed(:final error) => _errorView(error),
              },
      ),
    );
  }

  void _onFormSubmit(WorkoutPreferences preferences) {
    setState(() => _showingForm = false);
    ref
        .read(workoutGenerationProvider.notifier)
        .generate(preferences: preferences);
  }

  Widget _optionsView(LlmWorkoutResponse response, {String? followupAnswer}) {
    return WorkoutOptionsList(
      response: response,
      expandedOptionId: _expandedOptionId,
      onToggleOption: _toggleExpandedOption,
      onSelectOption: _selectOption,
      footer: _refinementSection(followupAnswer: followupAnswer),
    );
  }

  Widget _refinementSection({String? followupAnswer}) {
    return WorkoutRefinementPanel(
      mode: _refinementMode,
      feedbackController: _feedbackController,
      followupAnswer: followupAnswer,
      onModeChanged: (mode) {
        setState(() => _refinementMode = mode);
        _feedbackController.clear();
      },
      onFeedbackChanged: () => setState(() {}),
      onAsk: _askFollowup,
      onRefine: _refine,
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
            Text(
              message,
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ConnectionGatedWidget(
              child: CupertinoButton.filled(
                onPressed: () =>
                    ref.read(workoutGenerationProvider.notifier).generate(),
                child: const Text('Try Again'),
              ),
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
      return WorkoutOptionsList(
        response: response,
        expandedOptionId: _expandedOptionId,
        onToggleOption: _toggleExpandedOption,
        onSelectOption: _selectOption,
        showExplanation: false,
        footer: WorkoutFollowupAnswer(answer: partialAnswer, answering: true),
      );
    }

    return _optionsView(response, followupAnswer: partialAnswer);
  }

  void _selectOption(LlmWorkoutOption option) {
    Navigator.of(context).pop(option);
  }

  void _toggleExpandedOption(String optionId) {
    setState(() {
      _expandedOptionId = _expandedOptionId == optionId ? null : optionId;
    });
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
