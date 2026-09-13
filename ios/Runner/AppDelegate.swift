import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let healthKitBridge = HealthKitBridge()
  private let healthInventoryProgressStreamHandler = HealthInventoryProgressStreamHandler()
  private let healthImportStreamHandler = HealthInventoryProgressStreamHandler()
  private let heartRateStreamHandler = HeartRateStreamHandler()
  private let watchConnectivityStreamHandler = WatchConnectivityStreamHandler()
  private let watchCommandStreamHandler = WatchCommandStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications so the foreground app can
    // receive UNNotificationCenter callbacks (interval-timer alerts when
    // the screen is locked but the app technically still active).
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    WatchSessionManager.shared.configureSession(
      connectivityHandler: watchConnectivityStreamHandler,
      heartRateHandler: heartRateStreamHandler,
      watchCommandHandler: watchCommandStreamHandler
    )
    return didFinish
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

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
      name: "com.workouts/health_inventory_progress",
      binaryMessenger: messenger
    ).setStreamHandler(healthInventoryProgressStreamHandler)

    FlutterEventChannel(
      name: "com.workouts/health_import",
      binaryMessenger: messenger
    ).setStreamHandler(healthImportStreamHandler)

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

  private func handleHealthKitMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(healthKitBridge.authorizationStatus())
    case "request":
      healthKitBridge.requestAuthorization { status in
        DispatchQueue.main.async { result(status) }
      }
    case "inspectRecentCardioWorkouts":
      let maxWorkouts = (call.arguments as? [String: Any])?["maxWorkouts"] as? Int ?? 40
      healthKitBridge.inspectRecentCardioWorkouts(
        maxWorkouts: maxWorkouts,
        onProgress: { [weak self] payload in
          self?.healthInventoryProgressStreamHandler.send(payload)
        }
      ) { payload, error in
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(code: "inspect_workouts_failed", message: error.localizedDescription, details: nil))
            return
          }
          result(payload)
        }
      }
    case "fetchRecentCardioWorkouts":
      let request = FetchCardioWorkoutsRequest(arguments: call.arguments as? [String: Any])
      healthKitBridge.fetchRecentCardioWorkouts(
        maxWorkouts: request.maxWorkouts,
        includeRoute: request.includeRoute,
        maxRoutePoints: request.maxRoutePoints,
        includeHeartRateSeries: request.includeHeartRateSeries,
        includeAssociatedSeries: request.includeAssociatedSeries,
        onProgress: { [weak self] payload in
          self?.healthImportStreamHandler.send(payload)
        },
        onWorkout: { [weak self] workout in
          self?.healthImportStreamHandler.send(["workout": workout])
        }
      ) { count, error in
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(code: "fetch_workouts_failed", message: error.localizedDescription, details: nil))
            return
          }
          result(count as NSNumber?)
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
  let includeAssociatedSeries: Bool

  init(arguments: [String: Any]?) {
    maxWorkouts = arguments?["maxWorkouts"] as? Int ?? 20
    includeRoute = arguments?["includeRoute"] as? Bool ?? false
    maxRoutePoints = arguments?["maxRoutePoints"] as? Int ?? 1500
    includeHeartRateSeries = arguments?["includeHeartRateSeries"] as? Bool ?? true
    includeAssociatedSeries = arguments?["includeAssociatedSeries"] as? Bool ?? true
  }
}
