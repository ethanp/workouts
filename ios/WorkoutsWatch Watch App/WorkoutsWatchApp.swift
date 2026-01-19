//
//  WorkoutsWatchApp.swift
//  WorkoutsWatch Watch App
//

import SwiftUI

@main
struct WorkoutsWatchApp: App {
    init() {
        // Activate Watch Connectivity early
        PhoneConnectivity.shared.activate()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
