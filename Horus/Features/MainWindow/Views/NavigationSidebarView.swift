//
//  NavigationSidebarView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI

/// Navigation sidebar with tab selection for Input, OCR, Clean, Library, and Settings.
/// This is the primary navigation component in the app.
struct NavigationSidebarView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        List(selection: $state.selectedTab) {
            // Workflow tabs
            Section {
                NavigationTabRow(
                    tab: .input,
                    badgeCount: appState.inputBadgeCount,
                    isSelected: appState.selectedTab == .input
                )
                .tag(NavigationTab.input)
                
                NavigationTabRow(
                    tab: .ocr,
                    badgeCount: appState.ocrBadgeCount,
                    isSelected: appState.selectedTab == .ocr
                )
                .tag(NavigationTab.ocr)
                
                NavigationTabRow(
                    tab: .clean,
                    badgeCount: appState.cleanBadgeCount,
                    isSelected: appState.selectedTab == .clean
                )
                .tag(NavigationTab.clean)
                
                NavigationTabRow(
                    tab: .library,
                    badgeCount: appState.libraryBadgeCount,
                    isSelected: appState.selectedTab == .library
                )
                .tag(NavigationTab.library)
            }
            
            // Visual separator between workflow tabs and settings
            Section {
                Divider()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, DesignConstants.Spacing.xs)
            }
            
            // Settings tab
            Section {
                NavigationTabRow(
                    tab: .settings,
                    badgeCount: (!appState.hasAPIKey || !appState.hasClaudeAPIKey) ? 1 : 0,
                    isSelected: appState.selectedTab == .settings
                )
                .tag(NavigationTab.settings)
            }
            
            // Spacer section to push content up and add bottom padding
            Section {
                Spacer()
                    .frame(height: DesignConstants.Spacing.sm)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: DesignConstants.Layout.sidebarMinWidth)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Session Stats - Fixed to bottom (no divider)
            SessionStatsView()
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
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
                    .font(DesignConstants.Typography.badge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignConstants.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.sm)
                            .fill(Color(nsColor: .systemGray).opacity(0.55))
                    )
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationSidebarView()
        .environment(AppState())
        .frame(width: 220)
}
