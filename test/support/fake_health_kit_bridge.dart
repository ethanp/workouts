import 'dart:async';

import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/services/health_kit_bridge.dart';

class FakeHealthKitBridge extends HealthKitBridge {
  FakeHealthKitBridge({
    this.status = HealthPermissionStatus.unknown,
    this.requestedStatus = HealthPermissionStatus.authorized,
  });

  HealthPermissionStatus status;
  HealthPermissionStatus requestedStatus;

  final _controller = StreamController<HeartRateSample>.broadcast();

  @override
  Future<HealthPermissionStatus> getAuthorizationStatus() async => status;

  @override
  Future<HealthPermissionStatus> requestAuthorization() async => requestedStatus;

  @override
  Stream<HeartRateSample> heartRateStream() => _controller.stream;

  @override
  Future<int> countRunningWorkouts() async => 0;

  void emit(HeartRateSample sample) => _controller.add(sample);

  void dispose() {
    _controller.close();
  }
}
