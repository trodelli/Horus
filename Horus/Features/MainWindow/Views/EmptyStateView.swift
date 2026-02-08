//
//  EmptyStateView.swift
//  Horus
//
//  Created on 23/01/2026.
//

import SwiftUI

/// A standardized empty state view used throughout Horus for consistent placeholder content.
/// Provides visual hierarchy with icon, title, description, and optional call-to-action.
struct EmptyStateView: View {
    
    // MARK: - Configuration
    
    let icon: String
    let title: String
    let description: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil
    var accentColor: Color = .accentColor
    
    /// Optional secondary information displayed below the main content
    var secondaryContent: AnyView? = nil
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: DesignConstants.Icons.emptyStateSize))
                .foregroundStyle(.tertiary)
            
            Spacer().frame(height: DesignConstants.Spacing.lg)
            
            // Title
            Text(title)
                .font(DesignConstants.Typography.emptyStateTitle)
                .foregroundStyle(.secondary)
            
            Spacer().frame(height: DesignConstants.Spacing.sm)
            
            // Description
            Text(description)
                .font(DesignConstants.Typography.emptyStateDescription)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            // CTA Button (optional)
            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Spacer().frame(height: DesignConstants.Spacing.xl)
                
                Button(buttonTitle, action: buttonAction)
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .controlSize(.regular)
            }
            
            // Secondary content (optional)
            if let secondaryContent = secondaryContent {
                Spacer().frame(height: DesignConstants.Spacing.lg)
                secondaryContent
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Convenience Initializers

extension EmptyStateView {
    
    /// Creates an empty state with just icon, title, and description
    init(icon: String, title: String, description: String) {
        self.icon = icon
        self.title = title
        self.description = description
        self.buttonTitle = nil
        self.buttonAction = nil
        self.secondaryContent = nil
    }
    
    /// Creates an empty state with a call-to-action button
    init(
        icon: String,
        title: String,
        description: String,
        buttonTitle: String,
        buttonAction: @escaping () -> Void,
        accentColor: Color = .accentColor
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
        self.accentColor = accentColor
        self.secondaryContent = nil
    }
    
    /// Creates an empty state with secondary content below
    init<Secondary: View>(
        icon: String,
        title: String,
        description: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil,
        accentColor: Color = .accentColor,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
        self.accentColor = accentColor
        self.secondaryContent = AnyView(secondary())
    }
}

// MARK: - Preview

#Preview("Basic") {
    EmptyStateView(
        icon: "doc.text",
        title: "No Selection",
        description: "Select a document to preview its content."
    )
    .frame(width: 400, height: 300)
}

#Preview("With Button") {
    EmptyStateView(
        icon: "doc.badge.plus",
        title: "No Documents",
        description: "Drag and drop files here, or click Add Documents to get started.",
        buttonTitle: "Add Documents",
        buttonAction: { }
    )
    .frame(width: 400, height: 300)
}

#Preview("With Secondary Content") {
    EmptyStateView(
        icon: "sparkles",
        title: "No Documents to Clean",
        description: "Process documents through OCR first, then they'll appear here for cleaning.",
        buttonTitle: "Go to Input",
        buttonAction: { },
        accentColor: .purple
    ) {
        VStack(spacing: DesignConstants.Spacing.xs) {
            Text("Supported formats:")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("PDF, PNG, JPG, TXT, MD")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    .frame(width: 400, height: 350)
}
