import Flutter
import HealthKit
import WatchConnectivity
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

        switch call.method {
        case "status":
          result(self.healthKitBridge.authorizationStatus())
        case "request":
          self.healthKitBridge.requestAuthorization { status in
            DispatchQueue.main.async {
              result(status)
            }
          }
        case "deleteWorkouts":
          guard let arguments = call.arguments as? [String: Any],
                let uuids = arguments["uuids"] as? [String] else {
            result(FlutterError(code: "invalid_args", message: "Expected uuids array", details: nil))
            return
          }
          self.healthKitBridge.delete(workoutUUIDs: uuids) { success, error in
            DispatchQueue.main.async {
              if let error {
                result(FlutterError(code: "delete_failed", message: error.localizedDescription, details: nil))
              } else {
                result(success)
              }
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      FlutterEventChannel(
        name: "com.workouts/heart_rate_stream",
        binaryMessenger: messenger
      ).setStreamHandler(heartRateStreamHandler)

      FlutterEventChannel(
        name: "com.workouts/watch_connectivity",
        binaryMessenger: messenger
      ).setStreamHandler(watchConnectivityStreamHandler)
    }

    WatchSessionManager.shared.configureSession(streamHandler: watchConnectivityStreamHandler)
    return didFinish
  }
}


final class HealthKitBridge {
  private let healthStore = HKHealthStore()

  func authorizationStatus() -> String {
    guard HKHealthStore.isHealthDataAvailable() else {
      return "unavailable"
    }
    guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      return "denied"
    }
    let status = healthStore.authorizationStatus(for: heartRateType)
    switch status {
    case .sharingAuthorized:
      return "authorized"
    case .sharingDenied:
      return "denied"
    default:
      if #available(iOS 14.0, *), status.rawValue == 3 {
        return "limited"
      }
      return "unknown"
    }
  }

  func requestAuthorization(completion: @escaping (String) -> Void) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion("unavailable")
      return
    }
    guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
          let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
      completion("denied")
      return
    }

    let toShare: Set = [HKObjectType.workoutType(), heartRateType, energyType]
    healthStore.requestAuthorization(toShare: toShare, read: toShare) { [weak self] _, _ in
      guard let self else {
        completion("unknown")
        return
      }
      completion(self.authorizationStatus())
    }
  }

  func delete(workoutUUIDs: [String], completion: @escaping (Bool, Error?) -> Void) {
    let uuids = workoutUUIDs.compactMap(UUID.init(uuidString:))
    guard !uuids.isEmpty else {
      completion(true, nil)
      return
    }

    let predicate = HKQuery.predicateForObjects(with: Set(uuids))
    healthStore.deleteObjects(of: .workoutType(), predicate: predicate) { success, _, error in
      completion(success, error)
    }
  }
}

final class HeartRateStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func send(sample: [String: Any]) {
    eventSink?(sample)
  }
}

final class WatchConnectivityStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    events(false)
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func send(isConnected: Bool) {
    eventSink?(isConnected)
  }
}

final class WatchSessionManager: NSObject, WCSessionDelegate {
  static let shared = WatchSessionManager()

  private weak var streamHandler: WatchConnectivityStreamHandler?

  private override init() {
    super.init()
  }

  func configureSession(streamHandler: WatchConnectivityStreamHandler) {
    self.streamHandler = streamHandler
    guard WCSession.isSupported() else {
      streamHandler.send(isConnected: false)
      return
    }
    let session = WCSession.default
    session.delegate = self
    session.activate()
    publishConnectionState(for: session)
  }

  private func publishConnectionState(for session: WCSession) {
    let connected = session.isPaired && session.activationState == .activated
    streamHandler?.send(isConnected: connected)
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    publishConnectionState(for: session)
  }

  func sessionDidBecomeInactive(_ session: WCSession) {
    publishConnectionState(for: session)
  }

  func sessionDidDeactivate(_ session: WCSession) {
    streamHandler?.send(isConnected: false)
    session.activate()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    publishConnectionState(for: session)
  }
}
