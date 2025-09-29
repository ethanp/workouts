import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/theme/app_theme.dart';

class HeartRateTimelineCard extends StatelessWidget {
  const HeartRateTimelineCard({super.key, required this.samples});

  final List<HeartRateSample> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Heart Rate', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _summary(samples),
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.md),
          _TimelinePreview(samples: samples),
        ],
      ),
    );
  }

  String _summary(List<HeartRateSample> samples) {
    if (samples.isEmpty) {
      return 'Waiting for watch connection…';
    }
    final bpmValues = samples.map((s) => s.bpm).toList();
    final avg = (bpmValues.reduce((a, b) => a + b) / bpmValues.length).round();
    final max = bpmValues.reduce((a, b) => a > b ? a : b);
    return 'Avg $avg BPM · Max $max BPM';
  }
}

class _TimelinePreview extends StatelessWidget {
  const _TimelinePreview({required this.samples});

  final List<HeartRateSample> samples;

  @override
  Widget build(BuildContext context) {
    final latest = samples.takeLast(6).toList();
    final timeFormat = DateFormat('mm:ss');
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final sample = latest[index];
          return Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.backgroundDepth3,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderDepth1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${sample.bpm}',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textColor1,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  timeFormat.format(sample.timestamp.toLocal()),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textColor3,
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemCount: latest.length,
      ),
    );
  }
}

extension on List<HeartRateSample> {
  Iterable<HeartRateSample> takeLast(int count) {
    if (length <= count) {
      return this;
    }
    return sublist(length - count);
  }
}
