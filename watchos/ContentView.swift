import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var sessionManager: WatchSessionManager

  var body: some View {
    VStack(spacing: 12) {
      Text(sessionManager.displayTitle)
        .font(.headline)
      Text(sessionManager.displaySubtitle)
        .font(.footnote)
        .foregroundColor(.gray)
      HStack(spacing: 16) {
        Button(action: sessionManager.toggleWorkout) {
          Label(sessionManager.isWorkoutActive ? "End" : "Start", systemImage: sessionManager.isWorkoutActive ? "stop.circle" : "play.circle")
            .font(.title2)
        }
        Button(action: sessionManager.togglePause) {
          Label(sessionManager.isPaused ? "Resume" : "Pause", systemImage: sessionManager.isPaused ? "play.fill" : "pause")
        }
      }
      .buttonStyle(.bordered)
      .tint(.blue)
      Text("\(sessionManager.currentHeartRate) BPM")
        .font(.largeTitle)
        .bold()
        .padding(.top, 8)
      Spacer()
    }
    .padding()
    .onAppear(perform: sessionManager.configure)
  }
}
