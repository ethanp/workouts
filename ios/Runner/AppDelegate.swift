import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let healthKitBridge = HealthKitBridge()
  private let heartRateStreamHandler = HeartRateStreamHandler()
  private let watchConnectivityStreamHandler = WatchConnectivityStreamHandler()

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
      heartRateHandler: heartRateStreamHandler
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
    case "fetchRecentRunningWorkouts":
      let request = FetchRunningWorkoutsRequest(arguments: call.arguments as? [String: Any])
      healthKitBridge.fetchRecentRunningWorkouts(
        maxWorkouts: request.maxWorkouts,
        includeRoute: request.includeRoute,
        maxRoutePoints: request.maxRoutePoints,
        includeHeartRateSeries: request.includeHeartRateSeries
      ) { payload, error in
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(code: "fetch_runs_failed", message: error.localizedDescription, details: nil))
            return
          }
          result(payload)
        }
      }
    case "countRunningWorkouts":
      healthKitBridge.countRunningWorkouts { count, error in
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(code: "count_failed", message: error.localizedDescription, details: nil))
            return
          }
          result(count as NSNumber)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleWatchMethodCall(call: FlutterMethodCall, result: FlutterResult) {
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
        samplingIntervalSeconds: samplingIntervalSeconds
      )
      result(nil)
    case "stopWorkout":
      WatchSessionManager.shared.sendStopWorkout()
      result(nil)
    case "pauseWorkout":
      WatchSessionManager.shared.sendPauseWorkout()
      result(nil)
    case "resumeWorkout":
      WatchSessionManager.shared.sendResumeWorkout()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private struct FetchRunningWorkoutsRequest {
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
