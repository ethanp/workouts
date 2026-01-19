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
    
    var body: some View {
        VStack(spacing: 12) {
            // Connection status
            HStack {
                Circle()
                    .fill(connectivity.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(connectivity.isConnected ? "Phone Reachable" : "Phone Not Reachable")
                    .font(.caption)
            }
            
            Divider()
            
            if let sessionId = connectivity.activeSessionId {
                Text("Session: \(sessionId.prefix(8))...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("No active session")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            connectivity.activate()
        }
    }
}

#Preview {
    ContentView()
}
