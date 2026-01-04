import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/templates_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/expandable_cues.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesMapAsync = ref.watch(templatesMapProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: templatesMapAsync.when(
          data: (templatesMap) {
            final template = templatesMap[session.templateId];
            return Text(template?.name ?? 'Session Details');
          },
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Session Details'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: AppSpacing.lg),
            ..._buildBlocksList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Summary', style: AppTypography.title),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSummaryRow(
            icon: CupertinoIcons.time,
            label: 'Duration',
            value: _getDurationText(session.duration),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSummaryRow(
            icon: CupertinoIcons.calendar,
            label: 'Completed',
            value: _formatDateTime(session.completedAt ?? session.startedAt),
          ),
          if (session.feeling?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildSummaryRow(
              icon: CupertinoIcons.heart_fill,
              label: 'Feeling',
              value: session.feeling!,
            ),
          ],
          if (session.notes?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Notes', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              session.notes!,
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textColor3),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label: ',
          style: AppTypography.body.copyWith(color: AppColors.textColor3),
        ),
        Text(value, style: AppTypography.body),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final isComplete = session.completedAt != null;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isComplete ? AppColors.success : AppColors.accentPrimary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        isComplete ? 'Completed' : 'In Progress',
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<Widget> _buildBlocksList() {
    final widgets = <Widget>[];
    for (var i = 0; i < session.blocks.length; i++) {
      final block = session.blocks[i];
      widgets.add(_BlockCard(block: block, index: i));
      if (i < session.blocks.length - 1) {
        widgets.add(const SizedBox(height: AppSpacing.md));
      }
    }
    return widgets;
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} at $hour:$minute $period';
  }

  String _getDurationText(Duration? duration) {
    if (duration == null) return 'N/A';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.block, required this.index});

  final SessionBlock block;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Block ${index + 1}: ${titleCase(block.type.name)}',
                style: AppTypography.title,
              ),
              if (block.totalRounds != null)
                Text(
                  'Round ${block.roundIndex}/${block.totalRounds}',
                  style: AppTypography.caption,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...block.exercises.map((exercise) => _buildExercise(exercise)),
        ],
      ),
    );
  }

  String titleCase(String name) {
    final spacesAdded = name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .trim();
    return '${spacesAdded[0].toUpperCase()}${spacesAdded.substring(1)}';
  }

  Widget _buildExercise(WorkoutExercise exercise) {
    final exerciseLogs = block.logs
        .where((log) => log.exerciseId == exercise.id)
        .toList();
    final completedSets = exerciseLogs.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(exercise.name, style: AppTypography.subtitle),
              ),
              Text(
                '$completedSets/${exercise.targetSets} sets',
                style: AppTypography.caption.copyWith(
                  color: completedSets >= exercise.targetSets
                      ? AppColors.success
                      : AppColors.textColor3,
                ),
              ),
            ],
          ),
          if (exercise.restDuration != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Rest: ${_getDurationText(exercise.restDuration)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ],
          if (exercise.cues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ExpandableCues(cues: exercise.cues),
          ],
          if (exerciseLogs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...exerciseLogs.map((log) => _buildSetLog(log)),
          ],
        ],
      ),
    );
  }

  Widget _buildSetLog(SessionSetLog log) {
    final details = <String>[];

    if (log.weightKg != null) {
      details.add('${log.weightKg}kg');
    }
    if (log.reps != null) {
      details.add('${log.reps} reps');
    }
    if (log.duration != null) {
      final mins = log.duration!.inMinutes;
      final secs = log.duration!.inSeconds % 60;
      if (mins > 0) {
        details.add('${mins}m ${secs}s');
      } else {
        details.add('${secs}s');
      }
    }
    if (log.unitRemaining != null) {
      details.add('${log.unitRemaining} left in tank');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.textColor4,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Set ${log.setIndex + 1}: ${details.join(' · ')}',
              style: AppTypography.body.copyWith(color: AppColors.textColor3),
            ),
          ),
        ],
      ),
    );
  }

  String _getDurationText(Duration? duration) {
    if (duration == null) return 'N/A';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
