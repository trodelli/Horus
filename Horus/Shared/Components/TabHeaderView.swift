//
//  TabHeaderView.swift
//  Horus
//
//  Created on 24/01/2026.
//  Standardized header component for file list panes across all tabs.
//

import SwiftUI

/// A standardized header view for file list panes.
/// Provides consistent layout: Title + Subtitle, optional trailing actions, and search field.
///
/// Usage:
/// ```
/// TabHeaderView(
///     title: "Library",
///     subtitle: "Your processed documents",
///     searchText: $searchText
/// ) {
///     Button { /* action */ } label: {
///         Image(systemName: "trash")
///     }
/// }
/// ```
struct TabHeaderView<TrailingContent: View>: View {
    
    // MARK: - Properties
    
    let title: String
    let subtitle: String
    @Binding var searchText: String
    let trailingContent: TrailingContent?
    
    // MARK: - Initializers
    
    /// Creates a header with optional trailing action buttons
    init(
        title: String,
        subtitle: String,
        searchText: Binding<String>,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self._searchText = searchText
        self.trailingContent = trailingContent()
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xsm) {
            // Title row with optional trailing content
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignConstants.Typography.headerTitle)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(DesignConstants.Typography.headerSubtitle)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let trailing = trailingContent {
                    trailing
                }
            }
            
            // Search field
            searchField
        }
        .padding(.horizontal, DesignConstants.Spacing.md)
        .padding(.vertical, DesignConstants.Spacing.md)
        .frame(height: DesignConstants.Layout.headerHeight)
    }
    
    // MARK: - Search Field
    
    private var searchField: some View {
        HStack(spacing: DesignConstants.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(DesignConstants.Typography.searchIcon)
            
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(DesignConstants.Typography.searchField)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(DesignConstants.Typography.searchIcon)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignConstants.Spacing.sm)
        .padding(.vertical, 5)
        .frame(height: DesignConstants.Layout.searchFieldHeight)
        .background(DesignConstants.Colors.searchFieldBackground)
        .cornerRadius(DesignConstants.CornerRadius.md)
    }
}

// MARK: - Convenience Initializer (No Trailing Content)

extension TabHeaderView where TrailingContent == EmptyView {
    
    /// Creates a header without trailing action buttons
    init(
        title: String,
        subtitle: String,
        searchText: Binding<String>
    ) {
        self.title = title
        self.subtitle = subtitle
        self._searchText = searchText
        self.trailingContent = nil
    }
}

// MARK: - Preview

#Preview("With Trailing Content") {
    TabHeaderView(
        title: "Library",
        subtitle: "Your processed documents",
        searchText: .constant("")
    ) {
        Button {
            // Clear action
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 11))
        }
        .buttonStyle(.borderless)
    }
    .frame(width: 300)
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Without Trailing Content") {
    TabHeaderView(
        title: "OCR",
        subtitle: "Use Mistral AI to extract contents",
        searchText: .constant("annual report")
    )
    .frame(width: 300)
    .background(Color(nsColor: .windowBackgroundColor))
}
