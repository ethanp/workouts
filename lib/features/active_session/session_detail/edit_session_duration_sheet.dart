import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';
import 'package:workouts/utils/error_bus.dart';

class const EditSessionDurationSheet({required final Session session})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<EditSessionDurationSheet> createState() =>
      _EditSessionDurationSheetState();
}

class _EditSessionDurationSheetState()
    extends ConsumerState<EditSessionDurationSheet> {
  late Duration _duration;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _duration = widget.session.duration ?? Duration.zero;
  }

  Duration get _initialDuration => widget.session.duration ?? Duration.zero;

  bool get _canSave =>
      !_saving && _duration > Duration.zero && _duration != _initialDuration;

  int get _hours => _duration.inHours;
  int get _minutes => _duration.inMinutes.remainder(60);
  int get _seconds => _duration.inSeconds.remainder(60);

  @override
  Widget build(BuildContext context) {
    return _sheetPanel(child: _sheetBody());
  }

  Widget _sheetPanel({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ELayout.radiusXl),
        ),
      ),
      child: SafeArea(top: false, child: child),
    );
  }

  Widget _sheetBody() {
    return Padding(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dragHandle(),
          const SizedBox(height: ELayout.spaceLg),
          Text(
            'Edit Duration',
            style: EText.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ELayout.spaceLg),
          _durationFields(),
          const SizedBox(height: ELayout.spaceLg),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: ELayout.spaceSm),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: EColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationFields() {
    return Row(
      children: [
        Expanded(
          child: _unitDropdown(
            label: 'Hours',
            value: _hours,
            maxInclusive: 9,
            onChanged: (hours) => _setDuration(
              hours: hours,
              minutes: _minutes,
              seconds: _seconds,
            ),
          ),
        ),
        const SizedBox(width: ELayout.spaceMd),
        Expanded(
          child: _unitDropdown(
            label: 'Minutes',
            value: _minutes,
            maxInclusive: 59,
            onChanged: (minutes) => _setDuration(
              hours: _hours,
              minutes: minutes,
              seconds: _seconds,
            ),
          ),
        ),
        const SizedBox(width: ELayout.spaceMd),
        Expanded(
          child: _unitDropdown(
            label: 'Seconds',
            value: _seconds,
            maxInclusive: 59,
            onChanged: (seconds) => _setDuration(
              hours: _hours,
              minutes: _minutes,
              seconds: seconds,
            ),
          ),
        ),
      ],
    );
  }

  Widget _unitDropdown({
    required String label,
    required int value,
    required int maxInclusive,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: EText.caption.copyWith(color: EColors.textTertiary)),
        const SizedBox(height: ELayout.spaceXs),
        DropdownButtonFormField<int>(
          initialValue: value,
          decoration: EInput.filled(isDense: true),
          items: [
            for (var unit = 0; unit <= maxInclusive; unit++)
              DropdownMenuItem(value: unit, child: Text('$unit')),
          ],
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ],
    );
  }

  void _setDuration({
    required int hours,
    required int minutes,
    required int seconds,
  }) {
    setState(() {
      _duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
    });
  }

  Widget _dragHandle() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: EColors.borderStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      final repository = ref.read(sessionRepositoryPowerSyncProvider);
      await repository.updateSessionDuration(widget.session.id, _duration);
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      errorBus.add('Update session duration: $error');
      if (mounted) setState(() => _saving = false);
    }
  }
}
