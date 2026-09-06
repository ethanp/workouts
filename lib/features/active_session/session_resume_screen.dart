import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/session_resume/session_resume_body.dart';

class const SessionResumeScreen({required final String sessionId})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(activeSessionProvider);

    return sessionAsync.when(
      data: (session) => session == null
          ? const Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(child: Text('No active session.')),
            )
          : SessionResumeBody(session: session),
      loading: () => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(ELayout.spaceLg),
            child: Text(
              'Error loading session: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
