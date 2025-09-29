import Combine
import HealthKit
import WatchConnectivity

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var currentHeartRate: Int = 0
  @Published private(set) var isWorkoutActive = false
  @Published private(set) var isPaused = false

  private let healthStore = HKHealthStore()
  private var workoutSession: HKWorkoutSession?
  private var workoutBuilder: HKLiveWorkoutBuilder?
  private var heartRateQuery: HKAnchoredObjectQuery?

  func configure() {
    configureConnectivity()
    requestHealthAuthorization()
  }

  var displayTitle: String {
    isWorkoutActive ? (isPaused ? "Workout paused" : "Workout active") : "Ready to train"
  }

  var displaySubtitle: String {
    isWorkoutActive ? "Streaming heart rate" : "Connect from the phone to begin"
  }

  func toggleWorkout() {
    if isWorkoutActive {
      endWorkout()
    } else {
      startWorkout()
    }
  }

  func togglePause() {
    guard isWorkoutActive else { return }
    if isPaused {
      resumeWorkout()
    } else {
      pauseWorkout()
    }
  }

  private func configureConnectivity() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  private func requestHealthAuthorization() {
    guard HKHealthStore.isHealthDataAvailable(),
          let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
          let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
      return
    }
    let types: Set = [HKObjectType.workoutType(), heartRateType, energyType]
    healthStore.requestAuthorization(toShare: types, read: types) { _, _ in }
  }

  private func startWorkout() {
    guard let configuration = workoutConfiguration() else { return }
    do {
      workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
      workoutBuilder = workoutSession?.associatedWorkoutBuilder()
      workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
      workoutSession?.delegate = self
      workoutBuilder?.delegate = self
      let startDate = Date()
      workoutSession?.startActivity(with: startDate)
      workoutBuilder?.beginCollection(withStart: startDate) { [weak self] success, _ in
        if success {
          self?.isWorkoutActive = true
          self?.isPaused = false
          self?.beginHeartRateQuery()
        }
      }
    } catch {
      print("Unable to start workout: \(error.localizedDescription)")
    }
  }

  private func pauseWorkout() {
    workoutSession?.pause()
    isPaused = true
  }

  private func resumeWorkout() {
    workoutSession?.resume()
    isPaused = false
  }

  private func endWorkout() {
    workoutSession?.end()
    workoutBuilder?.endCollection(withEnd: Date()) { [weak self] success, _ in
      guard success else { return }
      self?.workoutBuilder?.finishWorkout { _, _ in }
    }
    isWorkoutActive = false
    isPaused = false
    currentHeartRate = 0
    if let query = heartRateQuery {
      healthStore.stop(query)
    }
  }

  private func beginHeartRateQuery() {
    guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
    let query = HKAnchoredObjectQuery(type: heartRateType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
      self?.handle(samples: samples)
    }

    query.updateHandler = { [weak self] _, samples, _, _, _ in
      self?.handle(samples: samples)
    }

    heartRateQuery = query
    healthStore.execute(query)
  }

  private func handle(samples: [HKSample]?) {
    guard let quantitySamples = samples as? [HKQuantitySample], let sample = quantitySamples.last else {
      return
    }
    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
    let value = Int(sample.quantity.doubleValue(for: heartRateUnit).rounded())
    DispatchQueue.main.async {
      self.currentHeartRate = value
    }
  }

  private func workoutConfiguration() -> HKWorkoutConfiguration? {
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .functionalStrengthTraining
    configuration.locationType = .indoor
    return configuration
  }

  // MARK: - WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

  func sessionReachabilityDidChange(_ session: WCSession) {}

  func session(_ session: WCSession, didReceiveMessageData messageData: Data) {}
}

extension WatchSessionManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
  func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    DispatchQueue.main.async {
      switch toState {
      case .paused:
        self.isPaused = true
      case .running:
        self.isWorkoutActive = true
        self.isPaused = false
      case .ended, .stopped:
        self.isWorkoutActive = false
        self.isPaused = false
      default:
        break
      }
    }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    print("Workout session failed: \(error.localizedDescription)")
  }

  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

  func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}
}
