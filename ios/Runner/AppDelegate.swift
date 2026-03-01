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
        case "fetchRecentRunningWorkouts":
          let arguments = call.arguments as? [String: Any]
          let maxWorkouts = arguments?["maxWorkouts"] as? Int ?? 20
          let includeRoute = arguments?["includeRoute"] as? Bool ?? false
          let maxRoutePoints = arguments?["maxRoutePoints"] as? Int ?? 1500
          let includeHeartRateSeries = arguments?["includeHeartRateSeries"] as? Bool ?? true
          self.healthKitBridge.fetchRecentRunningWorkouts(
            maxWorkouts: maxWorkouts,
            includeRoute: includeRoute,
            maxRoutePoints: maxRoutePoints,
            includeHeartRateSeries: includeHeartRateSeries
          ) { payload, error in
            DispatchQueue.main.async {
              if let error {
                result(FlutterError(code: "fetch_runs_failed", message: error.localizedDescription, details: nil))
              } else {
                result(payload)
              }
            }
          }
        case "validateRunningWorkoutFields":
          let arguments = call.arguments as? [String: Any]
          let maxWorkouts = arguments?["maxWorkouts"] as? Int ?? 20
          self.healthKitBridge.validateRunningWorkoutFields(maxWorkouts: maxWorkouts) { payload, error in
            DispatchQueue.main.async {
              if let error {
                result(FlutterError(code: "validate_runs_failed", message: error.localizedDescription, details: nil))
              } else {
                result(payload)
              }
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
      
      // Watch workout control channel
      let watchChannel = FlutterMethodChannel(
        name: "com.workouts/watch_workout",
        binaryMessenger: messenger
      )
      watchChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "startWorkout":
          guard let args = call.arguments as? [String: Any],
                let sessionId = args["sessionId"] as? String else {
            result(FlutterError(code: "invalid_args", message: "sessionId required", details: nil))
            return
          }
          let interval = args["samplingIntervalSeconds"] as? Double ?? 5.0
          WatchSessionManager.shared.sendStartWorkout(sessionId: sessionId, samplingIntervalSeconds: interval)
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

    WatchSessionManager.shared.configureSession(
      connectivityHandler: watchConnectivityStreamHandler,
      heartRateHandler: heartRateStreamHandler
    )
    return didFinish
  }
}


final class HealthKitBridge {
  private let healthStore = HKHealthStore()
  private let dateFormatter = ISO8601DateFormatter()

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
          let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
          let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
          let flightsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else {
      completion("denied")
      return
    }

    let routeType = HKSeriesType.workoutRoute()
    let toShare: Set = [HKObjectType.workoutType(), heartRateType, energyType]
    let toRead: Set = [HKObjectType.workoutType(), heartRateType, energyType, distanceType, flightsType, routeType]
    healthStore.requestAuthorization(toShare: toShare, read: toRead) { [weak self] _, _ in
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

  func fetchRecentRunningWorkouts(
    maxWorkouts: Int,
    includeRoute: Bool,
    maxRoutePoints: Int,
    includeHeartRateSeries: Bool,
    completion: @escaping ([[String: Any]]?, Error?) -> Void
  ) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion([], nil)
      return
    }
    let workoutType = HKObjectType.workoutType()
    let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

    let query = HKSampleQuery(
      sampleType: workoutType,
      predicate: runningPredicate,
      limit: max(1, maxWorkouts),
      sortDescriptors: [sortDescriptor]
    ) { [weak self] _, samples, error in
      guard let self else {
        completion([], nil)
        return
      }
      if let error {
        completion(nil, error)
        return
      }
      let workouts = (samples as? [HKWorkout]) ?? []
      if workouts.isEmpty {
        completion([], nil)
        return
      }

      let dispatchGroup = DispatchGroup()
      var payloadByIndex = Array<[String: Any]?>(repeating: nil, count: workouts.count)

      for (index, workout) in workouts.enumerated() {
        dispatchGroup.enter()
        self.serializeRunningWorkout(
          workout: workout,
          includeRoute: includeRoute,
          maxRoutePoints: maxRoutePoints,
          includeHeartRateSeries: includeHeartRateSeries
        ) { payload in
          payloadByIndex[index] = payload
          dispatchGroup.leave()
        }
      }

      dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
        let payload = payloadByIndex.compactMap { $0 }
        completion(payload, nil)
      }
    }

    healthStore.execute(query)
  }

  func validateRunningWorkoutFields(
    maxWorkouts: Int,
    completion: @escaping ([String: Any]?, Error?) -> Void
  ) {
    fetchRecentRunningWorkouts(
      maxWorkouts: maxWorkouts,
      includeRoute: false,
      maxRoutePoints: 0,
      includeHeartRateSeries: true
    ) { workouts, error in
      if let error {
        completion(nil, error)
        return
      }
      let runPayloads = workouts ?? []
      let fieldNames = [
        "externalWorkoutId",
        "startDate",
        "endDate",
        "durationSeconds",
        "distanceMeters",
        "energyKcal",
        "avgHeartRateBpm",
        "maxHeartRateBpm",
        "heartRateSampleCount",
        "isIndoor",
        "routeAvailable",
        "sourceName",
        "deviceModel"
      ]

      var coverage: [String: [String: Int]] = [:]
      for fieldName in fieldNames {
        let presentCount = runPayloads.reduce(0) { count, payload in
          let rawValue = payload[fieldName]
          if let stringValue = rawValue as? String {
            return count + (stringValue.isEmpty ? 0 : 1)
          }
          if let numberValue = rawValue as? NSNumber {
            return count + (numberValue.doubleValue.isNaN ? 0 : 1)
          }
          if let listValue = rawValue as? [Any] {
            return count + (listValue.isEmpty ? 0 : 1)
          }
          return count + (rawValue == nil ? 0 : 1)
        }
        coverage[fieldName] = [
          "present": presentCount,
          "missing": max(0, runPayloads.count - presentCount)
        ]
      }

      let totalHeartRateSamples = runPayloads.reduce(0) { count, payload in
        count + ((payload["heartRateSampleCount"] as? Int) ?? 0)
      }
      let workoutsWithHeartRateSamples = runPayloads.reduce(0) { count, payload in
        count + ((((payload["heartRateSampleCount"] as? Int) ?? 0) > 0) ? 1 : 0)
      }

      let sampleWorkouts = Array(runPayloads.prefix(3))
      completion([
        "workoutCount": runPayloads.count,
        "fieldCoverage": coverage,
        "totalHeartRateSamples": totalHeartRateSamples,
        "workoutsWithHeartRateSamples": workoutsWithHeartRateSamples,
        "sampleWorkouts": sampleWorkouts
      ], nil)
    }
  }

  private func serializeRunningWorkout(
    workout: HKWorkout,
    includeRoute: Bool,
    maxRoutePoints: Int,
    includeHeartRateSeries: Bool,
    completion: @escaping ([String: Any]) -> Void
  ) {
    let dispatchGroup = DispatchGroup()
    var avgHeartRateBpm: Double?
    var maxHeartRateBpm: Double?
    var heartRateSeries: [[String: Any]]?
    var routePointCount: Int?
    var routePoints: [[String: Any]]?
    var routeAvailable = false

    dispatchGroup.enter()
    fetchHeartRateStats(for: workout) { average, maximum in
      avgHeartRateBpm = average
      maxHeartRateBpm = maximum
      dispatchGroup.leave()
    }

    if includeHeartRateSeries {
      dispatchGroup.enter()
      fetchHeartRateSeries(for: workout, maxSamples: 5000) { series in
        heartRateSeries = series
        dispatchGroup.leave()
      }
    }

    dispatchGroup.enter()
    checkRouteAvailability(for: workout) { hasRoute in
      routeAvailable = hasRoute
      if !includeRoute || !hasRoute {
        dispatchGroup.leave()
        return
      }
      self.fetchRoutePoints(for: workout, maxPoints: maxRoutePoints) { points, rawPointCount in
        routePoints = points
        routePointCount = rawPointCount
        dispatchGroup.leave()
      }
    }

    dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
      let distanceMeters = workout.totalDistance?.doubleValue(for: .meter())
      let energyKcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
      let sourceName = workout.sourceRevision.source.name
      let sourceBundleId = workout.sourceRevision.source.bundleIdentifier
      let deviceModel = workout.device?.model
      let metadata = workout.metadata ?? [:]
      let elevationAscended = metadata[HKMetadataKeyElevationAscended] as? Double
      let isIndoor = (metadata[HKMetadataKeyIndoorWorkout] as? NSNumber)?.boolValue

      var payload: [String: Any] = [
        "externalWorkoutId": workout.uuid.uuidString,
        "startDate": self.dateFormatter.string(from: workout.startDate),
        "endDate": self.dateFormatter.string(from: workout.endDate),
        "durationSeconds": Int(workout.duration),
        "distanceMeters": distanceMeters as Any,
        "energyKcal": energyKcal as Any,
        "avgHeartRateBpm": avgHeartRateBpm as Any,
        "maxHeartRateBpm": maxHeartRateBpm as Any,
        "heartRateSampleCount": heartRateSeries?.count ?? 0,
        "isIndoor": isIndoor as Any,
        "routeAvailable": routeAvailable,
        "sourceName": sourceName,
        "sourceBundleId": sourceBundleId,
        "deviceModel": deviceModel as Any,
        "elevationAscendedMeters": elevationAscended as Any
      ]
      if includeRoute {
        payload["routePointCount"] = routePointCount as Any
        payload["routePoints"] = routePoints ?? []
      }
      if includeHeartRateSeries {
        payload["heartRateSeries"] = heartRateSeries ?? []
      }
      completion(payload)
    }
  }

  private func fetchHeartRateStats(
    for workout: HKWorkout,
    completion: @escaping (Double?, Double?) -> Void
  ) {
    guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      completion(nil, nil)
      return
    }
    let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
    let options: HKStatisticsOptions = [.discreteAverage, .discreteMax]

    let query = HKStatisticsQuery(
      quantityType: heartRateType,
      quantitySamplePredicate: predicate,
      options: options
    ) { _, statistics, _ in
      let average = statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
      let maximum = statistics?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
      completion(average, maximum)
    }
    healthStore.execute(query)
  }

  private func fetchHeartRateSeries(
    for workout: HKWorkout,
    maxSamples: Int,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      completion([])
      return
    }
    let predicate = HKQuery.predicateForSamples(
      withStart: workout.startDate,
      end: workout.endDate,
      options: .strictStartDate
    )
    let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
    let query = HKSampleQuery(
      sampleType: heartRateType,
      predicate: predicate,
      limit: max(1, maxSamples),
      sortDescriptors: sortDescriptors
    ) { [weak self] _, samples, _ in
      guard let self else {
        completion([])
        return
      }
      let heartRateSamples = (samples as? [HKQuantitySample]) ?? []
      let points = heartRateSamples.map { sample in
        let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        return [
          "timestamp": self.dateFormatter.string(from: sample.startDate),
          "bpm": bpm
        ]
      }
      completion(points)
    }
    healthStore.execute(query)
  }

  private func checkRouteAvailability(for workout: HKWorkout, completion: @escaping (Bool) -> Void) {
    let predicate = HKQuery.predicateForObjects(from: workout)
    let query = HKAnchoredObjectQuery(
      type: HKSeriesType.workoutRoute(),
      predicate: predicate,
      anchor: nil,
      limit: 1
    ) { _, samples, _, _, _ in
      completion(!(samples?.isEmpty ?? true))
    }
    healthStore.execute(query)
  }

  private func fetchRoutePoints(
    for workout: HKWorkout,
    maxPoints: Int,
    completion: @escaping ([[String: Any]], Int?) -> Void
  ) {
    let predicate = HKQuery.predicateForObjects(from: workout)
    let routeQuery = HKAnchoredObjectQuery(
      type: HKSeriesType.workoutRoute(),
      predicate: predicate,
      anchor: nil,
      limit: 1
    ) { [weak self] _, samples, _, _, error in
      guard let self else {
        completion([], nil)
        return
      }
      if error != nil {
        completion([], nil)
        return
      }
      guard let route = samples?.first as? HKWorkoutRoute else {
        completion([], nil)
        return
      }
      var routePointsPayload: [[String: Any]] = []
      let query = HKWorkoutRouteQuery(route: route) { _, locations, done, _ in
        if let locations {
          for location in locations {
            routePointsPayload.append([
              "lat": location.coordinate.latitude,
              "lng": location.coordinate.longitude,
              "altitudeMeters": location.altitude,
              "timestamp": self.dateFormatter.string(from: location.timestamp)
            ])
          }
        }
        if done {
          let rawPointCount = routePointsPayload.count
          let maxAllowedPoints = max(0, maxPoints)
          let normalizedPoints = self.downsampleRoutePoints(
            routePointsPayload,
            maxPoints: maxAllowedPoints
          )
          completion(normalizedPoints, rawPointCount)
        }
      }
      self.healthStore.execute(query)
    }
    healthStore.execute(routeQuery)
  }

  private func downsampleRoutePoints(
    _ routePoints: [[String: Any]],
    maxPoints: Int
  ) -> [[String: Any]] {
    if maxPoints <= 0 || routePoints.count <= maxPoints {
      return routePoints
    }
    if maxPoints == 1 {
      return [routePoints.first!]
    }

    let lastIndex = routePoints.count - 1
    var selectedPoints: [[String: Any]] = []
    selectedPoints.reserveCapacity(maxPoints)

    for pointIndex in 0..<maxPoints {
      let mappedIndex = Int(round(Double(pointIndex) * Double(lastIndex) / Double(maxPoints - 1)))
      selectedPoints.append(routePoints[mappedIndex])
    }
    return selectedPoints
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

  private weak var connectivityHandler: WatchConnectivityStreamHandler?
  private weak var heartRateHandler: HeartRateStreamHandler?
  private let dateFormatter = ISO8601DateFormatter()

  private override init() {
    super.init()
  }

  func configureSession(
    connectivityHandler: WatchConnectivityStreamHandler,
    heartRateHandler: HeartRateStreamHandler
  ) {
    self.connectivityHandler = connectivityHandler
    self.heartRateHandler = heartRateHandler
    guard WCSession.isSupported() else {
      connectivityHandler.send(isConnected: false)
      return
    }
    let session = WCSession.default
    session.delegate = self
    session.activate()
    publishConnectionState(for: session)
  }

  private func publishConnectionState(for session: WCSession) {
    let connected = session.isPaired && session.activationState == .activated
    connectivityHandler?.send(isConnected: connected)
  }

  private func canSendMessages(on session: WCSession) -> Bool {
    guard session.activationState == .activated else {
      return false
    }
    return session.isReachable
  }
  
  // MARK: - Send commands to watch
  
  func sendStartWorkout(sessionId: String, samplingIntervalSeconds: Double = 5.0) {
    let session = WCSession.default
    guard canSendMessages(on: session) else {
      print("[WatchSession] Watch not reachable, cannot send startWorkout")
      return
    }
    let message: [String: Any] = [
      "command": "startWorkout",
      "sessionId": sessionId,
      "samplingIntervalSeconds": samplingIntervalSeconds
    ]
    session.sendMessage(message, replyHandler: nil) { error in
      print("[WatchSession] Failed to send startWorkout: \(error.localizedDescription)")
    }
  }
  
  func sendStopWorkout() {
    let session = WCSession.default
    guard canSendMessages(on: session) else {
      print("[WatchSession] Watch not reachable, cannot send stopWorkout")
      return
    }
    session.sendMessage(["command": "stopWorkout"], replyHandler: nil) { error in
      print("[WatchSession] Failed to send stopWorkout: \(error.localizedDescription)")
    }
  }
  
  func sendPauseWorkout() {
    let session = WCSession.default
    guard canSendMessages(on: session) else { return }
    session.sendMessage(["command": "pauseWorkout"], replyHandler: nil, errorHandler: nil)
  }
  
  func sendResumeWorkout() {
    let session = WCSession.default
    guard canSendMessages(on: session) else { return }
    session.sendMessage(["command": "resumeWorkout"], replyHandler: nil, errorHandler: nil)
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    publishConnectionState(for: session)
  }

  func sessionDidBecomeInactive(_ session: WCSession) {
    publishConnectionState(for: session)
  }

  func sessionDidDeactivate(_ session: WCSession) {
    connectivityHandler?.send(isConnected: false)
    session.activate()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    publishConnectionState(for: session)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    if let samples = message["samples"] as? [[String: Any]] {
      samples.forEach { sendHeartRateSample($0) }
      return
    }
    if let sample = message["sample"] as? [String: Any] {
      sendHeartRateSample(sample)
      return
    }
    sendHeartRateSample(message)
  }

  private func sendHeartRateSample(_ payload: [String: Any]) {
    guard let bpm = payload["bpm"] as? Int else { return }
    let sessionId = payload["sessionId"] as? String ?? "unknown"
    let source = payload["source"] as? String ?? "watch"
    let energyKcal = payload["energyKcal"] as? Double

    let timestamp: String
    if let raw = payload["timestamp"] as? String {
      timestamp = raw
    } else {
      timestamp = dateFormatter.string(from: Date())
    }

    heartRateHandler?.send(sample: [
      "id": payload["id"] as? String ?? UUID().uuidString,
      "sessionId": sessionId,
      "timestamp": timestamp,
      "bpm": bpm,
      "energyKcal": energyKcal as Any,
      "source": source
    ])
  }
}
