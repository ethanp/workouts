import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/llm_workout_option.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/today/today_template_provider.dart';
import 'package:workouts/features/workout_generation/workout_generation_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/sync_status_icon.dart';
import 'package:workouts/features/today/today_template_card.dart';
import 'package:workouts/features/workout_generation/options/workout_options_sheet.dart';

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
          data: (items) => todayContent(items, ref, context),
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

  Widget todayContent(
    List<WorkoutTemplate> items,
    WidgetRef ref,
    BuildContext context,
  ) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      _GenerateWorkoutButton(
        onSelected: (option) =>
            ref.read(workoutGenerationProvider.notifier).select(option),
      ),
      const SizedBox(height: AppSpacing.xxl),
      _SavedTemplatesSection(
        templates: items,
        onStartTemplate: (template) =>
            ref.read(activeSessionProvider.notifier).start(template.id),
      ),
    ],
  );
}

class _SavedTemplatesSection extends StatelessWidget {
  const _SavedTemplatesSection({
    required this.templates,
    required this.onStartTemplate,
  });

  final List<WorkoutTemplate> templates;
  final ValueChanged<WorkoutTemplate> onStartTemplate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(),
      const SizedBox(height: AppSpacing.md),
      if (templates.isEmpty)
        _emptyState()
      else
        for (final template in templates) ...[
          TodayTemplateCard(
            template: template,
            onStart: () => onStartTemplate(template),
          ),
          if (template != templates.last) const SizedBox(height: AppSpacing.lg),
        ],
    ],
  );

  Widget _sectionHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Saved templates', style: AppTypography.subtitle),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Reusable plans assigned to today.',
        style: AppTypography.caption.copyWith(color: AppColors.textColor4),
      ),
    ],
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Text(
      'No saved templates assigned for today.',
      style: AppTypography.body.copyWith(color: AppColors.textColor4),
    ),
  );
}

class _GenerateWorkoutButton extends StatelessWidget {
  const _GenerateWorkoutButton({required this.onSelected});

  final void Function(LlmWorkoutOption option) onSelected;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        final option = await WorkoutOptionsSheet.show(context);
        if (option != null) onSelected(option);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.accentSecondary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.accentSecondary.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            _leadingIcon(),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _cardText()),
            const SizedBox(width: AppSpacing.md),
            Icon(
              CupertinoIcons.chevron_forward,
              color: AppColors.accentSecondary.withValues(alpha: 0.75),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget subtitle() => Text(
    'Create a workout for today based on your context and desires.',
    style: AppTypography.body.copyWith(color: AppColors.textColor2),
  );

  Widget _cardText() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      headline(),
      const SizedBox(height: AppSpacing.xs),
      subtitle(),
    ],
  );

  Widget _leadingIcon() => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: AppColors.accentSecondary.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: const Icon(
      CupertinoIcons.add,
      color: AppColors.accentSecondary,
      size: 18,
    ),
  );

  Widget headline() => Row(
    children: [Text('Design your own workout', style: AppTypography.subtitle)],
  );
}
