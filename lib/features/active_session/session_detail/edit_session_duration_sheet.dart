import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/error_bus.dart';

class EditSessionDurationSheet extends ConsumerStatefulWidget {
  const EditSessionDurationSheet({super.key, required this.session});

  final Session session;

  @override
  ConsumerState<EditSessionDurationSheet> createState() =>
      _EditSessionDurationSheetState();
}

class _EditSessionDurationSheetState
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dragHandle(),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Edit Duration',
                style: AppTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 220,
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hms,
                  initialTimerDuration: _duration,
                  onTimerDurationChanged: (newDuration) =>
                      setState(() => _duration = newDuration),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CupertinoButton.filled(
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              CupertinoButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textColor3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.borderDepth3,
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
