import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/services/notifications/timer_notification_service.dart';

part 'timer_notification_service_provider.g.dart';

@Riverpod(keepAlive: true)
TimerNotificationService timerNotificationService(Ref ref) {
  return TimerNotificationService();
}
