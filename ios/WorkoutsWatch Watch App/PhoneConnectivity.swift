//
//  PhoneConnectivity.swift
//  WorkoutsWatch Watch App
//

import Combine
import Foundation
import WatchConnectivity

/// Handles communication with the iPhone app via WatchConnectivity.
final class PhoneConnectivity: NSObject, ObservableObject {
    static let shared = PhoneConnectivity()
    
    @Published private(set) var isConnected = false
    @Published private(set) var activeSessionId: String?
    @Published private(set) var samplingIntervalSeconds: TimeInterval = 5.0
    
    private override init() {
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else {
            isConnected = false
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    /// Send a heart rate sample to the phone.
    func sendHeartRateSample(
        id: String,
        sessionId: String,
        bpm: Int,
        timestamp: Date,
        energyKcal: Double?,
        source: String = "watch"
    ) {
        guard WCSession.default.isReachable else { return }
        
        let formatter = ISO8601DateFormatter()
        var payload: [String: Any] = [
            "id": id,
            "sessionId": sessionId,
            "bpm": bpm,
            "timestamp": formatter.string(from: timestamp),
            "source": source
        ]
        if let energy = energyKcal {
            payload["energyKcal"] = energy
        }
        
        WCSession.default.sendMessage(["sample": payload], replyHandler: nil) { error in
            print("Failed to send HR sample: \(error.localizedDescription)")
        }
    }
    
    /// Send buffered samples (e.g., after reconnect).
    func sendBufferedSamples(_ samples: [[String: Any]]) {
        guard WCSession.default.isReachable, !samples.isEmpty else { return }
        WCSession.default.sendMessage(["samples": samples], replyHandler: nil) { error in
            print("Failed to send buffered samples: \(error.localizedDescription)")
        }
    }
}

extension PhoneConnectivity: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated && session.isReachable
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let command = message["command"] as? String {
                switch command {
                case "startWorkout":
                    self.activeSessionId = message["sessionId"] as? String
                    NotificationCenter.default.post(name: .startWorkout, object: nil, userInfo: message)
                case "stopWorkout":
                    self.activeSessionId = nil
                    NotificationCenter.default.post(name: .stopWorkout, object: nil)
                case "pauseWorkout":
                    NotificationCenter.default.post(name: .pauseWorkout, object: nil)
                case "resumeWorkout":
                    NotificationCenter.default.post(name: .resumeWorkout, object: nil)
                default:
                    break
                }
            }
            if let interval = message["samplingIntervalSeconds"] as? TimeInterval {
                self.samplingIntervalSeconds = interval
            }
        }
    }
}

extension Notification.Name {
    static let startWorkout = Notification.Name("startWorkout")
    static let stopWorkout = Notification.Name("stopWorkout")
    static let pauseWorkout = Notification.Name("pauseWorkout")
    static let resumeWorkout = Notification.Name("resumeWorkout")
}
