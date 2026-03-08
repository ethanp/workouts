import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    super.key,
    required this.title,
    required this.weeks,
    this.barColor,
    this.valueSuffix = '',
    this.formatValue,
  });

  final String title;
  final List<WeekData> weeks;
  final Color? barColor;
  final String valueSuffix;
  final String Function(double value)? formatValue;

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
          _header(),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 140, child: _bars()),
          const SizedBox(height: AppSpacing.xs),
          _labels(),
        ],
      ),
    );
  }

  Widget _header() {
    if (weeks.isEmpty) return Text(title, style: AppTypography.subtitle);

    final averageable = weeks.where((w) => w.includeInAverage).toList();
    final total = averageable.fold(0.0, (sum, w) => sum + w.value);
    final avg = averageable.isEmpty ? 0.0 : total / averageable.length;
    final formatted = formatValue != null
        ? formatValue!(avg)
        : '${avg.toStringAsFixed(1)}$valueSuffix';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTypography.subtitle),
        Text(
          'avg $formatted/wk',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
      ],
    );
  }

  Widget _bars() {
    if (weeks.isEmpty) {
      return const Center(
        child: Text('No data yet', style: AppTypography.caption),
      );
    }

    final maxValue = weeks.fold(0.0, (m, w) => math.max(m, w.value));
    final effectiveMax = maxValue > 0 ? maxValue : 1.0;
    final color = barColor ?? AppColors.accentPrimary;
    final showValueLabels = weeks.length <= 16;
    final barSpacing = switch (weeks.length) {
      > 24 => 1.0,
      > 16 => 2.0,
      _    => 4.0,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < weeks.length; i++) ...[
          if (i > 0) SizedBox(width: barSpacing),
          Expanded(
            child: _bar(weeks[i], effectiveMax, color, showValueLabels),
          ),
        ],
      ],
    );
  }

  Widget _bar(
      WeekData week, double maxValue, Color color, bool showLabel) {
    final fraction = (week.value / maxValue).clamp(0.0, 1.0);
    final barFraction = fraction == 0 ? 0.0 : math.max(fraction, 0.04);
    final label = formatValue != null
        ? formatValue!(week.value)
        : '${week.value.toStringAsFixed(1)}$valueSuffix';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showLabel && week.value > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: AppColors.textColor3,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.clip,
              maxLines: 1,
            ),
          ),
        Flexible(
          child: FractionallySizedBox(
            heightFactor: barFraction,
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3 + fraction * 0.6),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _labels() {
    final count = weeks.length;
    final (labelStride, barSpacing) = switch (count) {
      > 40 => (8, 1.0),
      > 24 => (4, 1.0),
      > 16 => (2, 2.0),
      _    => (1, 4.0),
    };

    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalSpacing = barSpacing * (count - 1);
          final barWidth = (constraints.maxWidth - totalSpacing) / count;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < count; i++)
                if (i % labelStride == 0 || weeks[i].isCurrent)
                  Positioned(
                    left: i * (barWidth + barSpacing) + barWidth / 2 - 20,
                    top: 0,
                    child: SizedBox(
                      width: 40,
                      child: Text(
                        weeks[i].label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: weeks[i].isCurrent
                              ? AppColors.accentPrimary
                              : AppColors.textColor4,
                          fontWeight: weeks[i].isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class WeekData {
  const WeekData({
    required this.label,
    required this.value,
    this.isCurrent = false,
    this.includeInAverage = true,
  });

  final String label;
  final double value;
  final bool isCurrent;
  final bool includeInAverage;
}
