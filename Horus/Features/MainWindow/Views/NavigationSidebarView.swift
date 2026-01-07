//
//  NavigationSidebarView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI

/// Navigation sidebar with tab selection for Queue, Library, and Settings.
/// This is the primary navigation component in the app.
struct NavigationSidebarView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            List(selection: $state.selectedTab) {
                Section {
                    NavigationTabRow(
                        tab: .queue,
                        badgeCount: appState.queueBadgeCount,
                        isSelected: appState.selectedTab == .queue
                    )
                    .tag(NavigationTab.queue)
                    
                    NavigationTabRow(
                        tab: .library,
                        badgeCount: appState.libraryBadgeCount,
                        isSelected: appState.selectedTab == .library
                    )
                    .tag(NavigationTab.library)
                }
                
                Section {
                    NavigationTabRow(
                        tab: .settings,
                        badgeCount: appState.hasAPIKey ? 0 : 1,
                        isSelected: appState.selectedTab == .settings
                    )
                    .tag(NavigationTab.settings)
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 180)
    }
}

// MARK: - Navigation Tab Row

struct NavigationTabRow: View {
    let tab: NavigationTab
    let badgeCount: Int
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Label(tab.title, systemImage: tab.systemImage)
            
            Spacer()
            
            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
    }
    
    private var badgeColor: Color {
        switch tab {
        case .queue:
            return .blue
        case .library:
            return .green
        case .settings:
            return .orange
        }
    }
}

#Preview {
    NavigationSidebarView()
        .environment(AppState())
        .frame(width: 220)
}
