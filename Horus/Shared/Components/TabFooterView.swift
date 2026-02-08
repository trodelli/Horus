//
//  TabFooterView.swift
//  Horus
//
//  Created on 24/01/2026.
//  Standardized footer component for file list panes across all tabs.
//

import SwiftUI

/// A standardized footer view for file list panes.
/// Provides consistent layout with customizable leading and trailing content.
///
/// Usage:
/// ```
/// TabFooterView {
///     Text("\(documents.count) documents")
///     Text("• \(cleanedCount) cleaned")
///         .foregroundStyle(.purple)
/// } trailing: {
///     Text("Total: $1.23")
///         .monospacedDigit()
/// }
/// ```
struct TabFooterView<LeadingContent: View, TrailingContent: View>: View {
    
    // MARK: - Properties
    
    let leadingContent: LeadingContent
    let trailingContent: TrailingContent
    
    // MARK: - Initializer
    
    init(
        @ViewBuilder leading: () -> LeadingContent,
        @ViewBuilder trailing: () -> TrailingContent
    ) {
        self.leadingContent = leading()
        self.trailingContent = trailing()
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            HStack(spacing: DesignConstants.Spacing.xs) {
                leadingContent
            }
            .font(DesignConstants.Typography.footer)
            .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: DesignConstants.Spacing.xs) {
                trailingContent
            }
            .font(DesignConstants.Typography.footer)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DesignConstants.Spacing.md)
        .frame(height: DesignConstants.Layout.footerHeight)
    }
}

// MARK: - Convenience Initializers

extension TabFooterView where TrailingContent == EmptyView {
    
    /// Creates a footer with only leading content
    init(@ViewBuilder leading: () -> LeadingContent) {
        self.leadingContent = leading()
        self.trailingContent = EmptyView()
    }
}

extension TabFooterView where LeadingContent == EmptyView {
    
    /// Creates a footer with only trailing content
    init(@ViewBuilder trailing: () -> TrailingContent) {
        self.leadingContent = EmptyView()
        self.trailingContent = trailing()
    }
}

// MARK: - Common Footer Patterns

extension TabFooterView where LeadingContent == Text, TrailingContent == Text {
    
    /// Creates a simple footer with document count and cost
    static func documentCountWithCost(
        count: Int,
        totalCost: Decimal
    ) -> TabFooterView<Text, Text> {
        TabFooterView {
            Text("\(count) document\(count == 1 ? "" : "s")")
        } trailing: {
            Text("Total: \(totalCost.formatted(.currency(code: "USD")))")
                .monospacedDigit()
        }
    }
}

// MARK: - Status Indicator Component

/// A small status indicator with colored dot and text.
/// Used in footers to show API connection status.
struct StatusIndicator: View {
    let isActive: Bool
    let activeText: String
    let inactiveText: String
    
    init(
        isActive: Bool,
        activeText: String = "Ready",
        inactiveText: String = "Not Ready"
    ) {
        self.isActive = isActive
        self.activeText = activeText
        self.inactiveText = inactiveText
    }
    
    var body: some View {
        HStack(spacing: DesignConstants.Spacing.xs) {
            Circle()
                .fill(isActive ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(isActive ? activeText : inactiveText)
                .font(DesignConstants.Typography.footerSecondary)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Document Count + Cost") {
    VStack {
        TabFooterView {
            Text("42 documents")
        } trailing: {
            Text("Total: $1.23")
                .monospacedDigit()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        
        Divider()
        
        TabFooterView {
            Text("5 documents")
            Text("•")
                .foregroundStyle(.tertiary)
            Text("3 cleaned")
                .foregroundStyle(.purple)
        } trailing: {
            Text("Total: $0.45")
                .monospacedDigit()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        
        Divider()
        
        TabFooterView {
            Text("12 documents")
        } trailing: {
            StatusIndicator(
                isActive: true,
                activeText: "Claude Ready",
                inactiveText: "No API Key"
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    .frame(width: 320)
}
