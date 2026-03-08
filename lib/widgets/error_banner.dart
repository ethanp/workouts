import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/error_bus.dart';

final _log = Logger('ErrorBanner');

class ErrorBanner extends StatefulWidget {
  const ErrorBanner({super.key, required this.child});

  final Widget child;

  @override
  State<ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<ErrorBanner> {
  StreamSubscription<String>? _subscription;
  String? _currentError;

  @override
  void initState() {
    super.initState();
    _subscription = errorBus.stream.listen((error) {
      _log.severe(error);
      setState(() => _currentError = error);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentError != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _ErrorToast(
                message: _currentError!,
                onDismiss: () => setState(() => _currentError = null),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorToast extends StatelessWidget {
  const _ErrorToast({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _toastDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.sm),
          _messageBody(),
          const SizedBox(height: AppSpacing.md),
          _actions(),
        ],
      ),
    );
  }

  BoxDecoration _toastDecoration() {
    return BoxDecoration(
      color: const Color(0xFF2C1010),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: CupertinoColors.destructiveRed.withValues(alpha: 0.5),
      ),
      boxShadow: [
        BoxShadow(
          color: CupertinoColors.black.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          color: CupertinoColors.destructiveRed,
          size: 18,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Error',
          style: AppTypography.subtitle.copyWith(
            color: CupertinoColors.destructiveRed,
          ),
        ),
        const Spacer(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(24, 24),
          onPressed: onDismiss,
          child: const Icon(
            CupertinoIcons.xmark,
            color: AppColors.textColor3,
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget _messageBody() {
    return Text(
      message,
      style: AppTypography.caption.copyWith(color: AppColors.textColor2),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _actions() {
    const buttonTextStyle = TextStyle(
      color: CupertinoColors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    );

    return Row(
      children: [
        CupertinoButton(
          padding: buttonPadding,
          color: CupertinoColors.destructiveRed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onPressed: () => _emailError(message),
          child: const Text('Email to me', style: buttonTextStyle),
        ),
        const SizedBox(width: AppSpacing.sm),
        CupertinoButton(
          padding: buttonPadding,
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onPressed: onDismiss,
          child: const Text('Dismiss', style: buttonTextStyle),
        ),
      ],
    );
  }

  Future<void> _emailError(String errorMessage) async {
    final subject = Uri.encodeComponent('Workouts App Error');
    final body = Uri.encodeComponent(
      'Error at ${DateTime.now().toIso8601String()}:\n\n$errorMessage',
    );
    final gmailUri = Uri.parse(
      'googlegmail:///co?to=etahnp@gmail.com&subject=$subject&body=$body',
    );
    if (await canLaunchUrl(gmailUri)) {
      await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
    } else {
      final webUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm'
        '&to=etahnp@gmail.com&su=$subject&body=$body',
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}
