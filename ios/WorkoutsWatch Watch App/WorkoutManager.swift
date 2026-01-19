//
//  WorkoutManager.swift
//  WorkoutsWatch Watch App
//

import Combine
import Foundation
import HealthKit

/// Manages an HKWorkoutSession to stream live heart rate data.
final class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var currentHeartRate: Int = 0
    @Published private(set) var isActive = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var totalCalories: Double = 0
    
    private var sessionId: String = ""
    private var sampleBuffer: [[String: Any]] = []
    private var samplingTimer: Timer?
    
    private override init() {
        super.init()
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartWorkout(_:)),
            name: .startWorkout,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopWorkout),
            name: .stopWorkout,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePauseWorkout),
            name: .pauseWorkout,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResumeWorkout),
            name: .resumeWorkout,
            object: nil
        )
    }
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }
    
    @objc private func handleStartWorkout(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let sessionId = userInfo["sessionId"] as? String else { return }
        startWorkout(sessionId: sessionId)
    }
    
    @objc private func handleStopWorkout() {
        stopWorkout()
    }
    
    @objc private func handlePauseWorkout() {
        pauseWorkout()
    }
    
    @objc private func handleResumeWorkout() {
        resumeWorkout()
    }
    
    func startWorkout(sessionId: String) {
        self.sessionId = sessionId
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { [weak self] success, error in
                if success {
                    DispatchQueue.main.async {
                        self?.isActive = true
                        self?.isPaused = false
                        self?.elapsedSeconds = 0
                        self?.startSamplingTimer()
                    }
                }
            }
        } catch {
            print("Failed to start workout: \(error)")
        }
    }
    
    func stopWorkout() {
        samplingTimer?.invalidate()
        samplingTimer = nil
        
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] success, error in
            self?.workoutBuilder?.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    self?.isActive = false
                    self?.isPaused = false
                    self?.currentHeartRate = 0
                    self?.flushBuffer()
                }
            }
        }
    }
    
    func pauseWorkout() {
        workoutSession?.pause()
        isPaused = true
    }
    
    func resumeWorkout() {
        workoutSession?.resume()
        isPaused = false
    }
    
    private func startSamplingTimer() {
        samplingTimer?.invalidate()
        let interval = PhoneConnectivity.shared.samplingIntervalSeconds
        samplingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendCurrentHeartRate()
        }
    }
    
    private func sendCurrentHeartRate() {
        guard currentHeartRate > 0, !sessionId.isEmpty else { return }
        
        let sample: [String: Any] = [
            "id": UUID().uuidString,
            "sessionId": sessionId,
            "bpm": currentHeartRate,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "energyKcal": totalCalories,
            "source": "watch"
        ]
        
        if PhoneConnectivity.shared.isConnected {
            PhoneConnectivity.shared.sendHeartRateSample(
                id: sample["id"] as! String,
                sessionId: sessionId,
                bpm: currentHeartRate,
                timestamp: Date(),
                energyKcal: totalCalories
            )
        } else {
            sampleBuffer.append(sample)
        }
    }
    
    private func flushBuffer() {
        guard !sampleBuffer.isEmpty else { return }
        PhoneConnectivity.shared.sendBufferedSamples(sampleBuffer)
        sampleBuffer.removeAll()
    }
    
    private func updateHeartRate(from statistics: HKStatistics?) {
        guard let statistics = statistics,
              let quantity = statistics.mostRecentQuantity() else { return }
        let bpm = Int(quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        DispatchQueue.main.async {
            self.currentHeartRate = bpm
        }
    }
    
    private func updateCalories(from statistics: HKStatistics?) {
        guard let statistics = statistics,
              let quantity = statistics.sumQuantity() else { return }
        let kcal = quantity.doubleValue(for: .kilocalorie())
        DispatchQueue.main.async {
            self.totalCalories = kcal
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isActive = true
                self.isPaused = false
            case .paused:
                self.isPaused = true
            case .ended:
                self.isActive = false
                self.isPaused = false
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            switch quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                updateHeartRate(from: statistics)
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                updateCalories(from: statistics)
            default:
                break
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}
