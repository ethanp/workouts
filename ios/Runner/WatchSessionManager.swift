import Foundation
import WatchConnectivity

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
