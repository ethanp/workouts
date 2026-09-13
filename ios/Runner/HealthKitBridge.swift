import Foundation
import HealthKit

final class HealthKitBridge {
  private let healthStore = HKHealthStore()
  private let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

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
      if status.rawValue == 3 {
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
    healthStore.requestAuthorization(toShare: shareTypes(), read: readTypes()) { [weak self] _, _ in
      guard let self else {
        completion("unknown")
        return
      }
      completion(self.authorizationStatus())
    }
  }

  func shareStatusBySignal() -> [[String: Any]] {
    var rows: [[String: Any]] = inspectableQuantityIdentifiers().map { identifier in
      shareStatusRow(
        id: identifier.rawValue,
        objectType: HKQuantityType.quantityType(forIdentifier: identifier)
      )
    }
    rows.append(contentsOf: inspectableCategoryTypes().map { categoryType in
      shareStatusRow(id: categoryType.identifier, objectType: categoryType)
    })
    rows.append(contentsOf: inspectableSeriesTypes().map { seriesType in
      shareStatusRow(id: seriesType.identifier, objectType: seriesType)
    })
    return rows
  }

  private func shareStatusRow(id: String, objectType: HKObjectType?) -> [String: Any] {
    let shareStatus: String
    if let objectType {
      shareStatus = shareStatusName(healthStore.authorizationStatus(for: objectType))
    } else {
      shareStatus = "unavailable"
    }
    return [
      "id": id,
      "shareStatus": shareStatus,
      "note": "HealthKit reports share permission only; read denial is not visible to apps.",
    ]
  }

  private static let cardioActivityTypes: [HKWorkoutActivityType] = [
    .running, .walking, .elliptical, .stairClimbing, .rowing
  ]

  func countCardioWorkouts(completion: @escaping (Int, Error?) -> Void) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(0, nil)
      return
    }
    let query = HKSampleQuery(
      sampleType: .workoutType(),
      predicate: cardioWorkoutPredicate(),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: nil
    ) { _, samples, error in
      if let error {
        completion(0, error)
        return
      }
      completion((samples as? [HKWorkout])?.count ?? 0, nil)
    }
    healthStore.execute(query)
  }

  func fetchRecentCardioWorkouts(
    maxWorkouts: Int,
    includeRoute: Bool,
    maxRoutePoints: Int,
    includeHeartRateSeries: Bool,
    includeAssociatedSeries: Bool,
    onProgress: @escaping ([String: Any]) -> Void,
    onWorkout: @escaping ([String: Any]) -> Void,
    completion: @escaping (Int?, Error?) -> Void
  ) {
    onProgress([
      "caption": "Asking Apple Health for workouts…",
      "completedWorkouts": 0,
      "totalWorkouts": 0,
    ])
    loadRecentCardioWorkouts(maxWorkouts: maxWorkouts) { [weak self] workouts, error in
      guard let self else {
        completion(0, nil)
        return
      }
      if let error {
        completion(nil, error)
        return
      }
      if workouts.isEmpty {
        onProgress([
          "caption": "No cardio workouts found.",
          "completedWorkouts": 0,
          "totalWorkouts": 0,
        ])
        completion(0, nil)
        return
      }
      onProgress([
        "caption": "Found \(workouts.count) workouts. Reading each one…",
        "completedWorkouts": 0,
        "totalWorkouts": workouts.count,
      ])
      self.serializeWorkoutsOneByOne(
        workouts,
        includeRoute: includeRoute,
        maxRoutePoints: maxRoutePoints,
        includeHeartRateSeries: includeHeartRateSeries,
        includeAssociatedSeries: includeAssociatedSeries,
        onProgress: onProgress,
        onWorkout: onWorkout
      ) {
        completion(workouts.count, nil)
      }
    }
  }

  func inspectRecentCardioWorkouts(
    maxWorkouts: Int,
    onProgress: @escaping ([String: Any]) -> Void,
    completion: @escaping ([String: Any]?, Error?) -> Void
  ) {
    onProgress([
      "caption": "Loading last \(maxWorkouts) cardio workouts…",
      "completedWorkouts": 0,
      "totalWorkouts": maxWorkouts,
    ])
    loadRecentCardioWorkouts(maxWorkouts: maxWorkouts) { [weak self] workouts, error in
      guard let self else {
        completion(["workouts": [], "requestedTypes": []], nil)
        return
      }
      if let error {
        completion(nil, error)
        return
      }
      if workouts.isEmpty {
        onProgress([
          "caption": "No cardio workouts found.",
          "completedWorkouts": 0,
          "totalWorkouts": 0,
        ])
        completion(
          [
            "requestedTypes": self.shareStatusBySignal(),
            "queriedQuantityTypes": self.inspectableQuantityIdentifiers().map(\.rawValue),
            "queriedCategoryTypes": self.inspectableCategoryIdentifiers().map(\.rawValue),
            "workouts": [],
          ],
          nil
        )
        return
      }
      self.serializeInspectWorkouts(workouts, onProgress: onProgress) { payloads, serializeError in
        if let serializeError {
          completion(nil, serializeError)
          return
        }
        onProgress([
          "caption": "Reading Health share status…",
          "completedWorkouts": workouts.count,
          "totalWorkouts": workouts.count,
        ])
        completion(
          [
            "requestedTypes": self.shareStatusBySignal(),
            "queriedQuantityTypes": self.inspectableQuantityIdentifiers().map(\.rawValue),
            "queriedCategoryTypes": self.inspectableCategoryIdentifiers().map(\.rawValue),
            "workouts": payloads ?? [],
          ],
          nil
        )
      }
    }
  }

  private func serializeInspectWorkouts(
    _ workouts: [HKWorkout],
    onProgress: @escaping ([String: Any]) -> Void,
    completion: @escaping ([[String: Any]]?, Error?) -> Void
  ) {
    var payloads: [[String: Any]] = []
    func inspectNext(_ index: Int) {
      if index >= workouts.count {
        completion(payloads, nil)
        return
      }
      let workout = workouts[index]
      onProgress([
        "caption": self.inspectCaption(workout: workout, index: index, total: workouts.count),
        "completedWorkouts": index,
        "totalWorkouts": workouts.count,
      ])
      serializeCardioWorkout(
        workout: workout,
        includeRoute: false,
        maxRoutePoints: 0,
        includeHeartRateSeries: false,
        includeAssociatedSeries: false,
        inspectSignals: true
      ) { payload in
        payloads.append(payload)
        onProgress([
          "caption": self.inspectCaption(workout: workout, index: index, total: workouts.count),
          "completedWorkouts": index + 1,
          "totalWorkouts": workouts.count,
        ])
        inspectNext(index + 1)
      }
    }
    inspectNext(0)
  }

  private func inspectCaption(workout: HKWorkout, index: Int, total: Int) -> String {
    let activity = activityTypeKey(for: workout)
    let sourceName = workout.sourceRevision.source.name
    return "Inspecting \(activity) · \(sourceName) (\(index + 1) of \(total))"
  }

  private func loadRecentCardioWorkouts(
    maxWorkouts: Int,
    completion: @escaping ([HKWorkout], Error?) -> Void
  ) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion([], nil)
      return
    }
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: cardioWorkoutPredicate(),
      limit: maxWorkouts <= 0 ? HKObjectQueryNoLimit : max(1, maxWorkouts),
      sortDescriptors: [sortDescriptor]
    ) { _, samples, error in
      if let error {
        completion([], error)
        return
      }
      completion((samples as? [HKWorkout]) ?? [], nil)
    }
    healthStore.execute(query)
  }

  private func serializeWorkoutsOneByOne(
    _ workouts: [HKWorkout],
    includeRoute: Bool,
    maxRoutePoints: Int,
    includeHeartRateSeries: Bool,
    includeAssociatedSeries: Bool,
    onProgress: @escaping ([String: Any]) -> Void,
    onWorkout: @escaping ([String: Any]) -> Void,
    completion: @escaping () -> Void
  ) {
    func serializeNext(_ index: Int) {
      if index >= workouts.count {
        onProgress([
          "caption": "Finished reading \(workouts.count) workouts.",
          "completedWorkouts": workouts.count,
          "totalWorkouts": workouts.count,
          "importFinished": true,
        ])
        completion()
        return
      }
      let workout = workouts[index]
      let activity = activityTypeKey(for: workout)
      onProgress([
        "caption": "Reading \(activity) (\(index + 1) of \(workouts.count))",
        "completedWorkouts": index,
        "totalWorkouts": workouts.count,
      ])
      serializeCardioWorkout(
        workout: workout,
        includeRoute: includeRoute,
        maxRoutePoints: maxRoutePoints,
        includeHeartRateSeries: includeHeartRateSeries,
        includeAssociatedSeries: includeAssociatedSeries,
        inspectSignals: false
      ) { payload in
        onWorkout(payload)
        onProgress([
          "caption": "Read \(activity) (\(index + 1) of \(workouts.count))",
          "completedWorkouts": index + 1,
          "totalWorkouts": workouts.count,
        ])
        serializeNext(index + 1)
      }
    }
    serializeNext(0)
  }

  private func cardioWorkoutPredicate() -> NSPredicate {
    let predicates = Self.cardioActivityTypes.map {
      HKQuery.predicateForWorkouts(with: $0)
    }
    return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
  }

  private func activityTypeKey(for workout: HKWorkout) -> String {
    let isIndoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? NSNumber)?.boolValue ?? false
    switch workout.workoutActivityType {
    case .running: return isIndoor ? "indoorRun" : "outdoorRun"
    case .walking: return isIndoor ? "indoorWalk" : "outdoorWalk"
    case .elliptical: return "elliptical"
    case .stairClimbing: return "stairClimbing"
    case .rowing: return "rowing"
    default: return "outdoorRun"
    }
  }

  private func serializeCardioWorkout(
    workout: HKWorkout,
    includeRoute: Bool,
    maxRoutePoints: Int,
    includeHeartRateSeries: Bool,
    includeAssociatedSeries: Bool,
    inspectSignals: Bool,
    completion: @escaping ([String: Any]) -> Void
  ) {
    let dispatchGroup = DispatchGroup()
    var avgHeartRateBpm: Double?
    var maxHeartRateBpm: Double?
    var heartRateSeries: [[String: Any]] = []
    var distanceSeries: [[String: Any]] = []
    var stepSeries: [[String: Any]] = []
    var routePointCount: Int?
    var routePoints: [[String: Any]]?
    var routeAvailable = false
    var recoveryBpm: Double?
    var effortScore: Double?
    var estimatedEffortScore: Double?
    var signalSummaries: [[String: Any]] = []
    var heartRateHasCondensed = false
    var distanceHasCondensed = false
    var stepHasCondensed = false

    dispatchGroup.enter()
    fetchHeartRateStats(for: workout) { average, maximum in
      avgHeartRateBpm = average
      maxHeartRateBpm = maximum
      dispatchGroup.leave()
    }

    if includeHeartRateSeries {
      dispatchGroup.enter()
      fetchAssociatedQuantitySeries(
        for: workout,
        identifier: .heartRate,
        unit: HKUnit.count().unitDivided(by: .minute()),
        maxSamples: 5000
      ) { series, hasCondensed in
        heartRateSeries = series
        heartRateHasCondensed = hasCondensed
        dispatchGroup.leave()
      }
    }

    if includeAssociatedSeries {
      dispatchGroup.enter()
      fetchAssociatedQuantitySeries(
        for: workout,
        identifier: .distanceWalkingRunning,
        unit: .meter(),
        maxSamples: 5000
      ) { series, hasCondensed in
        distanceSeries = series
        distanceHasCondensed = hasCondensed
        dispatchGroup.leave()
      }
      dispatchGroup.enter()
      fetchAssociatedQuantitySeries(
        for: workout,
        identifier: .stepCount,
        unit: .count(),
        maxSamples: 5000
      ) { series, hasCondensed in
        stepSeries = series
        stepHasCondensed = hasCondensed
        dispatchGroup.leave()
      }
    }

    dispatchGroup.enter()
    fetchRecoveryBpm(for: workout) { recovery in
      recoveryBpm = recovery
      dispatchGroup.leave()
    }

    dispatchGroup.enter()
    fetchEffortScores(for: workout) { perceived, estimated in
      effortScore = perceived
      estimatedEffortScore = estimated
      dispatchGroup.leave()
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

    if inspectSignals {
      dispatchGroup.enter()
      inspectAssociatedSignals(for: workout) { summaries in
        signalSummaries = summaries
        dispatchGroup.leave()
      }
    }

    dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
      completion(self.workoutPayload(
        workout: workout,
        avgHeartRateBpm: avgHeartRateBpm,
        maxHeartRateBpm: maxHeartRateBpm,
        heartRateSeries: heartRateSeries,
        heartRateHasCondensed: heartRateHasCondensed,
        distanceSeries: distanceSeries,
        distanceHasCondensed: distanceHasCondensed,
        stepSeries: stepSeries,
        stepHasCondensed: stepHasCondensed,
        routeAvailable: routeAvailable,
        routePoints: routePoints,
        routePointCount: routePointCount,
        recoveryBpm: recoveryBpm,
        effortScore: effortScore,
        estimatedEffortScore: estimatedEffortScore,
        includeRoute: includeRoute,
        includeHeartRateSeries: includeHeartRateSeries,
        includeAssociatedSeries: includeAssociatedSeries,
        inspectSignals: inspectSignals,
        signalSummaries: signalSummaries
      ))
    }
  }

  private func workoutPayload(
    workout: HKWorkout,
    avgHeartRateBpm: Double?,
    maxHeartRateBpm: Double?,
    heartRateSeries: [[String: Any]],
    heartRateHasCondensed: Bool,
    distanceSeries: [[String: Any]],
    distanceHasCondensed: Bool,
    stepSeries: [[String: Any]],
    stepHasCondensed: Bool,
    routeAvailable: Bool,
    routePoints: [[String: Any]]?,
    routePointCount: Int?,
    recoveryBpm: Double?,
    effortScore: Double?,
    estimatedEffortScore: Double?,
    includeRoute: Bool,
    includeHeartRateSeries: Bool,
    includeAssociatedSeries: Bool,
    inspectSignals: Bool,
    signalSummaries: [[String: Any]]
  ) -> [String: Any] {
    let metadata = workout.metadata ?? [:]
    var payload: [String: Any] = [
      "externalWorkoutId": workout.uuid.uuidString,
      "activityType": activityTypeKey(for: workout),
      "startDate": dateFormatter.string(from: workout.startDate),
      "endDate": dateFormatter.string(from: workout.endDate),
      "durationSeconds": Int(workout.duration),
      "distanceMeters": displayedDistanceMeters(workout, metadata: metadata),
      "energyKcal": workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) as Any,
      "basalEnergyKcal": statisticSum(
        workout,
        identifier: .basalEnergyBurned,
        unit: .kilocalorie()
      ) as Any,
      "avgHeartRateBpm": avgHeartRateBpm as Any,
      "maxHeartRateBpm": maxHeartRateBpm as Any,
      "minHeartRateBpm": statisticMin(
        workout,
        identifier: .heartRate,
        unit: HKUnit.count().unitDivided(by: .minute())
      ) as Any,
      "averageMets": averageMets(from: metadata) as Any,
      "fitnessMachineDurationSeconds": fitnessMachineDurationSeconds(from: metadata) as Any,
      "crossTrainerDistanceMeters": metadataQuantityMeters(
        metadata,
        key: HKMetadataKeyCrossTrainerDistance
      ) as Any,
      "indoorBikeDistanceMeters": metadataQuantityMeters(
        metadata,
        key: HKMetadataKeyIndoorBikeDistance
      ) as Any,
      "stepCount": statisticSum(workout, identifier: .stepCount, unit: .count()) as Any,
      "flightsClimbed": statisticSum(
        workout,
        identifier: .flightsClimbed,
        unit: .count()
      ) as Any,
      "heartRateSampleCount": heartRateSeries.count,
      "heartRateHasCondensed": heartRateHasCondensed,
      "routeAvailable": routeAvailable,
      "sourceName": workout.sourceRevision.source.name,
      "sourceBundleId": workout.sourceRevision.source.bundleIdentifier,
      "deviceName": workout.device?.name as Any,
      "deviceModel": workout.device?.model as Any,
      "elevationAscendedMeters": elevationAscendedMeters(from: metadata) as Any,
      "recoveryBpm": recoveryBpm as Any,
      "effortScore": effortScore as Any,
      "estimatedEffortScore": estimatedEffortScore as Any,
      "machineLinked": isMachineLinked(workout),
      "metadataKeys": metadata.keys.sorted(),
      "events": workoutEventsPayload(workout),
    ]
    if includeRoute {
      payload["routePointCount"] = routePointCount as Any
      payload["routePoints"] = routePoints ?? []
    }
    if includeHeartRateSeries {
      payload["heartRateSeries"] = heartRateSeries
    }
    if includeAssociatedSeries {
      payload["distanceSeries"] = distanceSeries
      payload["distanceHasCondensed"] = distanceHasCondensed
      payload["stepSeries"] = stepSeries
      payload["stepHasCondensed"] = stepHasCondensed
    }
    if inspectSignals {
      payload["signals"] = signalSummaries
      payload["statistics"] = workoutStatisticsPayload(workout)
      payload["metadata"] = metadataStringMap(metadata)
      payload["activities"] = workoutActivitiesPayload(workout)
    }
    return payload
  }

  private func fetchHeartRateStats(
    for workout: HKWorkout,
    completion: @escaping (Double?, Double?) -> Void
  ) {
    if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
       let statistics = workout.statistics(for: heartRateType) {
      let unit = HKUnit.count().unitDivided(by: .minute())
      completion(
        statistics.averageQuantity()?.doubleValue(for: unit),
        statistics.maximumQuantity()?.doubleValue(for: unit)
      )
      return
    }
    fetchAssociatedQuantitySeries(
      for: workout,
      identifier: .heartRate,
      unit: HKUnit.count().unitDivided(by: .minute()),
      maxSamples: 5000
    ) { series, _ in
      let values = series.compactMap { sample in sample["value"] as? Double }
      guard !values.isEmpty else {
        completion(nil, nil)
        return
      }
      completion(values.reduce(0, +) / Double(values.count), values.max())
    }
  }

  private func fetchAssociatedQuantitySeries(
    for workout: HKWorkout,
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    maxSamples: Int,
    completion: @escaping ([[String: Any]], Bool) -> Void
  ) {
    guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
      completion([], false)
      return
    }
    let query = HKSampleQuery(
      sampleType: quantityType,
      predicate: HKQuery.predicateForObjects(from: workout),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
    ) { [weak self] _, samples, _ in
      guard let self else {
        completion([], false)
        return
      }
      let quantitySamples = (samples as? [HKQuantitySample]) ?? []
      self.expandQuantitySamples(quantitySamples, unit: unit, maxSamples: maxSamples, completion: completion)
    }
    healthStore.execute(query)
  }

  private func expandQuantitySamples(
    _ samples: [HKQuantitySample],
    unit: HKUnit,
    maxSamples: Int,
    completion: @escaping ([[String: Any]], Bool) -> Void
  ) {
    let condensedSamples = samples.filter { $0.count > 1 }
    if condensedSamples.isEmpty {
      completion(Array(samples.prefix(maxSamples).map { quantitySamplePayload($0, unit: unit) }), false)
      return
    }
    let collectQueue = DispatchQueue(label: "com.workouts.healthkit.series")
    let dispatchGroup = DispatchGroup()
    var expanded: [[String: Any]] = []
    for sample in samples {
      if sample.count <= 1 {
        let payload = quantitySamplePayload(sample, unit: unit)
        collectQueue.sync { expanded.append(payload) }
        continue
      }
      dispatchGroup.enter()
      let seriesQuery = HKQuantitySeriesSampleQuery(
        quantityType: sample.quantityType,
        predicate: HKQuery.predicateForObject(with: sample.uuid)
      ) { _, quantity, dateInterval, _, done, _ in
        if let quantity, let dateInterval {
          let payload: [String: Any] = [
            "timestamp": self.dateFormatter.string(from: dateInterval.start),
            "endTimestamp": self.dateFormatter.string(from: dateInterval.end),
            "value": quantity.doubleValue(for: unit),
            "bpm": quantity.doubleValue(for: unit),
          ]
          collectQueue.sync { expanded.append(payload) }
        }
        if done {
          dispatchGroup.leave()
        }
      }
      healthStore.execute(seriesQuery)
    }
    dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
      let sorted = collectQueue.sync { expanded }.sorted {
        ($0["timestamp"] as? String ?? "") < ($1["timestamp"] as? String ?? "")
      }
      completion(Array(sorted.prefix(maxSamples)), true)
    }
  }

  private func quantitySamplePayload(_ sample: HKQuantitySample, unit: HKUnit) -> [String: Any] {
    let value = sample.quantity.doubleValue(for: unit)
    return [
      "timestamp": dateFormatter.string(from: sample.startDate),
      "endTimestamp": dateFormatter.string(from: sample.endDate),
      "value": value,
      "bpm": value,
    ]
  }

  private func inspectAssociatedSignals(
    for workout: HKWorkout,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    let quantityTypes = quantityTypesToInspect(for: workout)
    let categoryTypes = inspectableCategoryTypes()
    let seriesTypes = inspectableSeriesTypes()
    let collectQueue = DispatchQueue(label: "com.workouts.healthkit.inspect")
    let dispatchGroup = DispatchGroup()
    var summaries: [[String: Any]] = []

    func appendSummary(
      type: String,
      sampleCount: Int,
      hasCondensed: Bool,
      coverageSeconds: Int,
      kind: String
    ) {
      if sampleCount <= 0 { return }
      collectQueue.sync {
        summaries.append([
          "type": type,
          "sampleCount": sampleCount,
          "hasCondensed": hasCondensed,
          "coverageSeconds": coverageSeconds,
          "associated": true,
          "kind": kind,
        ])
      }
    }

    for quantityType in quantityTypes {
      dispatchGroup.enter()
      let query = HKSampleQuery(
        sampleType: quantityType,
        predicate: HKQuery.predicateForObjects(from: workout),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
      ) { _, samples, _ in
        let quantitySamples = (samples as? [HKQuantitySample]) ?? []
        appendSummary(
          type: quantityType.identifier,
          sampleCount: quantitySamples.count,
          hasCondensed: quantitySamples.contains { $0.count > 1 },
          coverageSeconds: self.coverageSeconds(quantitySamples, workout: workout),
          kind: "quantity"
        )
        dispatchGroup.leave()
      }
      healthStore.execute(query)
    }

    for categoryType in categoryTypes {
      dispatchGroup.enter()
      let query = HKSampleQuery(
        sampleType: categoryType,
        predicate: HKQuery.predicateForObjects(from: workout),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, _ in
        let categorySamples = (samples as? [HKCategorySample]) ?? []
        appendSummary(
          type: categoryType.identifier,
          sampleCount: categorySamples.count,
          hasCondensed: false,
          coverageSeconds: 0,
          kind: "category"
        )
        dispatchGroup.leave()
      }
      healthStore.execute(query)
    }

    for seriesType in seriesTypes {
      dispatchGroup.enter()
      let query = HKSampleQuery(
        sampleType: seriesType,
        predicate: HKQuery.predicateForObjects(from: workout),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, _ in
        appendSummary(
          type: seriesType.identifier,
          sampleCount: samples?.count ?? 0,
          hasCondensed: false,
          coverageSeconds: 0,
          kind: "series"
        )
        dispatchGroup.leave()
      }
      healthStore.execute(query)
    }

    dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
      let sorted = collectQueue.sync { summaries }.sorted {
        ($0["type"] as? String ?? "") < ($1["type"] as? String ?? "")
      }
      completion(sorted)
    }
  }

  private func coverageSeconds(_ samples: [HKQuantitySample], workout: HKWorkout) -> Int {
    guard let first = samples.first, let last = samples.last else { return 0 }
    let covered = last.endDate.timeIntervalSince(first.startDate)
    return Int(max(0, min(covered, workout.duration)))
  }

  private func fetchRecoveryBpm(
    for workout: HKWorkout,
    completion: @escaping (Double?) -> Void
  ) {
    guard let recoveryType = HKQuantityType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) else {
      completion(nil)
      return
    }
    let associated = HKQuery.predicateForObjects(from: workout)
    let nearby = HKQuery.predicateForSamples(
      withStart: workout.endDate.addingTimeInterval(-60),
      end: workout.endDate.addingTimeInterval(15 * 60),
      options: .strictStartDate
    )
    let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [associated, nearby])
    let query = HKSampleQuery(
      sampleType: recoveryType,
      predicate: predicate,
      limit: 8,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
    ) { _, samples, _ in
      let recoverySamples = (samples as? [HKQuantitySample]) ?? []
      let nearest = recoverySamples.min {
        abs($0.startDate.timeIntervalSince(workout.endDate)) <
          abs($1.startDate.timeIntervalSince(workout.endDate))
      }
      completion(nearest?.quantity.doubleValue(for: .count()))
    }
    healthStore.execute(query)
  }

  private func fetchEffortScores(
    for workout: HKWorkout,
    completion: @escaping (Double?, Double?) -> Void
  ) {
    let dispatchGroup = DispatchGroup()
    var perceived: Double?
    var estimated: Double?
    dispatchGroup.enter()
    fetchLatestAssociatedQuantity(
      for: workout,
      identifier: .workoutEffortScore,
      unit: .count()
    ) { value in
      perceived = value
      dispatchGroup.leave()
    }
    dispatchGroup.enter()
    fetchLatestAssociatedQuantity(
      for: workout,
      identifier: .estimatedWorkoutEffortScore,
      unit: .count()
    ) { value in
      estimated = value
      dispatchGroup.leave()
    }
    dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
      completion(perceived, estimated)
    }
  }

  private func fetchLatestAssociatedQuantity(
    for workout: HKWorkout,
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    completion: @escaping (Double?) -> Void
  ) {
    guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
      completion(nil)
      return
    }
    let query = HKSampleQuery(
      sampleType: quantityType,
      predicate: HKQuery.predicateForObjects(from: workout),
      limit: 1,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
    ) { _, samples, _ in
      let sample = (samples as? [HKQuantitySample])?.first
      completion(sample?.quantity.doubleValue(for: unit))
    }
    healthStore.execute(query)
  }

  private func checkRouteAvailability(for workout: HKWorkout, completion: @escaping (Bool) -> Void) {
    let query = HKAnchoredObjectQuery(
      type: HKSeriesType.workoutRoute(),
      predicate: HKQuery.predicateForObjects(from: workout),
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
    let routeQuery = HKAnchoredObjectQuery(
      type: HKSeriesType.workoutRoute(),
      predicate: HKQuery.predicateForObjects(from: workout),
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
          completion(
            self.downsampleRoutePoints(routePointsPayload, maxPoints: max(0, maxPoints)),
            rawPointCount
          )
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

  private func displayedDistanceMeters(
    _ workout: HKWorkout,
    metadata: [String: Any]
  ) -> Double {
    if let walkingRunningMeters = workout.totalDistance?.doubleValue(for: .meter()),
       walkingRunningMeters > 0 {
      return walkingRunningMeters
    }
    if let crossTrainerMeters = metadataQuantityMeters(
      metadata,
      key: HKMetadataKeyCrossTrainerDistance
    ), crossTrainerMeters > 0 {
      return crossTrainerMeters
    }
    if let indoorBikeMeters = metadataQuantityMeters(
      metadata,
      key: HKMetadataKeyIndoorBikeDistance
    ), indoorBikeMeters > 0 {
      return indoorBikeMeters
    }
    return 0
  }

  private func elevationAscendedMeters(from metadata: [String: Any]) -> Double? {
    metadataQuantityMeters(metadata, key: HKMetadataKeyElevationAscended)
  }

  private func averageMets(from metadata: [String: Any]) -> Double? {
    guard let quantity = metadata[HKMetadataKeyAverageMETs] as? HKQuantity else {
      return metadata[HKMetadataKeyAverageMETs] as? Double
    }
    let metsUnit = HKUnit.kilocalorie().unitDivided(
      by: HKUnit.hour().unitMultiplied(by: HKUnit.gramUnit(with: .kilo))
    )
    guard quantity.is(compatibleWith: metsUnit) else { return nil }
    return quantity.doubleValue(for: metsUnit)
  }

  private func fitnessMachineDurationSeconds(from metadata: [String: Any]) -> Double? {
    metadataQuantity(metadata, key: HKMetadataKeyFitnessMachineDuration, unit: .second())
  }

  private func metadataQuantityMeters(
    _ metadata: [String: Any],
    key: String
  ) -> Double? {
    metadataQuantity(metadata, key: key, unit: .meter())
  }

  private func metadataQuantity(
    _ metadata: [String: Any],
    key: String,
    unit: HKUnit
  ) -> Double? {
    if let quantity = metadata[key] as? HKQuantity, quantity.is(compatibleWith: unit) {
      return quantity.doubleValue(for: unit)
    }
    return metadata[key] as? Double
  }

  private func statisticSum(
    _ workout: HKWorkout,
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit
  ) -> Double? {
    guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier),
          let statistics = workout.statistics(for: quantityType) else {
      return nil
    }
    return statistics.sumQuantity()?.doubleValue(for: unit)
  }

  private func statisticMin(
    _ workout: HKWorkout,
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit
  ) -> Double? {
    guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier),
          let statistics = workout.statistics(for: quantityType) else {
      return nil
    }
    return statistics.minimumQuantity()?.doubleValue(for: unit)
  }

  private func workoutEventsPayload(_ workout: HKWorkout) -> [[String: Any]] {
    (workout.workoutEvents ?? []).map { event in
      [
        "type": eventTypeName(event.type),
        "timestamp": dateFormatter.string(from: event.dateInterval.start),
        "endTimestamp": dateFormatter.string(from: event.dateInterval.end),
        "metadata": metadataStringMap(event.metadata ?? [:]),
      ]
    }
  }

  private func workoutStatisticsPayload(_ workout: HKWorkout) -> [[String: Any]] {
    return workout.allStatistics.values
      .map { statisticsRow($0, source: "workoutStatistics") }
      .sorted { ($0["type"] as? String ?? "") < ($1["type"] as? String ?? "") }
  }

  private func workoutActivitiesPayload(_ workout: HKWorkout) -> [[String: Any]] {
    return workout.workoutActivities.map { activity in
      [
        "activityType": workoutActivityTypeName(activity.workoutConfiguration.activityType),
        "activityTypeRaw": activity.workoutConfiguration.activityType.rawValue,
        "startDate": dateFormatter.string(from: activity.startDate),
        "endDate": activity.endDate.map { dateFormatter.string(from: $0) } as Any,
        "durationSeconds": Int(activity.duration),
        "metadata": metadataStringMap(activity.metadata ?? [:]),
        "statistics": activity.allStatistics.values
          .map { statisticsRow($0, source: "activityStatistics") }
          .sorted { ($0["type"] as? String ?? "") < ($1["type"] as? String ?? "") },
      ]
    }
  }

  private func statisticsRow(_ statistics: HKStatistics, source: String) -> [String: Any] {
    var row: [String: Any] = [
      "type": statistics.quantityType.identifier,
      "source": source,
    ]
    if let unit = displayUnit(for: statistics) {
      row["unit"] = unit.unitString
      if let average = statistics.averageQuantity() {
        row["average"] = average.doubleValue(for: unit)
      }
      if let minimum = statistics.minimumQuantity() {
        row["min"] = minimum.doubleValue(for: unit)
      }
      if let maximum = statistics.maximumQuantity() {
        row["max"] = maximum.doubleValue(for: unit)
      }
      if let sum = statistics.sumQuantity() {
        row["sum"] = sum.doubleValue(for: unit)
      }
      if let mostRecent = statistics.mostRecentQuantity() {
        row["mostRecent"] = mostRecent.doubleValue(for: unit)
      }
    }
    return row
  }

  private func displayUnit(for statistics: HKStatistics) -> HKUnit? {
    let probe = statistics.averageQuantity()
      ?? statistics.sumQuantity()
      ?? statistics.minimumQuantity()
      ?? statistics.maximumQuantity()
      ?? statistics.mostRecentQuantity()
    guard let probe else { return nil }
    return Self.inventoryUnitCandidates.first { probe.is(compatibleWith: $0) }
  }

  private static let inventoryUnitCandidates: [HKUnit] = [
    HKUnit.count().unitDivided(by: .minute()),
    HKUnit.count().unitDivided(by: .second()),
    HKUnit.meter().unitDivided(by: .second()),
    HKUnit.meter(),
    HKUnit.kilocalorie(),
    HKUnit.smallCalorie(),
    HKUnit.watt(),
    HKUnit.count(),
    HKUnit.percent(),
    HKUnit(from: "mL/kg*min"),
    HKUnit(from: "kcal/(kg*hr)"),
    HKUnit.degreeCelsius(),
    HKUnit.degreeFahrenheit(),
    HKUnit.atmosphere(),
    HKUnit.pascal(),
    HKUnit.second(),
    HKUnit.minute(),
    HKUnit.hour(),
    HKUnit.pound(),
    HKUnit.gram(),
    HKUnit.decibelAWeightedSoundPressureLevel(),
    HKUnit.internationalUnit(),
  ]

  private func metadataStringMap(_ metadata: [String: Any]) -> [String: String] {
    var values: [String: String] = [:]
    for (key, value) in metadata {
      values[key] = stringifyMetadataValue(value)
    }
    return values
  }

  private func stringifyMetadataValue(_ value: Any) -> String {
    if let quantity = value as? HKQuantity {
      return quantity.description
    }
    if let date = value as? Date {
      return dateFormatter.string(from: date)
    }
    if let number = value as? NSNumber {
      return number.stringValue
    }
    return String(describing: value)
  }

  private func workoutActivityTypeName(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .running: return "running"
    case .walking: return "walking"
    case .elliptical: return "elliptical"
    case .stairClimbing: return "stairClimbing"
    case .rowing: return "rowing"
    case .cycling: return "cycling"
    case .hiking: return "hiking"
    case .coreTraining: return "coreTraining"
    case .flexibility: return "flexibility"
    case .highIntensityIntervalTraining: return "highIntensityIntervalTraining"
    case .jumpRope: return "jumpRope"
    default: return "type_\(type.rawValue)"
    }
  }

  private func eventTypeName(_ type: HKWorkoutEventType) -> String {
    switch type {
    case .pause: return "pause"
    case .resume: return "resume"
    case .lap: return "lap"
    case .marker: return "marker"
    case .motionPaused: return "motionPaused"
    case .motionResumed: return "motionResumed"
    case .segment: return "segment"
    case .pauseOrResumeRequest: return "pauseOrResumeRequest"
    @unknown default: return "other"
    }
  }

  private func isMachineLinked(_ workout: HKWorkout) -> Bool {
    let metadata = workout.metadata ?? [:]
    if metadata[HKMetadataKeyFitnessMachineDuration] != nil {
      return true
    }
    if metadata[HKMetadataKeyCrossTrainerDistance] != nil {
      return true
    }
    if metadata[HKMetadataKeyIndoorBikeDistance] != nil {
      return true
    }
    let deviceModel = (workout.device?.model ?? "").lowercased()
    return deviceModel.contains("fitnessmachinemodel")
  }

  private func readTypes() -> Set<HKObjectType> {
    var types: Set<HKObjectType> = [HKObjectType.workoutType()]
    for identifier in inspectableQuantityIdentifiers() {
      if let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) {
        types.insert(quantityType)
      }
    }
    types.formUnion(inspectableCategoryTypes())
    types.formUnion(inspectableSeriesTypes())
    return types
  }

  private func quantityTypesToInspect(for workout: HKWorkout) -> [HKQuantityType] {
    var typesByIdentifier: [String: HKQuantityType] = [:]
    for identifier in inspectableQuantityIdentifiers() {
      if let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) {
        typesByIdentifier[quantityType.identifier] = quantityType
      }
    }
    for quantityType in workout.allStatistics.keys {
      typesByIdentifier[quantityType.identifier] = quantityType
    }
    for activity in workout.workoutActivities {
      for quantityType in activity.allStatistics.keys {
        typesByIdentifier[quantityType.identifier] = quantityType
      }
    }
    return typesByIdentifier.values.sorted { $0.identifier < $1.identifier }
  }

  private func inspectableCategoryTypes() -> [HKCategoryType] {
    inspectableCategoryIdentifiers().compactMap { HKCategoryType.categoryType(forIdentifier: $0) }
  }

  private func inspectableSeriesTypes() -> [HKSeriesType] {
    var seriesTypes = [HKSeriesType.workoutRoute()]
    seriesTypes.append(HKSeriesType.heartbeat())
    return seriesTypes
  }

  private func inspectableCategoryIdentifiers() -> [HKCategoryTypeIdentifier] {
    [
      .mindfulSession,
      .sleepAnalysis,
      .highHeartRateEvent,
      .lowHeartRateEvent,
      .irregularHeartRhythmEvent,
      .appleStandHour,
      .lowCardioFitnessEvent,
      .appleWalkingSteadinessEvent,
      .hypertensionEvent,
      .sleepApneaEvent,
      .environmentalAudioExposureEvent,
      .headphoneAudioExposureEvent,
    ]
  }

  private func shareTypes() -> Set<HKSampleType> {
    var types: Set<HKSampleType> = [HKObjectType.workoutType()]
    if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
      types.insert(heartRate)
    }
    if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
      types.insert(energy)
    }
    return types
  }

  private func inspectableQuantityIdentifiers() -> [HKQuantityTypeIdentifier] {
    [
      .heartRate,
      .restingHeartRate,
      .walkingHeartRateAverage,
      .heartRateVariabilitySDNN,
      .heartRateRecoveryOneMinute,
      .activeEnergyBurned,
      .basalEnergyBurned,
      .distanceWalkingRunning,
      .distanceCycling,
      .distanceSwimming,
      .distanceWheelchair,
      .distanceDownhillSnowSports,
      .distanceCrossCountrySkiing,
      .distancePaddleSports,
      .distanceRowing,
      .distanceSkatingSports,
      .stepCount,
      .flightsClimbed,
      .nikeFuel,
      .pushCount,
      .swimmingStrokeCount,
      .vo2Max,
      .respiratoryRate,
      .oxygenSaturation,
      .appleExerciseTime,
      .appleStandTime,
      .appleMoveTime,
      .walkingSpeed,
      .walkingStepLength,
      .walkingAsymmetryPercentage,
      .walkingDoubleSupportPercentage,
      .stairAscentSpeed,
      .stairDescentSpeed,
      .sixMinuteWalkTestDistance,
      .appleWalkingSteadiness,
      .runningSpeed,
      .runningPower,
      .runningStrideLength,
      .runningVerticalOscillation,
      .runningGroundContactTime,
      .cyclingSpeed,
      .cyclingCadence,
      .cyclingPower,
      .cyclingFunctionalThresholdPower,
      .physicalEffort,
      .timeInDaylight,
      .workoutEffortScore,
      .estimatedWorkoutEffortScore,
      .crossCountrySkiingSpeed,
      .paddleSportsSpeed,
      .rowingSpeed,
      .environmentalAudioExposure,
      .environmentalSoundReduction,
      .headphoneAudioExposure,
      .bodyTemperature,
      .basalBodyTemperature,
      .appleSleepingWristTemperature,
      .bloodPressureSystolic,
      .bloodPressureDiastolic,
      .bloodGlucose,
      .bodyMass,
      .bodyMassIndex,
      .bodyFatPercentage,
      .leanBodyMass,
      .height,
      .waistCircumference,
      .electrodermalActivity,
      .peripheralPerfusionIndex,
      .dietaryEnergyConsumed,
      .dietaryWater,
      .numberOfTimesFallen,
      .numberOfAlcoholicBeverages,
      .uvExposure,
      .insulinDelivery,
      .forcedExpiratoryVolume1,
      .forcedVitalCapacity,
      .peakExpiratoryFlowRate,
      .inhalerUsage,
      .underwaterDepth,
      .waterTemperature,
      .atrialFibrillationBurden,
      .appleSleepingBreathingDisturbances,
    ]
  }

  private func shareStatusName(_ status: HKAuthorizationStatus) -> String {
    switch status {
    case .sharingAuthorized: return "sharingAuthorized"
    case .sharingDenied: return "sharingDenied"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unknown"
    }
  }
}
