//
//  ContentView.swift
//  WorkoutsWatch Watch App
//
//  Created by Ethan Petuchowski on 1/19/26.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @ObservedObject private var connectivity = PhoneConnectivity.shared
    @ObservedObject private var workoutManager = WorkoutManager.shared
    @State private var hasRequestedAuth = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Connection status bar
            HStack {
                Circle()
                    .fill(connectivity.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(connectivity.isConnected ? "Phone" : "No Phone")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if let sessionId = connectivity.activeSessionId {
                    Text(sessionId.prefix(6) + "...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
            
            if workoutManager.isActive {
                // Active workout view
                WorkoutActiveView(workoutManager: workoutManager)
            } else {
                // Idle view
                WorkoutIdleView(connectivity: connectivity)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            connectivity.activate()
            requestHealthKitAuth()
        }
    }
    
    private func requestHealthKitAuth() {
        guard !hasRequestedAuth else { return }
        hasRequestedAuth = true
        Task {
            _ = await workoutManager.requestAuthorization()
        }
    }
}

/// Displayed when a workout is active
struct WorkoutActiveView: View {
    @ObservedObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 4) {
            // Heart rate display
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.title3)
                Text("\(workoutManager.currentHeartRate)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("BPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Calories
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text(String(format: "%.0f kcal", workoutManager.totalCalories))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 16) {
                if workoutManager.isPaused {
                    Button {
                        workoutManager.resumeWorkout()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button {
                        workoutManager.pauseWorkout()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                }
                
                Button {
                    workoutManager.stopWorkout()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }
}

/// Displayed when no workout is active
struct WorkoutIdleView: View {
    @ObservedObject var connectivity: PhoneConnectivity
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            
            if connectivity.activeSessionId != nil {
                Text("Workout starting...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Start a workout\non your iPhone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
