import 'dart:async';

import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/services/health_kit_bridge.dart';

class FakeHealthKitBridge extends HealthKitBridge {
  FakeHealthKitBridge({
    this.status = HealthPermissionStatus.unknown,
    this.requestedStatus = HealthPermissionStatus.authorized,
    this.deleteResult = true,
  });

  HealthPermissionStatus status;
  HealthPermissionStatus requestedStatus;
  bool deleteResult;

  final _controller = StreamController<HeartRateSample>.broadcast();

  @override
  Future<HealthPermissionStatus> getAuthorizationStatus() async => status;

  @override
  Future<HealthPermissionStatus> requestAuthorization() async => requestedStatus;

  @override
  Stream<HeartRateSample> heartRateStream() => _controller.stream;

  @override
  Future<bool> deleteWorkouts(List<String> uuids) async => deleteResult;

  void emit(HeartRateSample sample) => _controller.add(sample);

  void dispose() {
    _controller.close();
  }
}
