import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/features/library/template_detail_screen.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';
import 'package:workouts/widgets/delete_confirmation_dialog.dart';

class const TemplatesTab({
  super.key,
  required final VoidCallback onTemplateAddRequested,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(workoutTemplatesProvider);

    return templatesAsync.when(
      data: (templates) => templates.isEmpty
          ? _EmptyState(onTemplateAddRequested: onTemplateAddRequested)
          : _TemplateList(templates: templates),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: EText.body.medium.copyWith(color: EColors.danger),
        ),
      ),
    );
  }
}

class const _TemplateList({required final List<WorkoutTemplate> templates})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceLg,
        vertical: ELayout.spaceMd,
      ),
      itemCount: templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: ELayout.spaceSm),
      itemBuilder: (context, templateIndex) =>
          _TemplateCard(template: templates[templateIndex]),
    );
  }
}

class const _TemplateCard({required final WorkoutTemplate template})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockCount = template.blocks.length;
    final exerciseCount = template.blocks
        .expand((block) => block.exercises)
        .length;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TemplateDetailScreen(templateId: template.id),
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

  Future<bool> _confirmDelete(BuildContext context) => confirmDeleteDialog(
    context,
    title: 'Delete Routine?',
    content: '"${template.name}" will be permanently deleted.',
  );

  Widget _deleteBackground() => Container(
    decoration: BoxDecoration(
      color: EColors.danger,
      borderRadius: BorderRadius.circular(ELayout.radiusMd),
    ),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: ELayout.spaceLg),
    child: const Icon(
      Icons.delete,
      color: Colors.white,
      size: 22,
    ),
  );

  Widget _card(int blockCount, int exerciseCount) {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Row(
        children: [
          _templateIcon(),
          const SizedBox(width: ELayout.spaceMd),
          Expanded(child: _cardContent(blockCount, exerciseCount)),
          const Icon(
            Icons.chevron_right,
            size: 14,
            color: EColors.textMuted,
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
        color: EColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: const Icon(
        Icons.layers,
        size: 18,
        color: EColors.accent,
      ),
    );
  }

  Widget _cardContent(int blockCount, int exerciseCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          template.name,
          style: EText.body.medium.copyWith(
            color: EColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (template.goal.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            template.goal,
            style: EText.caption.copyWith(color: EColors.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: ELayout.spaceXs),
        Row(
          children: [
            _metaChip('$blockCount ${blockCount == 1 ? 'block' : 'blocks'}'),
            const SizedBox(width: ELayout.spaceXs),
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
        color: EColors.surfaceRaised,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: EColors.textMuted,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class const _EmptyState({required final VoidCallback onTemplateAddRequested})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ELayout.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: EColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.layers,
                size: 32,
                color: EColors.accent,
              ),
            ),
            const SizedBox(height: ELayout.spaceXl),
            Text('No Templates Yet', style: EText.title),
            const SizedBox(height: ELayout.spaceSm),
            Text(
              'Create workout templates to build structured training sessions.',
              style: EText.body.medium.copyWith(color: EColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onTemplateAddRequested,
              child: const Text('Create Template'),
            ),
          ],
        ),
      ),
    );
  }
}
