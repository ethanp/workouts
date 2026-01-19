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
          _HeartRateHeader(samples: samples),
          const SizedBox(height: AppSpacing.md),
          _TimelinePreview(samples: samples),
        ],
      ),
    );
  }
}

class _HeartRateHeader extends StatelessWidget {
  const _HeartRateHeader({required this.samples});

  final List<HeartRateSample> samples;

  @override
  Widget build(BuildContext context) {
    final currentBpm = samples.isNotEmpty ? samples.last.bpm : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (currentBpm != null)
          ..._liveHeartRate(currentBpm)
        else
          ..._waitingState(),
        if (samples.isNotEmpty) _statsSummary(),
      ],
    );
  }

  List<Widget> _liveHeartRate(int bpm) => [
    const Icon(
      CupertinoIcons.heart_fill,
      color: CupertinoColors.systemRed,
      size: 24,
    ),
    const SizedBox(width: AppSpacing.xs),
    Text(
      '$bpm',
      style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
    ),
    const SizedBox(width: 4),
    Text(
      'BPM',
      style: AppTypography.caption.copyWith(color: AppColors.textColor3),
    ),
    const Spacer(),
  ];

  List<Widget> _waitingState() => [
    const Icon(CupertinoIcons.heart, color: AppColors.textColor3, size: 20),
    const SizedBox(width: AppSpacing.xs),
    Expanded(
      child: Text(
        'Waiting for watch...',
        style: AppTypography.body.copyWith(color: AppColors.textColor3),
      ),
    ),
  ];

  Widget _statsSummary() {
    final bpmValues = samples.map((s) => s.bpm).toList();
    final avg = (bpmValues.reduce((a, b) => a + b) / bpmValues.length).round();
    final max = bpmValues.reduce((a, b) => a > b ? a : b);
    return Text(
      'Avg $avg · Max $max',
      style: AppTypography.caption.copyWith(color: AppColors.textColor3),
    );
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
