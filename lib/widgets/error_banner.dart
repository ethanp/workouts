import 'dart:async';

import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:workouts/error_bus.dart';

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
              child: ErrorSnackBar(
                message: _currentError!,
                emailSubject: 'Workouts App Error',
                onDismiss: () => setState(() => _currentError = null),
              ),
            ),
          ),
      ],
    );
  }
}
