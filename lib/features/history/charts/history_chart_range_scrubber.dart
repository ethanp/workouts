import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/widgets/zoomable_chart_area.dart';

class const HistoryChartRangeScrubber({
  required final DateTimeRange fullRange,
  required final CustomPainter plot,
  required final Color windowColor,
}) extends ConsumerWidget {
  static const height = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTimeRange? zoomRange = ref.watch(chartZoomProvider);
    final DateTimeRange visible =
        zoomRange ?? ChartZoomNotifier.defaultVisibleRange(fullRange);
    return EChartVisibleRangeScrubber(
      fullStart: fullRange.start,
      fullEnd: fullRange.end,
      visible: EChartVisibleRange(start: visible.start, end: visible.end),
      windowColor: windowColor,
      height: height,
      plot: plot,
      onVisibleRangeChanged: (range) {
        ref.read(chartZoomProvider.notifier).setVisibleRange(
          DateTimeRange(start: range.start, end: range.end),
        );
      },
    );
  }
}
