import Foundation
import WatchConnectivity

final class WatchSessionManager: NSObject, WCSessionDelegate {
  static let shared = WatchSessionManager()

  private weak var connectivityHandler: WatchConnectivityStreamHandler?
  private weak var heartRateHandler: HeartRateStreamHandler?
  private weak var watchCommandHandler: WatchCommandStreamHandler?
  private let dateFormatter = ISO8601DateFormatter()

  private override init() {
    super.init()
  }

  func configureSession(
    connectivityHandler: WatchConnectivityStreamHandler,
    heartRateHandler: HeartRateStreamHandler,
    watchCommandHandler: WatchCommandStreamHandler
  ) {
    self.connectivityHandler = connectivityHandler
    self.heartRateHandler = heartRateHandler
    self.watchCommandHandler = watchCommandHandler
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

  func sendStartWorkout(sessionId: String, samplingIntervalSeconds: Double = 5.0, result: @escaping FlutterResult) {
    let session = WCSession.default
    guard canSendMessages(on: session) else {
      result(FlutterError(code: "watch_unreachable", message: "Watch is not reachable", details: nil))
      return
    }
    let message: [String: Any] = [
      "command": "startWorkout",
      "sessionId": sessionId,
      "samplingIntervalSeconds": samplingIntervalSeconds
    ]
    session.sendMessage(message, replyHandler: { _ in result(nil) }) { error in
      result(FlutterError(code: "watch_send_failed", message: error.localizedDescription, details: nil))
    }
  }

  func sendStopWorkout(result: @escaping FlutterResult) {
    let session = WCSession.default
    guard canSendMessages(on: session) else {
      result(FlutterError(code: "watch_unreachable", message: "Watch is not reachable", details: nil))
      return
    }
    session.sendMessage(["command": "stopWorkout"], replyHandler: { _ in result(nil) }) { error in
      result(FlutterError(code: "watch_send_failed", message: error.localizedDescription, details: nil))
    }
  }

  func sendPauseWorkout(result: @escaping FlutterResult) {
    let session = WCSession.default
    guard canSendMessages(on: session) else {
      result(FlutterError(code: "watch_unreachable", message: "Watch is not reachable", details: nil))
      return
    }
    session.sendMessage(["command": "pauseWorkout"], replyHandler: { _ in result(nil) }) { error in
      result(FlutterError(code: "watch_send_failed", message: error.localizedDescription, details: nil))
    }
  }

  func sendResumeWorkout(result: @escaping FlutterResult) {
    let session = WCSession.default
    guard canSendMessages(on: session) else {
      result(FlutterError(code: "watch_unreachable", message: "Watch is not reachable", details: nil))
      return
    }
    session.sendMessage(["command": "resumeWorkout"], replyHandler: { _ in result(nil) }) { error in
      result(FlutterError(code: "watch_send_failed", message: error.localizedDescription, details: nil))
    }
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
    if let command = message["command"] as? String {
      watchCommandHandler?.send(command: command)
      return
    }
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
