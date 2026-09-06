import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:workouts/utils/error_bus.dart';

const _recentLogLineCount = 75;

const _log = ELogger('ErrorBanner');

class const ErrorBanner({required final Widget child}) extends StatefulWidget {
  @override
  State<ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState() extends State<ErrorBanner> {
  StreamSubscription<String>? _subscription;
  String? _currentError;

  @override
  void initState() {
    super.initState();
    _subscription = errorBus.stream.listen((error) {
      _log.error(error);
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

class const _ErrorToast({
  required final String message,
  required final VoidCallback onDismiss,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(ELayout.spaceMd),
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: _toastDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: ELayout.spaceSm),
          _messageBody(),
          const SizedBox(height: ELayout.spaceMd),
          _actions(),
        ],
      ),
    );
  }

  BoxDecoration _toastDecoration() {
    return BoxDecoration(
      color: const Color(0xFF2C1010),
      borderRadius: ELayout.borderRadiusMd,
      border: Border.all(color: EColors.danger.withValues(alpha: 0.5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.warning, color: EColors.danger, size: 18),
        const SizedBox(width: ELayout.spaceSm),
        Text('Error', style: EText.section.danger),
        const Spacer(),
        IconButton(
          tooltip: 'Dismiss',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: onDismiss,
          icon: const Icon(Icons.close, color: EColors.textTertiary, size: 16),
        ),
      ],
    );
  }

  Widget _messageBody() {
    return SelectionArea(
      child: Text(
        message,
        style: EText.caption.secondary,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _actions() {
    final buttonStyle = FilledButton.styleFrom(
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceMd,
        vertical: ELayout.spaceSm,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: ELayout.borderRadiusSm,
      ),
    );

    return Row(
      children: [
        FilledButton(
          style: buttonStyle.copyWith(
            backgroundColor: const WidgetStatePropertyAll(EColors.danger),
          ),
          onPressed: () => _emailError(message),
          child: const Text('Email to me'),
        ),
        const SizedBox(width: ELayout.spaceSm),
        FilledButton(
          style: buttonStyle.copyWith(
            backgroundColor: const WidgetStatePropertyAll(EColors.surface),
          ),
          onPressed: () => Clipboard.setData(ClipboardData(text: message)),
          child: const Text('Copy'),
        ),
        const SizedBox(width: ELayout.spaceSm),
        FilledButton(
          style: buttonStyle.copyWith(
            backgroundColor: const WidgetStatePropertyAll(EColors.surface),
          ),
          onPressed: onDismiss,
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  Future<void> _emailError(String errorMessage) async {
    final logTail = appLogBuffer.entries
        .skip(
          (appLogBuffer.entries.length - _recentLogLineCount).clamp(
            0,
            appLogBuffer.entries.length,
          ),
        )
        .map((e) => e.formattedText)
        .join('\n');

    final subject = Uri.encodeComponent('Workouts App Error');
    final body = Uri.encodeComponent(
      'Error at ${DateTime.now().toIso8601String()}:\n\n'
      '$errorMessage\n\n'
      '--- Recent log (${appLogBuffer.entries.length < _recentLogLineCount ? appLogBuffer.entries.length : _recentLogLineCount} lines) ---\n'
      '$logTail',
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
