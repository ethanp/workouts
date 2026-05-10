import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/session_resume/session_resume_body.dart';
import 'package:workouts/theme/app_theme.dart';

class SessionResumeScreen extends ConsumerWidget {
  const SessionResumeScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(activeSessionProvider);

    return sessionAsync.when(
      data: (session) => session == null
          ? const CupertinoPageScaffold(
              child: Center(child: Text('No active session.')),
            )
          : SessionResumeBody(session: session),
      loading: () => const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) => CupertinoPageScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
