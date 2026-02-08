//
//  DesignConstants.swift
//  Horus
//
//  Created on 24/01/2026.
//  Single source of truth for all design values across the application.
//

import SwiftUI

/// Centralized design constants for visual harmony across Horus.
/// All UI components should reference these values rather than hardcoding dimensions.
enum DesignConstants {
    
    // MARK: - Spacing
    
    /// Standard spacing values following an 4-point base grid
    enum Spacing {
        /// 4pt - Tight spacing between closely related elements
        static let xs: CGFloat = 4
        /// 6pt - Compact spacing for header content levels
        static let xsm: CGFloat = 6
        /// 8pt - Small spacing between related elements
        static let sm: CGFloat = 8
        /// 12pt - Medium spacing, standard padding
        static let md: CGFloat = 12
        /// 16pt - Large spacing between sections
        static let lg: CGFloat = 16
        /// 20pt - Extra large spacing for major separations
        static let xl: CGFloat = 20
        /// 24pt - Maximum spacing for distinct sections
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Layout
    
    /// Standard layout dimensions for consistent structure
    enum Layout {
        /// Standard header height for all tab file list and content panes (96pt)
        static let headerHeight: CGFloat = 96
        /// Standard footer height for all tab file list panes (36pt)
        static let footerHeight: CGFloat = 36
        
        /// File list pane constraints
        static let fileListMinWidth: CGFloat = 220
        static let fileListMaxWidth: CGFloat = 320
        
        /// Content pane minimum width (400pt to allow smaller window sizes on 13" screens)
        static let contentPaneMinWidth: CGFloat = 400
        
        /// Inspector panel constraints
        static let inspectorMinWidth: CGFloat = 300
        static let inspectorIdealWidth: CGFloat = 470
        static let inspectorMaxWidth: CGFloat = 580
        
        /// Navigation sidebar constraints
        static let sidebarMinWidth: CGFloat = 180
        static let sidebarIdealWidth: CGFloat = 200
        static let sidebarMaxWidth: CGFloat = 250
        
        /// Search field height
        static let searchFieldHeight: CGFloat = 26
        
        /// Document row vertical padding
        static let documentRowPadding: CGFloat = 4
    }
    
    // MARK: - Typography
    
    /// Standard font sizes for consistent text hierarchy
    enum Typography {
        /// Tab/section title (13pt, semibold)
        static let headerTitle: Font = .system(size: 13, weight: .semibold)
        /// Tab/section subtitle (11pt, regular)
        static let headerSubtitle: Font = .system(size: 11)
        
        /// Document name in lists (13pt, regular)
        static let documentName: Font = .system(size: 13)
        /// Document metadata in lists (11pt, regular)
        static let documentMeta: Font = .system(size: 11)
        
        /// Search field text (12pt, regular)
        static let searchField: Font = .system(size: 12)
        /// Search field icon (11pt)
        static let searchIcon: Font = .system(size: 11)
        
        /// Footer text (11pt, regular)
        static let footer: Font = .system(size: 11)
        /// Footer secondary text (10pt, regular)
        static let footerSecondary: Font = .system(size: 10)
        
        /// Inspector section header (subheadline, semibold)
        static let inspectorHeader: Font = .subheadline.weight(.semibold)
        /// Inspector row label (callout)
        static let inspectorLabel: Font = .callout
        /// Inspector row value (callout)
        static let inspectorValue: Font = .callout
        
        /// Badge text (10pt, medium)
        static let badge: Font = .system(size: 10, weight: .medium)
        
        /// Stats bar text (10pt, regular)
        static let statsBar: Font = .system(size: 10)
        
        /// Toolbar button text (12pt, medium)
        static let toolbarButton: Font = .system(size: 12, weight: .medium)
        /// Toolbar button text (12pt, regular)
        static let toolbarButtonRegular: Font = .system(size: 12)
        
        /// Empty state icon (48pt)
        static let emptyStateIcon: Font = .system(size: 48)
        /// Empty state title (title3, medium)
        static let emptyStateTitle: Font = .title3.weight(.medium)
        /// Empty state description (callout)
        static let emptyStateDescription: Font = .callout
    }
    
    // MARK: - Colors
    
    /// Semantic background colors for consistent visual hierarchy
    enum Colors {
        /// File list pane background - lighter (underPageBackgroundColor for consistent light appearance)
        static let fileListBackground = Color(nsColor: .underPageBackgroundColor)
        /// Content pane background - darker (primary focus)
        static let contentBackground = Color(nsColor: .textBackgroundColor)
        /// Inspector background - lighter (matches file list using same color)
        static let inspectorBackground = Color(nsColor: .underPageBackgroundColor)
        
        /// Stats bar background
        static let statsBarBackground = Color(nsColor: .controlBackgroundColor)
        /// Search field background
        static let searchFieldBackground = Color(nsColor: .quaternaryLabelColor).opacity(0.5)
        
        /// Separator color
        static let separator = Color(nsColor: .separatorColor)
    }
    
    // MARK: - Icons
    
    /// Standard icon dimensions
    enum Icons {
        /// Document row icon size (32×40)
        static let documentRowWidth: CGFloat = 32
        static let documentRowHeight: CGFloat = 40
        static let documentRowCornerRadius: CGFloat = 4
        static let documentRowIconFont: Font = .system(size: 12)
        
        /// Input document row icon size (28×34) - slightly smaller
        static let inputRowWidth: CGFloat = 28
        static let inputRowHeight: CGFloat = 34
        static let inputRowCornerRadius: CGFloat = 3
        static let inputRowIconFont: Font = .system(size: 10)
        
        /// Inspector document icon size (40×40)
        static let inspectorIconSize: CGFloat = 40
        static let inspectorIconCornerRadius: CGFloat = 8
        static let inspectorIconFont: Font = .system(size: 20)
        
        /// Empty state icon size (48pt)
        static let emptyStateSize: CGFloat = 48
        
        /// Thumbnail sizes
        static let thumbnailWidth: CGFloat = 280
        static let thumbnailHeight: CGFloat = 360
        static let thumbnailCornerRadius: CGFloat = 8
    }
    
    // MARK: - Corner Radii
    
    /// Standard corner radius values
    enum CornerRadius {
        /// Tiny radius for badges, small elements (3pt)
        static let xs: CGFloat = 3
        /// Small radius for buttons, tags (4pt)
        static let sm: CGFloat = 4
        /// Medium radius for cards, containers (6pt)
        static let md: CGFloat = 6
        /// Large radius for panels, sheets (8pt)
        static let lg: CGFloat = 8
        /// Extra large radius for modals (12pt)
        static let xl: CGFloat = 12
        /// Maximum radius for prominent containers (16pt)
        static let xxl: CGFloat = 16
    }
    
    // MARK: - Animations
    
    /// Standard animation durations
    enum Animation {
        /// Quick transitions (0.15s)
        static let fast: Double = 0.15
        /// Standard transitions (0.2s)
        static let standard: Double = 0.2
        /// Slower, more deliberate transitions (0.3s)
        static let slow: Double = 0.3
    }
    
    // MARK: - Shadows
    
    /// Standard shadow values
    enum Shadow {
        /// Subtle shadow for slight elevation
        static let subtle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: .black.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        /// Medium shadow for cards
        static let medium: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: .black.opacity(0.15),
            radius: 4,
            x: 0,
            y: 2
        )
        /// Strong shadow for modals/overlays
        static let strong: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
            color: .black.opacity(0.2),
            radius: 20,
            x: 0,
            y: 10
        )
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Apply standard file list pane background
    func fileListBackground() -> some View {
        self.background(DesignConstants.Colors.fileListBackground)
    }
    
    /// Apply standard content pane background
    func contentBackground() -> some View {
        self.background(DesignConstants.Colors.contentBackground)
    }
    
    /// Apply standard inspector background
    func inspectorBackground() -> some View {
        self.background(DesignConstants.Colors.inspectorBackground)
    }
    
    /// Apply standard horizontal padding (12pt)
    func standardHorizontalPadding() -> some View {
        self.padding(.horizontal, DesignConstants.Spacing.md)
    }
    
    /// Apply standard section spacing (20pt)
    func sectionSpacing() -> some View {
        self.padding(.vertical, DesignConstants.Spacing.xl)
    }
}
