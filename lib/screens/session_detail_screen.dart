import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/polarization_week.dart';
import 'package:workouts/models/session_note.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/heart_rate_samples_provider.dart';
import 'package:workouts/providers/session_notes_provider.dart';
import 'package:workouts/providers/templates_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/utils/training_load_calculator.dart';
import 'package:workouts/widgets/expandable_cues.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesMapAsync = ref.watch(templatesMapProvider);
    final notesAsync = ref.watch(sessionNotesStreamProvider(session.id));
    final heartRateSamplesAsync = ref.watch(
      heartRateSamplesStreamProvider(session.id),
    );
    final maxHrSetting = ref.watch(maxHeartRateProvider);
    final restingHrSetting = ref.watch(restingHeartRateProvider);

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
            _SessionHeartRateCard(
              samples: heartRateSamplesAsync.value ?? const [],
              averageHeartRate: session.averageHeartRate,
              maxHeartRate: session.maxHeartRate,
              maxHrSetting: maxHrSetting,
              restingHrSetting: restingHrSetting,
            ),
            if ((heartRateSamplesAsync.value ?? const []).isNotEmpty)
              const SizedBox(height: AppSpacing.lg),
            _SessionNotesCard(notes: notesAsync.value ?? []),
            if ((notesAsync.value ?? []).isNotEmpty)
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
            value: Format.dateTime(session.completedAt ?? session.startedAt),
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
    for (var blockIndex = 0; blockIndex < session.blocks.length; blockIndex++) {
      final block = session.blocks[blockIndex];
      widgets.add(_BlockCard(block: block, index: blockIndex));
      if (blockIndex < session.blocks.length - 1) {
        widgets.add(const SizedBox(height: AppSpacing.md));
      }
    }
    return widgets;
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

class _SessionNotesCard extends StatelessWidget {
  const _SessionNotesCard({required this.notes});

  final List<SessionNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

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
            children: [
              const Icon(
                CupertinoIcons.doc_text,
                size: 20,
                color: AppColors.textColor2,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Session Notes', style: AppTypography.title),
              const Spacer(),
              Text(
                '${notes.length}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...notes.map((note) => _buildNoteItem(note)),
        ],
      ),
    );
  }

  Widget _buildNoteItem(SessionNote note) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: _getTypeColor(note.noteType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              note.noteType.icon,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.content, style: AppTypography.body),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Format.time(note.timestamp),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textColor4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(SessionNoteType type) {
    return switch (type) {
      SessionNoteType.observation => AppColors.textColor2,
      SessionNoteType.modification => AppColors.accentPrimary,
      SessionNoteType.painSignal => AppColors.warning,
      SessionNoteType.breakthrough => AppColors.success,
    };
  }

}

class _SessionHeartRateCard extends StatelessWidget {
  const _SessionHeartRateCard({
    required this.samples,
    required this.averageHeartRate,
    required this.maxHeartRate,
    required this.maxHrSetting,
    required this.restingHrSetting,
  });

  final List<HeartRateSample> samples;
  final int? averageHeartRate;
  final int? maxHeartRate;
  final int maxHrSetting;
  final int restingHrSetting;

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
            children: [
              const Icon(
                CupertinoIcons.heart_fill,
                size: 20,
                color: AppColors.textColor2,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Heart Rate', style: AppTypography.title),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _StatPill(label: 'Avg', value: _avgText()),
              const SizedBox(width: AppSpacing.sm),
              _StatPill(label: 'Max', value: _maxText()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          MetricsMiniChart(samples: samples),
          if (samples.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _ZoneDistributionSection(
              samples: samples,
              maxHrSetting: maxHrSetting,
              restingHrSetting: restingHrSetting,
            ),
          ],
        ],
      ),
    );
  }

  String _avgText() {
    if (averageHeartRate != null) {
      return '${averageHeartRate!} BPM';
    }
    if (samples.isEmpty) return '--';
    final averageBpm = (samples
                .map((heartRateSample) => heartRateSample.bpm)
                .reduce((firstBpm, secondBpm) => firstBpm + secondBpm) /
            samples.length)
            .round();
    return '$averageBpm BPM';
  }

  String _maxText() {
    if (maxHeartRate != null) {
      return '${maxHeartRate!} BPM';
    }
    if (samples.isEmpty) return '--';
    final maxBpm = samples
        .map((heartRateSample) => heartRateSample.bpm)
        .reduce((firstBpm, secondBpm) => firstBpm > secondBpm ? firstBpm : secondBpm);
    return '$maxBpm BPM';
  }
}

class _ZoneDistributionSection extends StatefulWidget {
  const _ZoneDistributionSection({
    required this.samples,
    required this.maxHrSetting,
    required this.restingHrSetting,
  });

  final List<HeartRateSample> samples;
  final int maxHrSetting;
  final int restingHrSetting;

  @override
  State<_ZoneDistributionSection> createState() =>
      _ZoneDistributionSectionState();
}

class _ZoneDistributionSectionState
    extends State<_ZoneDistributionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text(
                'Zone Distribution',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                _expanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                size: 11,
                color: AppColors.textColor4,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.sm),
          _ZoneBreakdown(
            samples: widget.samples,
            maxHrSetting: widget.maxHrSetting,
            restingHrSetting: widget.restingHrSetting,
          ),
        ],
      ],
    );
  }
}

class _ZoneBreakdown extends StatelessWidget {
  const _ZoneBreakdown({
    required this.samples,
    required this.maxHrSetting,
    required this.restingHrSetting,
  });

  final List<HeartRateSample> samples;
  final int maxHrSetting;
  final int restingHrSetting;

  static const _aerobicColor = Color(0xFF3FB37F);
  static const _grayZoneColor = Color(0xFFF0B347);
  static const _vo2maxColor = Color(0xFFE15A64);

  @override
  Widget build(BuildContext context) {
    final polarization = _compute();
    if (!polarization.hasData) {
      return Text(
        'Not enough HR data to compute zones.',
        style: AppTypography.caption.copyWith(color: AppColors.textColor4),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shown as Aerobic Base · Gray Zone · VO₂max — metabolic context only.',
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor4,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (polarization.aerobicBaseSeconds > 0)
                  Flexible(
                    flex: polarization.aerobicBaseSeconds,
                    child: Container(color: _aerobicColor),
                  ),
                if (polarization.grayZoneSeconds > 0)
                  Flexible(
                    flex: polarization.grayZoneSeconds,
                    child: Container(color: _grayZoneColor),
                  ),
                if (polarization.vo2maxSeconds > 0)
                  Flexible(
                    flex: polarization.vo2maxSeconds,
                    child: Container(color: _vo2maxColor),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            _pill(
              '${polarization.aerobicBaseMinutes}m Base',
              _aerobicColor,
            ),
            const SizedBox(width: AppSpacing.xs),
            _pill('${polarization.grayZoneMinutes}m Gray', _grayZoneColor),
            const SizedBox(width: AppSpacing.xs),
            _pill(
              '${polarization.vo2maxMinutes}m VO₂max',
              _vo2maxColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }

  PolarizationWeek _compute() {
    final calculator = TrainingLoadCalculator(
      maxHeartRate: maxHrSetting,
      restingHeartRate: restingHrSetting,
    );

    final timestamped = samples
        .map(
          (sample) => TimestampedHeartRate(
            timestamp: sample.timestamp,
            bpm: sample.bpm,
          ),
        )
        .toList()
      ..sort(
        (firstSample, secondSample) =>
            firstSample.timestamp.compareTo(secondSample.timestamp),
      );

    final result = calculator.compute(timestamped);
    return PolarizationWeek.fromHrZoneTime(result.zoneTime);
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Row(
        children: [
          Text(
            '$label ',
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
          Text(value, style: AppTypography.caption),
        ],
      ),
    );
  }
}
