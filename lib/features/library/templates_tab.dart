import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/features/library/template_detail_screen.dart';
import 'package:workouts/services/repositories/template_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class TemplatesTab extends ConsumerWidget {
  const TemplatesTab({super.key, required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(workoutTemplatesProvider);

    return templatesAsync.when(
      data: (templates) => templates.isEmpty
          ? _EmptyState(onAdd: onAddPressed)
          : _TemplateList(templates: templates),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}

class _TemplateList extends StatelessWidget {
  const _TemplateList({required this.templates});

  final List<WorkoutTemplate> templates;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemCount: templates.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, templateIndex) =>
          _TemplateCard(template: templates[templateIndex]),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template});

  final WorkoutTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockCount = template.blocks.length;
    final exerciseCount =
        template.blocks.expand((block) => block.exercises).length;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => TemplateDetailScreen(template: template),
        ),
      ),
      child: Dismissible(
        key: ValueKey(template.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => ref
            .read(templateRepositoryPowerSyncProvider)
            .deleteTemplate(template.id),
        background: _deleteBackground(),
        child: _card(blockCount, exerciseCount),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) =>
      confirmDeleteDialog(
        context,
        title: 'Delete Routine?',
        content: '"${template.name}" will be permanently deleted.',
      );

  Widget _deleteBackground() => Container(
    decoration: BoxDecoration(
      color: AppColors.error,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: AppSpacing.lg),
    child: const Icon(CupertinoIcons.trash, color: CupertinoColors.white, size: 22),
  );

  Widget _card(int blockCount, int exerciseCount) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Row(
        children: [
          _templateIcon(),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _cardContent(blockCount, exerciseCount)),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: AppColors.textColor4,
          ),
        ],
      ),
    );
  }

  Widget _templateIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(
        CupertinoIcons.rectangle_stack,
        size: 18,
        color: AppColors.accentPrimary,
      ),
    );
  }

  Widget _cardContent(int blockCount, int exerciseCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          template.name,
          style: AppTypography.body.copyWith(
            color: AppColors.textColor1,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (template.goal.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            template.goal,
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            _metaChip(
              '$blockCount ${blockCount == 1 ? 'block' : 'blocks'}',
            ),
            const SizedBox(width: AppSpacing.xs),
            _metaChip(
              '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth4,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textColor4,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                CupertinoIcons.rectangle_stack,
                size: 32,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('No Templates Yet', style: AppTypography.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create workout templates to build structured training sessions.',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            CupertinoButton.filled(
              onPressed: onAdd,
              child: const Text(
                'Create Template',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
