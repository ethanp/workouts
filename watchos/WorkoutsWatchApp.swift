import SwiftUI

@main
struct WorkoutsWatchApp: App {
  @StateObject private var sessionManager = WatchSessionManager()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(sessionManager)
    }
  }
}
