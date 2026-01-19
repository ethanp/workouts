import 'package:flutter/cupertino.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/theme/app_theme.dart';

class HeartRateTimelineCard extends StatelessWidget {
  const HeartRateTimelineCard({super.key, required this.samples});

  final List<HeartRateSample> samples;

  @override
  Widget build(BuildContext context) {
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
      return 'Waiting for watch connection...';
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
    return SizedBox(height: 120, child: HeartRateMiniChart(samples: samples));
  }
}

class HeartRateMiniChart extends StatelessWidget {
  const HeartRateMiniChart({super.key, required this.samples});

  final List<HeartRateSample> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Center(
          child: Text(
            samples.isEmpty ? 'No samples yet' : '${samples.first.bpm} BPM',
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _HeartRateLinePainter(samples: samples),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderDepth1),
        ),
      ),
    );
  }
}

class _HeartRateLinePainter extends CustomPainter {
  _HeartRateLinePainter({required this.samples});

  final List<HeartRateSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final minBpm = samples.map((s) => s.bpm).reduce((a, b) => a < b ? a : b);
    final maxBpm = samples.map((s) => s.bpm).reduce((a, b) => a > b ? a : b);
    final range = (maxBpm - minBpm).clamp(1, 1000);

    final linePaint = Paint()
      ..color = AppColors.accentPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final points = <Offset>[];
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final x = size.width * (i / (samples.length - 1));
      final normalized = (sample.bpm - minBpm) / range;
      final y = size.height - (normalized * size.height);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _HeartRateLinePainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}
