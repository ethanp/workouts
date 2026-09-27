import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/features/history/charts/rolling_daily_painter.dart';

class const PolarizationMinuteAxis({required final EChartValueScale scale})
    extends StatelessWidget {
  static const width = RollingDailyPainter.leftPadding;
  static const plotHeight = 140.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: plotHeight,
      child: CustomPaint(
        painter: _MinuteTickPainter(scale: scale),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MinuteTickPainter({required final EChartValueScale scale})
    extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (final tick in scale.ticks) {
      final caption = '${tick.round()}m';
      final textPainter = TextPainter(
        text: TextSpan(text: caption, style: EChartAxis.tickLabel),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width - 4);
      final unclampedY =
          (1 - scale.fractionFromBottom(tick)) * size.height -
          textPainter.height / 2;
      final tickY = unclampedY.clamp(0.0, size.height - textPainter.height);
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 4, tickY),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MinuteTickPainter oldDelegate) =>
      oldDelegate.scale != scale;
}
