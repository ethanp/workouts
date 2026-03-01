import Foundation
import HealthKit

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
