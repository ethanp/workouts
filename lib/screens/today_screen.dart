import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/providers/today_template_provider.dart';
import 'package:workouts/providers/workout_generation_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/sync_status_icon.dart';
import 'package:workouts/widgets/today_template_card.dart';
import 'package:workouts/widgets/workout_options_sheet.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(todayTemplatesProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        leading: SyncStatusIcon(),
        middle: Text('Today'),
      ),
      child: SafeArea(
        child: templates.when(
          data: (items) => items.isEmpty
              ? const _EmptyTemplateView()
              : templateList(items, ref, context),
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Unable to load template: $error',
              style: AppTypography.body,
            ),
          ),
        ),
      ),
    );
  }

  Widget templateList(
    List<WorkoutTemplate> items,
    WidgetRef ref,
    BuildContext context,
  ) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final template in items) ...[
          TodayTemplateCard(
            template: template,
            onStart: () => _startSession(ref, template.id),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _GenerateWorkoutButton(
          onSelected: (option) => _handleGeneratedWorkout(context, option, ref),
        ),
      ],
    );
  }

  Future<void> _startSession(WidgetRef ref, String templateId) async {
    await ref.read(activeSessionProvider.notifier).start(templateId);
  }

  Future<void> _handleGeneratedWorkout(
    BuildContext context,
    LlmWorkoutOption option,
    WidgetRef ref,
  ) async {
    await ref.read(workoutGenerationProvider.notifier).select(option);
  }
}

class _EmptyTemplateView extends StatelessWidget {
  const _EmptyTemplateView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No template assigned for today. Create one to begin tracking.',
        style: AppTypography.body,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _GenerateWorkoutButton extends StatelessWidget {
  const _GenerateWorkoutButton({required this.onSelected});

  final void Function(LlmWorkoutOption option) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                color: AppColors.textColor2,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Need inspiration?', style: AppTypography.subtitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Generate personalized workout options based on your goals and recent training.',
            style: AppTypography.body.copyWith(color: AppColors.textColor2),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: AppColors.backgroundDepth3,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              onPressed: () async {
                final option = await WorkoutOptionsSheet.show(context);
                if (option != null) {
                  onSelected(option);
                }
              },
              child: const Text('Generate Workout'),
            ),
          ),
        ],
      ),
    );
  }
}
