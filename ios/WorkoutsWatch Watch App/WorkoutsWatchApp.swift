//
//  WorkoutsWatchApp.swift
//  WorkoutsWatch Watch App
//

import SwiftUI

@main
struct WorkoutsWatchApp: App {
    init() {
        // Initialize singletons early to receive notifications
        PhoneConnectivity.shared.activate()
        _ = WorkoutManager.shared  // Ensure notification observers are registered
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
