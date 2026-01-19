import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/providers/today_template_provider.dart';
import 'package:workouts/screens/settings_screen.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/expandable_cues.dart';
import 'package:workouts/widgets/sync_status_icon.dart';
import 'package:workouts/widgets/today_template_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(todayTemplatesProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: const SyncStatusIcon(),
        middle: const Text('Today'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(
              context,
            ).push(CupertinoPageRoute(builder: (_) => const SettingsScreen()));
          },
          child: const Icon(CupertinoIcons.gear, color: CupertinoColors.white),
        ),
      ),
      child: SafeArea(
        child: templates.when(
          data: (items) => items.isEmpty
              ? const _EmptyTemplateView()
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final template in items) ...[
                      TodayTemplateCard(
                        template: template,
                        onStart: () => _startSession(ref, template.id),
                        onTap: () => ref
                            .read(expandedTemplatesProvider.notifier)
                            .toggle(template.id),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (ref.watch(
                        expandedTemplatesProvider.select(
                          (s) => s.contains(template.id),
                        ),
                      )) ...[
                        _BlockPreviewList(blocks: template.blocks),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    const _AnimalMovementSummary(),
                  ],
                ),
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

  Future<void> _startSession(WidgetRef ref, String templateId) async {
    await ref.read(activeSessionProvider.notifier).start(templateId);
  }
}

class _BlockPreviewList extends StatelessWidget {
  const _BlockPreviewList({required this.blocks});

  final List<WorkoutBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session Overview', style: AppTypography.title),
        const SizedBox(height: AppSpacing.md),
        ...blocks.map((block) => _BlockPreview(block: block)),
      ],
    );
  }
}

class _BlockPreview extends StatelessWidget {
  const _BlockPreview({required this.block});

  final WorkoutBlock block;

  String get blockLabel => switch (block.type) {
    WorkoutBlockType.warmup => 'Warmup',
    WorkoutBlockType.animalFlow => 'Animal Flow',
    WorkoutBlockType.strength => 'Strength',
    WorkoutBlockType.mobility => 'Mobility',
    WorkoutBlockType.core => 'Core',
    WorkoutBlockType.conditioning => 'Conditioning',
    WorkoutBlockType.cooldown => 'Cooldown',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(blockLabel, style: AppTypography.subtitle),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (block.rounds > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDepth3,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.borderDepth2),
                      ),
                      child: Text(
                        '${block.rounds} rounds',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textColor3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    '${block.targetDuration.inMinutes}m',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...block.exercises.map(
            (exercise) => _ExercisePreview(exercise: exercise),
          ),
        ],
      ),
    );
  }
}

class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview({required this.exercise});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                exercise.prescription,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor3,
                ),
              ),
            ],
          ),
          if (exercise.restDuration != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Rest: ${_formatDuration(exercise.restDuration!)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ],
          if (exercise.cues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            ExpandableCues(cues: exercise.cues),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}

class _AnimalMovementSummary extends StatelessWidget {
  const _AnimalMovementSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: AppColors.backgroundDepth2,
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Animal Movements', style: AppTypography.subtitle),
          SizedBox(height: AppSpacing.sm),
          _MovementTile(
            title: 'Beast Crawl',
            description:
                'Integrates scapula, ribs, and core with contralateral patterning.',
          ),
          SizedBox(height: AppSpacing.sm),
          _MovementTile(
            title: 'Crab Reach',
            description:
                'Opens shoulder blade, ribs, and hip flexors through loaded extension.',
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(description, style: AppTypography.caption),
      ],
    );
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
