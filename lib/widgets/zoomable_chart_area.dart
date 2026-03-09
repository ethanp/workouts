import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'zoomable_chart_area.g.dart';

@riverpod
class ChartZoomNotifier extends _$ChartZoomNotifier {
  static const _minVisibleDays = 14;

  @override
  DateTimeRange? build() => null;

  /// Scales the visible window by [scaleFactor] around a horizontal
  /// [focalRatio] (0 = left edge, 1 = right edge), clamped to
  /// [_minVisibleDays] and the full data range.
  void zoom(DateTimeRange fullRange, double scaleFactor, double focalRatio) {
    final current = state ?? fullRange;
    final currentDuration = current.duration;
    final newDuration = Duration(
      milliseconds: (currentDuration.inMilliseconds / scaleFactor).round(),
    );

    final fullDuration = fullRange.duration;
    final clampedDuration = Duration(
      milliseconds: newDuration.inMilliseconds.clamp(
        const Duration(days: _minVisibleDays).inMilliseconds,
        fullDuration.inMilliseconds,
      ),
    );

    if (clampedDuration >= fullDuration) {
      state = null;
      return;
    }

    final focalTime = current.start.add(
      Duration(
        milliseconds: (currentDuration.inMilliseconds * focalRatio).round(),
      ),
    );

    final halfBefore = Duration(
      milliseconds: (clampedDuration.inMilliseconds * focalRatio).round(),
    );
    final halfAfter = clampedDuration - halfBefore;

    var newStart = focalTime.subtract(halfBefore);
    var newEnd = focalTime.add(halfAfter);

    if (newStart.isBefore(fullRange.start)) {
      newStart = fullRange.start;
      newEnd = newStart.add(clampedDuration);
    }
    if (newEnd.isAfter(fullRange.end)) {
      newEnd = fullRange.end;
      newStart = newEnd.subtract(clampedDuration);
    }

    state = DateTimeRange(
      start: newStart.isBefore(fullRange.start) ? fullRange.start : newStart,
      end: newEnd.isAfter(fullRange.end) ? fullRange.end : newEnd,
    );
  }

  /// Shifts the visible window by [delta], clamped so it stays
  /// within [fullRange].
  void pan(DateTimeRange fullRange, Duration delta) {
    final current = state ?? fullRange;
    var newStart = current.start.add(delta);
    var newEnd = current.end.add(delta);

    if (newStart.isBefore(fullRange.start)) {
      newStart = fullRange.start;
      newEnd = newStart.add(current.duration);
    }
    if (newEnd.isAfter(fullRange.end)) {
      newEnd = fullRange.end;
      newStart = newEnd.subtract(current.duration);
    }

    state = DateTimeRange(start: newStart, end: newEnd);
  }

  void reset() => state = null;
}

class ZoomableChartArea extends ConsumerStatefulWidget {
  const ZoomableChartArea({
    super.key,
    required this.fullRange,
    required this.child,
  });

  final DateTimeRange fullRange;
  final Widget child;

  @override
  ConsumerState<ZoomableChartArea> createState() => _ZoomableChartAreaState();
}

class _ZoomableChartAreaState extends ConsumerState<ZoomableChartArea> {
  double _lastScale = 1.0;
  Offset _lastFocalPoint = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerSignal: (event) =>
              _handlePointerSignal(event, constraints),
          child: GestureDetector(
            onScaleStart: (details) {
              _lastScale = 1.0;
              _lastFocalPoint = details.localFocalPoint;
            },
            onScaleUpdate: (details) =>
                _handleScaleUpdate(details, constraints),
            onDoubleTap: () {
              ref.read(chartZoomProvider.notifier).reset();
            },
            behavior: HitTestBehavior.translucent,
            child: widget.child,
          ),
        );
      },
    );
  }

  /// Interprets a pinch gesture as either a zoom (when scale != 1)
  /// or a horizontal pan, converting screen-space deltas to
  /// time-range adjustments.
  void _handleScaleUpdate(
    ScaleUpdateDetails details,
    BoxConstraints constraints,
  ) {
    final zoomNotifier = ref.read(chartZoomProvider.notifier);
    final fullRange = widget.fullRange;

    if (details.scale != 1.0) {
      final scaleDelta = details.scale / _lastScale;
      _lastScale = details.scale;
      final focalRatio =
          (details.localFocalPoint.dx / constraints.maxWidth)
              .clamp(0.0, 1.0);
      zoomNotifier.zoom(fullRange, scaleDelta, focalRatio);
    } else {
      final dx = details.localFocalPoint.dx - _lastFocalPoint.dx;
      if (dx.abs() > 0.5) {
        final current = ref.read(chartZoomProvider) ?? fullRange;
        final visibleMs = current.duration.inMilliseconds;
        final panRatio = -dx / constraints.maxWidth;
        final panMs = (visibleMs * panRatio).round();
        zoomNotifier.pan(fullRange, Duration(milliseconds: panMs));
      }
    }
    _lastFocalPoint = details.localFocalPoint;
  }

  /// Zooms the chart when the user scrolls while holding Cmd (macOS).
  /// Scroll-up zooms in, scroll-down zooms out, anchored at the
  /// cursor's horizontal position.
  void _handlePointerSignal(
    PointerSignalEvent event,
    BoxConstraints constraints,
  ) {
    if (event is! PointerScrollEvent) return;
    final cmdHeld = HardwareKeyboard.instance.logicalKeysPressed
        .any((key) =>
            key == LogicalKeyboardKey.metaLeft ||
            key == LogicalKeyboardKey.metaRight);
    if (!cmdHeld) return;

    final scrollDelta = event.scrollDelta.dy;
    final scaleFactor = scrollDelta < 0 ? 1.15 : 0.87;
    final focalRatio =
        (event.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    ref
        .read(chartZoomProvider.notifier)
        .zoom(widget.fullRange, scaleFactor, focalRatio);
  }
}
