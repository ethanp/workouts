import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/features/active_session/exercise/active_timer_store.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';

part 'active_timer_store_provider.g.dart';

@Riverpod(keepAlive: true)
ActiveTimerStore activeTimerStore(Ref ref) {
  return ActiveTimerStore(ref.watch(sharedPreferencesProvider));
}
