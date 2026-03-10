import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let healthKitBridge = HealthKitBridge()
  private let heartRateStreamHandler = HeartRateStreamHandler()
  private let watchConnectivityStreamHandler = WatchConnectivityStreamHandler()
  private let watchCommandStreamHandler = WatchCommandStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger
      let methodChannel = FlutterMethodChannel(
        name: "com.workouts/health_kit",
        binaryMessenger: messenger
      )
      methodChannel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "bridge_missing", message: "HealthKit bridge missing", details: nil))
          return
        }
        self.handleHealthKitMethodCall(call: call, result: result)
      }

      FlutterEventChannel(
        name: "com.workouts/heart_rate_stream",
        binaryMessenger: messenger
      ).setStreamHandler(heartRateStreamHandler)

      FlutterEventChannel(
        name: "com.workouts/watch_connectivity",
        binaryMessenger: messenger
      ).setStreamHandler(watchConnectivityStreamHandler)

      FlutterEventChannel(
        name: "com.workouts/watch_commands",
        binaryMessenger: messenger
      ).setStreamHandler(watchCommandStreamHandler)
      
      // Watch workout control channel
      let watchChannel = FlutterMethodChannel(
        name: "com.workouts/watch_workout",
        binaryMessenger: messenger
      )
      watchChannel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "bridge_missing", message: "Watch bridge missing", details: nil))
          return
        }
        self.handleWatchMethodCall(call: call, result: result)
      }
    }

    WatchSessionManager.shared.configureSession(
      connectivityHandler: watchConnectivityStreamHandler,
      heartRateHandler: heartRateStreamHandler,
      watchCommandHandler: watchCommandStreamHandler
    )
    return didFinish
  }

  private func handleHealthKitMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(healthKitBridge.authorizationStatus())
    case "request":
      healthKitBridge.requestAuthorization { status in
        DispatchQueue.main.async { result(status) }
      }
    case "fetchRecentCardioWorkouts":
      let request = FetchCardioWorkoutsRequest(arguments: call.arguments as? [String: Any])
      healthKitBridge.fetchRecentCardioWorkouts(
        maxWorkouts: request.maxWorkouts,
        includeRoute: request.includeRoute,
        maxRoutePoints: request.maxRoutePoints,
        includeHeartRateSeries: request.includeHeartRateSeries
      ) { payload, error in
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(code: "fetch_workouts_failed", message: error.localizedDescription, details: nil))
            return
          }
          result(payload)
        }
      }
    case "countCardioWorkouts":
      healthKitBridge.countCardioWorkouts { count, error in
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(code: "count_failed", message: error.localizedDescription, details: nil))
            return
          }
          result(count as NSNumber)
        }
      }
    case "fetchRestingHeartRate":
      let isoDate = (call.arguments as? [String: Any])?["date"] as? String
      let targetDate = isoDate.flatMap { ISO8601DateFormatter().date(from: $0) }
      healthKitBridge.fetchRestingHeartRate(nearDate: targetDate) { bpm in
        DispatchQueue.main.async {
          result(bpm.map { $0 as NSNumber })
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleWatchMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startWorkout":
      guard let arguments = call.arguments as? [String: Any],
            let sessionId = arguments["sessionId"] as? String else {
        result(FlutterError(code: "invalid_args", message: "sessionId required", details: nil))
        return
      }
      let samplingIntervalSeconds = arguments["samplingIntervalSeconds"] as? Double ?? 5.0
      WatchSessionManager.shared.sendStartWorkout(
        sessionId: sessionId,
        samplingIntervalSeconds: samplingIntervalSeconds,
        result: result
      )
    case "stopWorkout":
      WatchSessionManager.shared.sendStopWorkout(result: result)
    case "pauseWorkout":
      WatchSessionManager.shared.sendPauseWorkout(result: result)
    case "resumeWorkout":
      WatchSessionManager.shared.sendResumeWorkout(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private struct FetchCardioWorkoutsRequest {
  let maxWorkouts: Int
  let includeRoute: Bool
  let maxRoutePoints: Int
  let includeHeartRateSeries: Bool

  init(arguments: [String: Any]?) {
    maxWorkouts = arguments?["maxWorkouts"] as? Int ?? 20
    includeRoute = arguments?["includeRoute"] as? Bool ?? false
    maxRoutePoints = arguments?["maxRoutePoints"] as? Int ?? 1500
    includeHeartRateSeries = arguments?["includeHeartRateSeries"] as? Bool ?? true
  }
}
