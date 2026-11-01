import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:workouts/app/workouts_home.dart';
import 'package:workouts/app_identity.dart';
import 'package:workouts/services/backend/sync_config.dart';
import 'package:workouts/services/notifications/timer_notification_service_provider.dart';

const _log = ELogger('Main');

void main() {
  _log.log('App starting...');
  SyncedAppLaunch(
    appName: AppIdentity.displayName,
    syncConfig: buildWorkoutsSyncConfig,
    home: const WorkoutsHome(),
    // Warm up the local-notification plugin (timezone DB + plugin init) so
    // the first interval-timer start doesn't pay that cost. Permission is
    // still requested lazily inside `scheduleAt` on first use.
    beforeRunApp: (container) =>
        container.read(timerNotificationServiceProvider).init(),
  ).launch();
}
