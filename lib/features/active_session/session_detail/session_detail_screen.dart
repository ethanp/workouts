import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/session_detail/session_blocks_card.dart';
import 'package:workouts/features/active_session/session_detail/session_heart_rate_card.dart';
import 'package:workouts/features/active_session/session_detail/session_notes_card.dart';
import 'package:workouts/features/active_session/session_detail/session_summary_card.dart';
import 'package:workouts/features/active_session/session_notes_provider.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/heart_rate_samples_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesMapAsync = ref.watch(templatesMapProvider);
    final notesAsync = ref.watch(sessionNotesStreamProvider(session.id));
    final heartRateSamplesAsync = ref.watch(
      heartRateSamplesStreamProvider(session.id),
    );
    final restingHrSetting = ref.watch(restingHeartRateProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: templatesMapAsync.when(
          data: (templatesMap) {
            final template = templatesMap[session.templateId];
            return Text(template?.name ?? 'Session Details');
          },
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Session Details'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SessionSummaryCard(session: session),
            const SizedBox(height: AppSpacing.lg),
            SessionHeartRateCard(
              samples: heartRateSamplesAsync.value ?? const <HeartRateSample>[],
              averageHeartRate: session.averageHeartRate,
              maxHeartRate: session.maxHeartRate,
              restingHrSetting: restingHrSetting,
            ),
            if ((heartRateSamplesAsync.value ?? const <HeartRateSample>[])
                .isNotEmpty)
              const SizedBox(height: AppSpacing.lg),
            SessionNotesCard(notes: notesAsync.value ?? []),
            if ((notesAsync.value ?? []).isNotEmpty)
              const SizedBox(height: AppSpacing.lg),
            for (
              var blockIndex = 0;
              blockIndex < session.blocks.length;
              blockIndex++
            ) ...[
              SessionDetailBlockCard(
                block: session.blocks[blockIndex],
                index: blockIndex,
              ),
              if (blockIndex < session.blocks.length - 1)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
