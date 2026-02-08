//
//  SettingsTabView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import AppKit

/// Settings tab view embedded in the main window.
/// Uses the shared SettingsView for consistent appearance.
struct SettingsTabView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        SettingsView()
    }
}

#Preview {
    SettingsTabView()
        .environment(AppState())
        .frame(width: 700, height: 900)
}
