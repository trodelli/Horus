# Implementation Guide
## Horus — Document Processing System for macOS

> **Document Version:** 2.0  
> **Last Updated:** January 2026  
> **Status:** Production Reference  
> **Prerequisites:** PRD v2.0, Technical Architecture v2.0, API Integration Guide v2.0, UI/UX Specification v2.0

---

## Table of Contents

1. [Development Overview](#1-development-overview)
2. [Environment Setup](#2-environment-setup)
3. [Phase 1: Foundation](#3-phase-1-foundation)
4. [Phase 2: Core Services](#4-phase-2-core-services)
5. [Phase 3: Document Management](#5-phase-3-document-management)
6. [Phase 4: OCR Processing](#6-phase-4-ocr-processing)
7. [Phase 5: Library & Export](#7-phase-5-library--export)
8. [Phase 6: Cleaning Pipeline](#8-phase-6-cleaning-pipeline)
9. [Phase 7: Polish & Testing](#9-phase-7-polish--testing)
10. [Verification Checkpoints](#10-verification-checkpoints)
11. [Common Pitfalls](#11-common-pitfalls)
12. [Appendix: Code Templates](#12-appendix-code-templates)

---

## 1. Development Overview

### 1.1 Development Philosophy

Horus is built incrementally, with each phase producing a working application that does progressively more. This approach:

- Provides early feedback on fundamental decisions
- Reduces risk by validating assumptions continuously
- Keeps motivation high with visible progress
- Makes debugging easier (fewer variables at each step)

### 1.2 Architecture Overview

Horus implements a **5-tab workflow architecture** with **dual API integration**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                           HORUS                                     │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌────────┐│
│  │  Input  │ → │   OCR   │ → │  Clean  │ → │ Library │   │Settings││
│  │ (Blue)  │   │ (Blue)  │   │(Purple) │   │ (Green) │   │ (Gray) ││
│  └─────────┘   └─────────┘   └─────────┘   └─────────┘   └────────┘│
│       │              │             │              │                 │
│       ▼              ▼             ▼              ▼                 │
│   Import &      Mistral       Claude API     Completed             │
│   Validate       OCR API      Cleaning       Documents             │
└─────────────────────────────────────────────────────────────────────┘
```

**Key Architectural Elements:**
- **Dual API Integration:** Mistral for OCR, Claude for AI-powered cleaning
- **Library-Centric Workflow:** Documents must be explicitly added to Library
- **Session-Based Processing:** Documents exist within sessions, not persisted to disk
- **Multi-Stage Pipeline:** Input → OCR → Clean → Library progression
- **Shared Component Architecture:** Reusable UI components across tabs

### 1.3 Phase Summary

| Phase | Focus | Duration | Deliverable |
|:------|:------|:---------|:------------|
| **1. Foundation** | Project setup, models, app shell | 2-3 days | Empty app with 5-tab navigation |
| **2. Core Services** | Keychain, network, cost calculation | 2-3 days | Settings with dual API key storage |
| **3. Document Management** | Import, queue, validation | 3-4 days | Import and display documents |
| **4. OCR Processing** | Mistral API integration, progress | 4-5 days | Process documents with OCR |
| **5. Library & Export** | Library management, file export | 3-4 days | View and export completed documents |
| **6. Cleaning Pipeline** | Claude API, cleaning workflow | 5-7 days | AI-powered document cleaning |
| **7. Polish & Testing** | Edge cases, accessibility, testing | 3-4 days | Production-ready application |

**Total Estimated Duration:** 22-30 days

### 1.4 Build Sequence Rationale

```
Foundation ──▶ Services ──▶ Documents ──▶ OCR ──▶ Library ──▶ Cleaning ──▶ Polish
     │              │            │          │         │           │           │
     ▼              ▼            ▼          ▼         ▼           ▼           ▼
  Models        Keychain     Import     Mistral    Export      Claude      Tests
  App Shell     Network      Queue      Progress   Formats     Pipeline    A11y
  5-Tab Nav     Settings     Validate   Errors     Library     14 Steps    Edge Cases
  Design Sys    Dual Keys    Drag-Drop  Badges     Selection   Validation  Performance
```

Each phase builds on the previous, minimizing rework and maintaining a runnable application throughout.

---

## 2. Environment Setup

### 2.1 Prerequisites

| Requirement | Version | How to Verify |
|:------------|:--------|:--------------|
| macOS | 14.0+ (Sonoma) | Apple menu → About This Mac |
| Xcode | 15.0+ | `xcode-select --version` |
| Swift | 5.9+ | `swift --version` |
| Git | Any recent | `git --version` |
| Mistral API Key | — | console.mistral.ai |
| Anthropic API Key | — | console.anthropic.com |

### 2.2 Create Xcode Project

**Step 1: Create New Project**

1. Open Xcode
2. File → New → Project (⇧⌘N)
3. Select: macOS → App
4. Click Next

**Step 2: Configure Project**

| Field | Value |
|:------|:------|
| Product Name | Horus |
| Team | Your Apple Developer account |
| Organization Identifier | com.yourname |
| Bundle Identifier | Auto-generated |
| Interface | SwiftUI |
| Language | Swift |
| Storage | None |
| Include Tests | ✓ (checked) |

**Step 3: Configure Project Settings**

1. Select the Horus project in the navigator
2. Select the Horus target
3. In the General tab:
   - Minimum Deployments: macOS 14.0
   - App Category: Productivity
4. In Signing & Capabilities:
   - Add Keychain Sharing capability
5. In Info tab:
   - Add `NSDocumentsFolderUsageDescription`: "Horus needs access to export processed files."

### 2.3 Create Folder Structure

```
Horus/
├── App/
│   └── AppState.swift
├── Core/
│   ├── Errors/
│   │   ├── CleaningError.swift
│   │   └── HorusError.swift
│   ├── Models/
│   │   ├── APIModels/
│   │   │   ├── ClaudeAPIModels.swift
│   │   │   └── OCRAPIModels.swift
│   │   ├── CleaningModels/
│   │   │   ├── CleanedContent.swift
│   │   │   ├── CleaningConfiguration.swift
│   │   │   ├── CleaningProgress.swift
│   │   │   ├── CleaningStep.swift
│   │   │   └── DetectedPatterns.swift
│   │   ├── Document.swift
│   │   ├── DocumentStatus.swift
│   │   ├── DocumentWorkflowStage.swift
│   │   ├── ExportFormat.swift
│   │   ├── OCRResult.swift
│   │   ├── ProcessingSession.swift
│   │   └── UserPreferences.swift
│   ├── Services/
│   │   ├── APIKeyValidator.swift
│   │   ├── ClaudeService.swift
│   │   ├── CleaningService.swift
│   │   ├── CostCalculator.swift
│   │   ├── DocumentService.swift
│   │   ├── ExportService.swift
│   │   ├── KeychainService.swift
│   │   ├── NetworkClient.swift
│   │   ├── OCRService.swift
│   │   └── TextProcessingService.swift
│   └── Utilities/
│       ├── DesignConstants.swift
│       └── Extensions/
│           ├── Accessibility.swift
│           └── Notifications.swift
├── Features/
│   ├── Cleaning/
│   │   ├── ViewModels/
│   │   │   └── CleaningViewModel.swift
│   │   └── Views/
│   │       ├── CleanTabView.swift
│   │       ├── CleaningInspectorView.swift
│   │       └── VirtualizedTextView.swift
│   ├── DocumentQueue/
│   │   └── ViewModels/
│   │       └── DocumentQueueViewModel.swift
│   ├── Export/
│   │   ├── ViewModels/
│   │   │   └── ExportViewModel.swift
│   │   └── Views/
│   │       ├── BatchExportSheetView.swift
│   │       └── ExportSheetView.swift
│   ├── Library/
│   │   └── Views/
│   │       └── LibraryView.swift
│   ├── MainWindow/
│   │   └── Views/
│   │       ├── ContentAreaView.swift
│   │       ├── InspectorView.swift
│   │       ├── MainWindowView.swift
│   │       ├── NavigationSidebarView.swift
│   │       └── SidebarView.swift
│   ├── OCR/
│   │   └── Views/
│   │       └── OCRTabView.swift
│   ├── Onboarding/
│   │   └── Views/
│   │       ├── OnboardingView.swift
│   │       └── OnboardingWizardView.swift
│   ├── Processing/
│   │   └── ViewModels/
│   │       └── ProcessingViewModel.swift
│   ├── Queue/
│   │   └── Views/
│   │       └── InputView.swift
│   └── Settings/
│       └── Views/
│           ├── CleaningSettingsView.swift
│           └── SettingsView.swift
├── Shared/
│   └── Components/
│       ├── ContentHeaderView.swift
│       ├── DocumentListRow.swift
│       ├── InspectorComponents.swift
│       ├── PipelineStatusIcons.swift
│       ├── TabFooterView.swift
│       └── TabHeaderView.swift
├── Resources/
├── HorusApp.swift
└── Horus.entitlements
```

### 2.4 Design System Setup

Create `Core/Utilities/DesignConstants.swift` early—this is the foundation for consistent UI:

```swift
import SwiftUI

/// Single source of truth for all design values in Horus.
/// Uses a 4-point base grid system for consistent spacing.
enum DesignConstants {
    
    // MARK: - Spacing (4-point base grid)
    
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
        /// 20pt - Extra large for major separations
        static let xl: CGFloat = 20
        /// 24pt - Maximum spacing for distinct sections
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Layout Dimensions
    
    enum Layout {
        /// Standard header height for all tab views
        static let headerHeight: CGFloat = 96
        /// Standard footer height
        static let footerHeight: CGFloat = 36
        /// Minimum file list width
        static let fileListMinWidth: CGFloat = 220
        /// Maximum file list width
        static let fileListMaxWidth: CGFloat = 320
        /// Ideal file list width
        static let fileListIdealWidth: CGFloat = 260
        /// Minimum content pane width
        static let contentMinWidth: CGFloat = 400
        /// Minimum inspector width
        static let inspectorMinWidth: CGFloat = 300
        /// Maximum inspector width
        static let inspectorMaxWidth: CGFloat = 580
        /// Ideal inspector width
        static let inspectorIdealWidth: CGFloat = 470
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let headerTitle: Font = .system(size: 15, weight: .semibold)
        static let headerSubtitle: Font = .system(size: 12, weight: .regular)
        static let sectionHeader: Font = .system(size: 11, weight: .semibold)
        static let bodyText: Font = .system(size: 13, weight: .regular)
        static let caption: Font = .system(size: 11, weight: .regular)
        static let footerPrimary: Font = .system(size: 11, weight: .medium)
        static let footerSecondary: Font = .system(size: 10, weight: .regular)
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 6
        static let large: CGFloat = 8
        static let card: CGFloat = 10
    }
    
    // MARK: - Tab Accent Colors
    
    enum TabColors {
        static let input: Color = .blue
        static let ocr: Color = .blue
        static let clean: Color = .purple
        static let library: Color = .green
        static let settings: Color = .gray
    }
}
```

### 2.5 Verification Checkpoint

✅ **Environment Setup Complete When:**
- [ ] Project builds without errors (⌘B)
- [ ] App launches and shows default SwiftUI view (⌘R)
- [ ] Folder structure matches specification
- [ ] Keychain entitlement added
- [ ] DesignConstants.swift created
- [ ] Git repository initialized
- [ ] Minimum deployment target is macOS 14.0

---

## 3. Phase 1: Foundation

### 3.1 Phase Goals

By the end of this phase:
- All data models defined (Document, OCRResult, ProcessingSession)
- App entry point configured with 5-tab navigation
- Main window shell with NavigationSplitView structure
- Empty views for all major screens
- Design system constants established

### 3.2 Core Models

**Document.swift** — The central data model:

```swift
import Foundation
import UniformTypeIdentifiers

/// Represents a document imported for processing.
/// Documents exist within sessions and are not persisted between launches.
struct Document: Identifiable, Equatable, Hashable {
    let id: UUID
    let sourceURL: URL
    let contentType: UTType
    let fileSize: Int64
    var estimatedPageCount: Int?
    var status: DocumentStatus
    let importedAt: Date
    var processedAt: Date?
    var result: OCRResult?
    var error: DocumentError?
    var cleanedContent: CleanedContent?
    var isInLibrary: Bool
    
    // Computed properties
    var displayName: String { sourceURL.deletingPathExtension().lastPathComponent }
    var fileExtension: String { sourceURL.pathExtension.lowercased() }
    var isCompleted: Bool { if case .completed = status { return true }; return false }
    var isCleaned: Bool { cleanedContent != nil }
    var canClean: Bool { isCompleted && result != nil }
    var requiresOCR: Bool { contentType.conforms(to: .pdf) || contentType.conforms(to: .image) }
    
    /// Whether processing costs have been incurred (OCR or Cleaning)
    var hasBeenProcessed: Bool {
        let ocrCost = result?.cost ?? 0
        let cleaningCost = cleanedContent?.totalCost ?? 0
        return ocrCost > 0 || cleaningCost > 0
    }
}

/// Processing status with associated values for progress
enum DocumentStatus: Equatable {
    case pending
    case validating
    case processing(progress: Double)
    case completed
    case failed
    case cancelled
}

/// Workflow stages for Input tab organization
enum DocumentWorkflowStage {
    case pending    // Awaiting processing
    case processing // OCR or Cleaning in progress
    case complete   // In library
}
```

**ProcessingSession.swift** — Session management with library tracking:

```swift
import Foundation
import Observation

/// Manages documents within a processing session.
/// Tracks both processing state and library membership.
@Observable
final class ProcessingSession {
    private(set) var documents: [Document] = []
    
    // MARK: - Filtered Views
    
    var pendingDocuments: [Document] {
        documents.filter { $0.status == .pending }
    }
    
    var processingDocuments: [Document] {
        documents.filter { if case .processing = $0.status { return true }; return false }
    }
    
    var completedDocuments: [Document] {
        documents.filter { $0.isCompleted }
    }
    
    var failedDocuments: [Document] {
        documents.filter { $0.status == .failed }
    }
    
    /// Documents explicitly added to Library
    var libraryDocuments: [Document] {
        documents.filter { $0.isInLibrary }
    }
    
    /// Completed but NOT yet in Library (awaiting user action)
    var awaitingLibraryDocuments: [Document] {
        documents.filter { $0.isCompleted && !$0.isInLibrary }
    }
    
    // MARK: - Document Management
    
    func addDocuments(_ newDocuments: [Document]) {
        documents.append(contentsOf: newDocuments)
    }
    
    func updateDocument(_ document: Document) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index] = document
    }
    
    func removeDocument(id: UUID) {
        documents.removeAll { $0.id == id }
    }
    
    func addToLibrary(id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].isInLibrary = true
    }
    
    func clearAll() {
        documents.removeAll()
    }
}
```

### 3.3 Navigation Tab Enum

```swift
/// The five main navigation tabs
enum NavigationTab: String, Identifiable, CaseIterable {
    case input = "input"
    case ocr = "ocr"
    case clean = "clean"
    case library = "library"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .input: return "Input"
        case .ocr: return "OCR"
        case .clean: return "Clean"
        case .library: return "Library"
        case .settings: return "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .input: return "square.and.arrow.down"
        case .ocr: return "doc.text.viewfinder"
        case .clean: return "sparkles"
        case .library: return "books.vertical"
        case .settings: return "gearshape"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .input, .ocr: return DesignConstants.TabColors.ocr
        case .clean: return DesignConstants.TabColors.clean
        case .library: return DesignConstants.TabColors.library
        case .settings: return DesignConstants.TabColors.settings
        }
    }
}
```

### 3.4 App State

```swift
import Foundation
import Observation
import OSLog

/// Global application state shared across all views.
@Observable
@MainActor
final class AppState {
    private let logger = Logger(subsystem: "com.horus.app", category: "AppState")
    
    // MARK: - Services (injected)
    let keychainService: KeychainServiceProtocol
    let costCalculator: CostCalculatorProtocol
    // ... other services
    
    // MARK: - Core State
    var session: ProcessingSession
    var preferences: UserPreferences
    private(set) var hasAPIKey: Bool = false
    private(set) var hasClaudeAPIKey: Bool = false
    
    // MARK: - Navigation State
    var selectedTab: NavigationTab = .input
    var selectedInputDocumentId: UUID?
    var selectedLibraryDocumentId: UUID?
    var selectedCleanDocumentId: UUID?
    var selectedPageIndex: Int = 0
    
    // MARK: - UI State
    var showOnboarding: Bool = false
    var currentAlert: AlertInfo?
    var showingExportSheet: Bool = false
    var showingCleaningSheet: Bool = false
    
    // MARK: - Badge Counts (for tab indicators)
    var inputBadgeCount: Int {
        session.pendingDocuments.count + session.processingDocuments.count + session.failedDocuments.count
    }
    
    var ocrBadgeCount: Int {
        session.awaitingLibraryDocuments.filter { $0.requiresOCR && !$0.isCleaned }.count
    }
    
    var libraryBadgeCount: Int {
        session.libraryDocuments.count
    }
    
    var cleanBadgeCount: Int {
        session.completedDocuments.filter { $0.isCleaned && !$0.isInLibrary }.count
    }
    
    // MARK: - Initialization
    init(keychainService: KeychainServiceProtocol = KeychainService.shared, ...) {
        self.keychainService = keychainService
        self.session = ProcessingSession()
        self.preferences = UserPreferences.load()
        self.hasAPIKey = keychainService.hasAPIKey
        self.hasClaudeAPIKey = keychainService.hasClaudeAPIKey
        self.showOnboarding = !hasAPIKey
    }
}
```

### 3.5 Main Window Structure

**MainWindowView.swift:**

```swift
import SwiftUI

struct MainWindowView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationSplitView {
            // Left: Tab Navigation
            NavigationSidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } content: {
            // Middle: Tab Content (File List + Content Pane)
            ContentAreaView()
                .navigationSplitViewColumnWidth(min: 600, ideal: 800, max: .infinity)
        } detail: {
            // Right: Inspector
            InspectorView()
                .navigationSplitViewColumnWidth(
                    min: DesignConstants.Layout.inspectorMinWidth,
                    ideal: DesignConstants.Layout.inspectorIdealWidth,
                    max: DesignConstants.Layout.inspectorMaxWidth
                )
        }
        .sheet(isPresented: $appState.showOnboarding) {
            OnboardingWizardView()
        }
    }
}
```

**NavigationSidebarView.swift** — 5-tab vertical navigation:

```swift
import SwiftUI

struct NavigationSidebarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            // App Logo/Title
            VStack(spacing: DesignConstants.Spacing.xs) {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.accent)
                Text("Horus")
                    .font(.headline)
            }
            .padding(.vertical, DesignConstants.Spacing.lg)
            
            Divider()
            
            // Navigation Tabs
            List(selection: Binding(
                get: { appState.selectedTab },
                set: { appState.selectedTab = $0 }
            )) {
                ForEach(NavigationTab.allCases) { tab in
                    NavigationTabRow(tab: tab, badgeCount: badgeCount(for: tab))
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func badgeCount(for tab: NavigationTab) -> Int {
        switch tab {
        case .input: return appState.inputBadgeCount
        case .ocr: return appState.ocrBadgeCount
        case .clean: return appState.cleanBadgeCount
        case .library: return appState.libraryBadgeCount
        case .settings: return 0
        }
    }
}

struct NavigationTabRow: View {
    let tab: NavigationTab
    let badgeCount: Int
    
    var body: some View {
        Label {
            HStack {
                Text(tab.title)
                Spacer()
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tab.accentColor.opacity(0.2))
                        .foregroundStyle(tab.accentColor)
                        .clipShape(Capsule())
                }
            }
        } icon: {
            Image(systemName: tab.systemImage)
                .foregroundStyle(tab.accentColor)
        }
    }
}
```

### 3.6 Shared Components Foundation

**TabHeaderView.swift** — Reusable header for all tabs:

```swift
import SwiftUI

struct TabHeaderView: View {
    let title: String
    let subtitle: String?
    let accentColor: Color
    let icon: String?
    
    init(title: String, subtitle: String? = nil, accentColor: Color = .blue, icon: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.icon = icon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xsm) {
            HStack(spacing: DesignConstants.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(accentColor)
                }
                Text(title)
                    .font(DesignConstants.Typography.headerTitle)
            }
            
            if let subtitle {
                Text(subtitle)
                    .font(DesignConstants.Typography.headerSubtitle)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: DesignConstants.Layout.headerHeight)
        .padding(.horizontal, DesignConstants.Spacing.lg)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
```

**TabFooterView.swift:**

```swift
import SwiftUI

struct TabFooterView: View {
    let primaryText: String
    let secondaryText: String?
    let accentColor: Color
    
    var body: some View {
        HStack {
            Text(primaryText)
                .font(DesignConstants.Typography.footerPrimary)
                .foregroundStyle(accentColor)
            
            if let secondary = secondaryText {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text(secondary)
                    .font(DesignConstants.Typography.footerSecondary)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(height: DesignConstants.Layout.footerHeight)
        .padding(.horizontal, DesignConstants.Spacing.lg)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
```

### 3.7 Verification Checkpoint

✅ **Phase 1 Complete When:**
- [ ] App launches without errors
- [ ] 5-tab vertical navigation displays correctly
- [ ] Tab selection changes content area
- [ ] Badge counts display (can be hardcoded for now)
- [ ] NavigationSplitView shows 3 columns
- [ ] Shared components (TabHeaderView, TabFooterView) work
- [ ] DesignConstants values used throughout
- [ ] All models compile without errors
- [ ] Git commit: "Phase 1: Foundation complete"

---

## 4. Phase 2: Core Services

### 4.1 Phase Goals

By the end of this phase:
- Keychain service storing both Mistral and Claude API keys
- Network client for HTTP operations
- Cost calculator for dual pricing (OCR + Cleaning)
- API key validation for both services
- Settings UI with dual API key management
- Onboarding wizard for initial setup

### 4.2 Keychain Service

**KeychainService.swift** — Supports both API providers:

```swift
import Foundation
import Security
import OSLog

protocol KeychainServiceProtocol {
    var hasAPIKey: Bool { get }
    var hasClaudeAPIKey: Bool { get }
    func storeAPIKey(_ key: String) throws
    func retrieveAPIKey() throws -> String?
    func deleteAPIKey() throws
    func storeClaudeAPIKey(_ key: String) throws
    func retrieveClaudeAPIKey() throws -> String?
    func deleteClaudeAPIKey() throws
}

final class KeychainService: KeychainServiceProtocol {
    static let shared = KeychainService()
    
    private let logger = Logger(subsystem: "com.horus.app", category: "Keychain")
    private let serviceName = "com.horus.app"
    private let mistralAccountName = "mistral-api-key"
    private let claudeAccountName = "claude-api-key"
    
    var hasAPIKey: Bool { (try? retrieveAPIKey()) != nil }
    var hasClaudeAPIKey: Bool { (try? retrieveClaudeAPIKey()) != nil }
    
    // MARK: - Mistral API Key
    
    func storeAPIKey(_ key: String) throws {
        try store(key: key, account: mistralAccountName)
    }
    
    func retrieveAPIKey() throws -> String? {
        try retrieve(account: mistralAccountName)
    }
    
    func deleteAPIKey() throws {
        try delete(account: mistralAccountName)
    }
    
    // MARK: - Claude API Key
    
    func storeClaudeAPIKey(_ key: String) throws {
        try store(key: key, account: claudeAccountName)
    }
    
    func retrieveClaudeAPIKey() throws -> String? {
        try retrieve(account: claudeAccountName)
    }
    
    func deleteClaudeAPIKey() throws {
        try delete(account: claudeAccountName)
    }
    
    // MARK: - Key Format Validation
    
    static func isValidMistralKeyFormat(_ key: String) -> Bool {
        key.hasPrefix("sk-") && key.count > 20
    }
    
    static func isValidClaudeKeyFormat(_ key: String) -> Bool {
        key.hasPrefix("sk-ant-") && key.count > 40
    }
    
    // MARK: - Private Implementation
    
    private func store(key: String, account: String) throws {
        try? delete(account: account)
        
        guard let keyData = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    private func retrieve(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let key = String(data: data, encoding: .utf8) else {
                throw KeychainError.decodingFailed
            }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.retrieveFailed(status)
        }
    }
    
    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
```

### 4.3 Cost Calculator

**CostCalculator.swift** — Dual pricing for OCR and Cleaning:

```swift
import Foundation

protocol CostCalculatorProtocol {
    func calculateOCRCost(pages: Int) -> Decimal
    func calculateCleaningCost(inputTokens: Int, outputTokens: Int) -> Decimal
    func formatCost(_ cost: Decimal, includeEstimatePrefix: Bool) -> String
}

struct CostCalculator: CostCalculatorProtocol {
    static let shared = CostCalculator()
    
    // Mistral OCR: $1.00 per 1,000 pages
    private let ocrPricePerPage: Decimal = Decimal(string: "0.001")!
    
    // Claude Sonnet 4: $3.00 per 1M input tokens, $15.00 per 1M output tokens
    private let claudeInputPricePerToken: Decimal = Decimal(string: "0.000003")!
    private let claudeOutputPricePerToken: Decimal = Decimal(string: "0.000015")!
    
    func calculateOCRCost(pages: Int) -> Decimal {
        Decimal(pages) * ocrPricePerPage
    }
    
    func calculateCleaningCost(inputTokens: Int, outputTokens: Int) -> Decimal {
        let inputCost = Decimal(inputTokens) * claudeInputPricePerToken
        let outputCost = Decimal(outputTokens) * claudeOutputPricePerToken
        return inputCost + outputCost
    }
    
    func formatCost(_ cost: Decimal, includeEstimatePrefix: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        
        if cost < Decimal(string: "0.01")! {
            formatter.minimumFractionDigits = 3
            formatter.maximumFractionDigits = 4
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }
        
        let formatted = formatter.string(from: cost as NSDecimalNumber) ?? "$0.00"
        return includeEstimatePrefix ? "~\(formatted)" : formatted
    }
}
```

### 4.4 API Key Validator

```swift
import Foundation

enum APIKeyValidationResult {
    case valid
    case invalid(String)
    case networkError(String)
}

protocol APIKeyValidatorProtocol {
    func validate(_ key: String) async -> APIKeyValidationResult
    func validateClaudeKey(_ key: String) async -> APIKeyValidationResult
}

final class APIKeyValidator: APIKeyValidatorProtocol {
    static let shared = APIKeyValidator()
    
    private let networkClient: NetworkClient
    
    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
    }
    
    func validate(_ key: String) async -> APIKeyValidationResult {
        guard KeychainService.isValidMistralKeyFormat(key) else {
            return .invalid("Key should start with 'sk-'")
        }
        
        do {
            // Test with Mistral models endpoint
            struct ModelsResponse: Decodable {
                let data: [Model]
                struct Model: Decodable { let id: String }
            }
            
            let _: ModelsResponse = try await networkClient.get(
                url: URL(string: "https://api.mistral.ai/v1/models")!,
                headers: ["Authorization": "Bearer \(key)"]
            )
            return .valid
        } catch let error as NetworkError {
            if case .httpError(401, _) = error {
                return .invalid("Invalid API key")
            }
            return .networkError(error.localizedDescription)
        } catch {
            return .networkError(error.localizedDescription)
        }
    }
    
    func validateClaudeKey(_ key: String) async -> APIKeyValidationResult {
        guard KeychainService.isValidClaudeKeyFormat(key) else {
            return .invalid("Key should start with 'sk-ant-'")
        }
        
        // Validation implemented via ClaudeService
        return .valid // Actual validation done during first API call
    }
}
```

### 4.5 Settings View with Dual API Keys

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        TabView {
            APISettingsView()
                .tabItem { Label("API Keys", systemImage: "key.fill") }
            
            CleaningSettingsView()
                .tabItem { Label("Cleaning", systemImage: "sparkles") }
            
            ExportSettingsView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
            
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 550, height: 450)
    }
}

struct APISettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Form {
            // Mistral OCR API Section
            Section {
                APIKeyRow(
                    title: "Mistral OCR",
                    isConfigured: appState.hasAPIKey,
                    pricing: "$1.00 per 1,000 pages",
                    onConfigure: { /* Show key entry */ },
                    onRemove: { try? appState.keychainService.deleteAPIKey() }
                )
            } header: {
                Label("OCR Processing", systemImage: "doc.text.viewfinder")
            }
            
            // Claude API Section
            Section {
                APIKeyRow(
                    title: "Anthropic Claude",
                    isConfigured: appState.hasClaudeAPIKey,
                    pricing: "$3/$15 per 1M tokens (in/out)",
                    onConfigure: { /* Show key entry */ },
                    onRemove: { try? appState.keychainService.deleteClaudeAPIKey() }
                )
            } header: {
                Label("AI Cleaning", systemImage: "sparkles")
            }
        }
        .formStyle(.grouped)
    }
}
```

### 4.6 Verification Checkpoint

✅ **Phase 2 Complete When:**
- [ ] Mistral API key stores/retrieves from Keychain
- [ ] Claude API key stores/retrieves from Keychain
- [ ] Settings shows both API key sections
- [ ] Key validation works for both providers
- [ ] Cost calculator handles both OCR and Cleaning pricing
- [ ] Onboarding wizard configures at least Mistral key
- [ ] App remembers keys between launches
- [ ] Git commit: "Phase 2: Core services complete"

---

## 5. Phase 3: Document Management

### 5.1 Phase Goals

By the end of this phase:
- Document import via drag-and-drop and file picker
- Input tab displays document queue with workflow stages
- Document validation and page counting
- Queue management (remove, clear)
- Document pathway detection (OCR vs. Direct Clean)

### 5.2 Document Service

```swift
import Foundation
import UniformTypeIdentifiers
import PDFKit
import OSLog

protocol DocumentServiceProtocol {
    func loadDocument(from url: URL) async throws -> Document
    func loadDocuments(from urls: [URL]) async throws -> [Document]
    func readTextContent(from url: URL) throws -> String
}

final class DocumentService: DocumentServiceProtocol {
    static let shared = DocumentService()
    
    private let logger = Logger(subsystem: "com.horus.app", category: "Documents")
    
    /// OCR-required file types
    static let ocrTypes: Set<UTType> = [.pdf, .png, .jpeg, .tiff, .gif, .webP, .bmp]
    
    /// Direct-clean file types (text-based)
    static let textTypes: Set<UTType> = [.plainText, .rtf, .json, .xml, .html]
    
    /// All supported types
    static let supportedTypes: Set<UTType> = ocrTypes.union(textTypes)
    
    /// Maximum file size (100 MB)
    static let maxFileSize: Int64 = 100 * 1024 * 1024
    
    func loadDocument(from url: URL) async throws -> Document {
        guard url.startAccessingSecurityScopedResource() else {
            throw DocumentLoadError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            throw DocumentLoadError.attributesUnavailable
        }
        
        guard fileSize <= Self.maxFileSize else {
            throw DocumentLoadError.fileTooLarge(fileSize, max: Self.maxFileSize)
        }
        
        let ext = url.pathExtension.lowercased()
        guard let contentType = UTType(filenameExtension: ext),
              Self.supportedTypes.contains(where: { contentType.conforms(to: $0) }) else {
            throw DocumentLoadError.unsupportedFormat(ext)
        }
        
        // Get page count for PDFs
        var pageCount: Int? = nil
        if contentType.conforms(to: .pdf) {
            if let pdfDoc = PDFDocument(url: url) {
                if pdfDoc.isEncrypted && pdfDoc.isLocked {
                    throw DocumentLoadError.encryptedPDF
                }
                pageCount = pdfDoc.pageCount
            }
        } else if contentType.conforms(to: .image) {
            pageCount = 1
        }
        
        return Document(
            sourceURL: url,
            contentType: contentType,
            fileSize: fileSize,
            estimatedPageCount: pageCount
        )
    }
    
    func readTextContent(from url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw DocumentLoadError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        return try String(contentsOf: url, encoding: .utf8)
    }
}
```

### 5.3 Input Tab View

```swift
import SwiftUI

struct InputView: View {
    @Environment(AppState.self) private var appState
    @State private var isDropTargeted = false
    
    var body: some View {
        HSplitView {
            // File List
            VStack(spacing: 0) {
                TabHeaderView(
                    title: "Input Queue",
                    subtitle: "\(appState.inputDocuments.count) documents",
                    accentColor: DesignConstants.TabColors.input,
                    icon: "square.and.arrow.down"
                )
                
                Divider()
                
                if appState.inputDocuments.isEmpty {
                    emptyState
                } else {
                    documentList
                }
                
                Divider()
                
                TabFooterView(
                    primaryText: "\(appState.session.pendingDocuments.count) pending",
                    secondaryText: estimatedCostText,
                    accentColor: DesignConstants.TabColors.input
                )
            }
            .frame(minWidth: DesignConstants.Layout.fileListMinWidth,
                   maxWidth: DesignConstants.Layout.fileListMaxWidth)
            
            // Content Pane
            ContentPaneView()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if isDropTargeted { dropOverlay }
        }
    }
    
    private var documentList: some View {
        List(selection: $appState.selectedInputDocumentId) {
            // Group by workflow stage
            ForEach([DocumentWorkflowStage.pending, .processing, .complete], id: \.self) { stage in
                let docs = appState.sessionDocumentsByStage[stage] ?? []
                if !docs.isEmpty {
                    Section(stage.displayName) {
                        ForEach(docs) { document in
                            DocumentListRow(document: document)
                                .tag(document.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Documents", systemImage: "doc.badge.plus")
        } description: {
            Text("Drop PDF or image files here, or click Add Documents")
        } actions: {
            Button("Add Documents...") {
                openFilePicker()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }
}
```

### 5.4 Document List Row with Pipeline Badges

```swift
import SwiftUI

struct DocumentListRow: View {
    let document: Document
    
    var body: some View {
        HStack(spacing: DesignConstants.Spacing.sm) {
            // Document icon with status badge
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: document.requiresOCR ? "doc.fill" : "doc.text.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                
                statusBadge
                    .offset(x: 4, y: 4)
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                // Filename
                Text(document.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                // Status line with pipeline badges
                HStack(spacing: DesignConstants.Spacing.xs) {
                    statusText
                    
                    // Pipeline badges
                    if document.isOCRComplete {
                        PipelineBadge(text: "OCR", color: DesignConstants.TabColors.ocr)
                    }
                    if document.isCleaned {
                        PipelineBadge(text: "Cleaned", color: DesignConstants.TabColors.clean)
                    }
                    if document.isInLibrary {
                        PipelineBadge(text: "Library", color: DesignConstants.TabColors.library)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, DesignConstants.Spacing.sm)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch document.status {
        case .pending:
            Circle().fill(.secondary.opacity(0.3)).frame(width: 10, height: 10)
        case .processing:
            ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        default:
            EmptyView()
        }
    }
}

struct PipelineBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
```

### 5.5 Verification Checkpoint

✅ **Phase 3 Complete When:**
- [ ] Drag-and-drop imports documents
- [ ] File picker opens with ⌘O
- [ ] Documents grouped by workflow stage
- [ ] Pipeline badges display correctly
- [ ] Page counts accurate for PDFs
- [ ] Text files detected as direct-clean pathway
- [ ] Invalid files show appropriate errors
- [ ] Documents can be selected and removed
- [ ] Queue summary shows accurate counts
- [ ] Git commit: "Phase 3: Document management complete"

---

## 6. Phase 4: OCR Processing

### 6.1 Phase Goals

By the end of this phase:
- Mistral OCR API integration with proper error handling
- Processing progress display with real-time updates
- OCR tab showing completed documents awaiting library
- Cost tracking during processing
- Retry mechanism for failed documents

### 6.2 OCR Service

```swift
import Foundation
import OSLog

protocol OCRServiceProtocol {
    func processDocument(_ document: Document, apiKey: String) async throws -> OCRResult
}

actor OCRService: OCRServiceProtocol {
    static let shared = OCRService()
    
    private let logger = Logger(subsystem: "com.horus.app", category: "OCR")
    private let networkClient: NetworkClient
    
    private let baseURL = "https://api.mistral.ai/v1"
    private let model = "mistral-ocr-latest"
    
    func processDocument(_ document: Document, apiKey: String) async throws -> OCRResult {
        logger.info("Processing: \(document.displayName)")
        
        // Load and encode document
        let documentData = try loadDocumentData(from: document.sourceURL)
        let base64Content = documentData.base64EncodedString()
        
        // Build request
        let request = OCRRequest(
            model: model,
            document: OCRDocumentInput(
                type: document.contentType.conforms(to: .pdf) ? "document_url" : "image_url",
                data: "data:\(mimeType(for: document));base64,\(base64Content)"
            )
        )
        
        // Send request
        let startTime = Date()
        let response: OCRResponse = try await networkClient.post(
            url: URL(string: "\(baseURL)/ocr")!,
            body: request,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ],
            timeout: 300 // 5 minutes for large documents
        )
        let duration = Date().timeIntervalSince(startTime)
        
        // Transform response
        let pages = response.pages.enumerated().map { index, page in
            OCRPage(
                index: index,
                markdown: page.markdown,
                tables: page.tables ?? [],
                images: page.images ?? [],
                dimensions: page.dimensions
            )
        }
        
        let cost = CostCalculator.shared.calculateOCRCost(pages: pages.count)
        
        return OCRResult(
            documentId: document.id,
            pages: pages,
            model: model,
            cost: cost,
            processingDuration: duration,
            completedAt: Date()
        )
    }
}
```

### 6.3 Processing ViewModel

```swift
import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class ProcessingViewModel {
    private let logger = Logger(subsystem: "com.horus.app", category: "Processing")
    
    private let ocrService: OCRServiceProtocol
    private let costCalculator: CostCalculatorProtocol
    
    private(set) var isProcessing = false
    private(set) var isPaused = false
    private(set) var currentDocument: Document?
    private(set) var overallProgress: Double = 0
    private(set) var processedCount = 0
    private(set) var totalCount = 0
    
    private var processingTask: Task<Void, Never>?
    
    func processAllPending(in session: ProcessingSession) {
        let pending = session.pendingDocuments
        guard !pending.isEmpty else { return }
        
        totalCount = pending.count
        processedCount = 0
        isProcessing = true
        
        processingTask = Task {
            for document in pending {
                guard !Task.isCancelled && !isPaused else { break }
                
                currentDocument = document
                await processDocument(document, in: session)
                processedCount += 1
                overallProgress = Double(processedCount) / Double(totalCount)
            }
            
            isProcessing = false
            currentDocument = nil
        }
    }
    
    private func processDocument(_ document: Document, in session: ProcessingSession) async {
        // Update status to processing
        var doc = document
        doc.status = .processing(progress: 0)
        session.updateDocument(doc)
        
        do {
            guard let apiKey = try KeychainService.shared.retrieveAPIKey() else {
                throw OCRError.missingAPIKey
            }
            
            let result = try await ocrService.processDocument(document, apiKey: apiKey)
            
            doc.result = result
            doc.status = .completed
            doc.processedAt = Date()
            
        } catch {
            doc.status = .failed
            doc.error = DocumentError(
                code: "ocr_failed",
                message: error.localizedDescription,
                isRetryable: isRetryable(error)
            )
            logger.error("OCR failed: \(error.localizedDescription)")
        }
        
        session.updateDocument(doc)
    }
    
    func cancelProcessing() {
        processingTask?.cancel()
        isProcessing = false
        isPaused = false
    }
    
    func pauseProcessing() {
        isPaused = true
    }
    
    func resumeProcessing(in session: ProcessingSession) {
        isPaused = false
        // Continue with remaining documents
    }
}
```

### 6.4 OCR Tab View

```swift
import SwiftUI

struct OCRTabView: View {
    @Environment(AppState.self) private var appState
    
    /// Documents that completed OCR but aren't in library yet
    var awaitingDocuments: [Document] {
        appState.awaitingLibraryDocuments.filter { $0.requiresOCR }
    }
    
    var body: some View {
        HSplitView {
            // File List
            VStack(spacing: 0) {
                TabHeaderView(
                    title: "OCR Results",
                    subtitle: processingSubtitle,
                    accentColor: DesignConstants.TabColors.ocr,
                    icon: "doc.text.viewfinder"
                )
                
                Divider()
                
                // Processing indicator
                if appState.isProcessing {
                    ProcessingProgressBar(viewModel: appState.processingViewModel)
                }
                
                if awaitingDocuments.isEmpty {
                    emptyState
                } else {
                    documentList
                }
                
                Divider()
                
                TabFooterView(
                    primaryText: "\(awaitingDocuments.count) awaiting action",
                    secondaryText: nil,
                    accentColor: DesignConstants.TabColors.ocr
                )
            }
            .frame(minWidth: DesignConstants.Layout.fileListMinWidth,
                   maxWidth: DesignConstants.Layout.fileListMaxWidth)
            
            // Content Pane - OCR Preview
            OCRPreviewPane()
        }
    }
    
    private var processingSubtitle: String {
        if appState.isProcessing {
            return "Processing \(appState.processingViewModel.processedCount + 1) of \(appState.processingViewModel.totalCount)"
        }
        return "\(awaitingDocuments.count) documents ready"
    }
}
```

### 6.5 Verification Checkpoint

✅ **Phase 4 Complete When:**
- [ ] "Process All" triggers OCR processing
- [ ] Progress displays per-document and overall
- [ ] OCR results populate correctly
- [ ] Cost updates during processing
- [ ] Failed documents show error messages
- [ ] Retry mechanism works
- [ ] Cancel/Pause/Resume work correctly
- [ ] OCR tab shows documents awaiting library
- [ ] Git commit: "Phase 4: OCR processing complete"

---

## 7. Phase 5: Library & Export

### 7.1 Phase Goals

By the end of this phase:
- Library tab showing explicitly added documents
- "Add to Library" action from OCR and Clean tabs
- Export in multiple formats (Markdown, JSON, Plain Text)
- Batch export capability
- Copy to clipboard functionality

### 7.2 Library Tab View

```swift
import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HSplitView {
            // File List
            VStack(spacing: 0) {
                TabHeaderView(
                    title: "Library",
                    subtitle: "\(appState.libraryDocuments.count) documents",
                    accentColor: DesignConstants.TabColors.library,
                    icon: "books.vertical"
                )
                
                Divider()
                
                if appState.libraryDocuments.isEmpty {
                    emptyState
                } else {
                    documentList
                }
                
                Divider()
                
                // Stats footer
                LibraryStatsFooter()
            }
            .frame(minWidth: DesignConstants.Layout.fileListMinWidth,
                   maxWidth: DesignConstants.Layout.fileListMaxWidth)
            
            // Content Pane - Document Preview
            LibraryPreviewPane()
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Library Empty", systemImage: "books.vertical")
        } description: {
            Text("Process documents and add them to your library")
        } actions: {
            Button("Go to Input") {
                appState.selectedTab = .input
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var documentList: some View {
        List(selection: $appState.selectedLibraryDocumentId) {
            ForEach(appState.libraryDocuments) { document in
                DocumentListRow(document: document)
                    .tag(document.id)
                    .contextMenu {
                        libraryContextMenu(for: document)
                    }
            }
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    private func libraryContextMenu(for document: Document) -> some View {
        Button("Export...") {
            appState.selectedLibraryDocumentId = document.id
            appState.showingExportSheet = true
        }
        
        Button("Copy to Clipboard") {
            appState.copySelectedToClipboard()
        }
        
        if document.canClean && !document.isCleaned {
            Divider()
            Button("Clean Document...") {
                appState.navigateToClean(with: document)
            }
        }
        
        Divider()
        
        Button("Remove from Library", role: .destructive) {
            appState.requestDeleteDocument(document)
        }
    }
}
```

### 7.3 Export Service

```swift
import Foundation
import OSLog

protocol ExportServiceProtocol {
    func export(_ document: Document, format: ExportFormat, to url: URL) throws
    func exportBatch(_ documents: [Document], format: ExportFormat, to folder: URL) throws -> [URL]
}

final class ExportService: ExportServiceProtocol {
    static let shared = ExportService()
    
    private let logger = Logger(subsystem: "com.horus.app", category: "Export")
    
    func export(_ document: Document, format: ExportFormat, to url: URL) throws {
        let content: String
        
        switch format {
        case .markdown:
            content = generateMarkdown(for: document)
        case .json:
            content = try generateJSON(for: document)
        case .plainText:
            content = generatePlainText(for: document)
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        logger.info("Exported \(document.displayName) as \(format.displayName)")
    }
    
    private func generateMarkdown(for document: Document) -> String {
        var output = "---\n"
        output += "title: \(document.displayName)\n"
        output += "source: \(document.sourceURL.lastPathComponent)\n"
        output += "processed: \(ISO8601DateFormatter().string(from: document.processedAt ?? Date()))\n"
        
        if let result = document.result {
            output += "pages: \(result.pages.count)\n"
            output += "words: \(result.wordCount)\n"
            output += "ocr_cost: $\(result.cost)\n"
        }
        
        if let cleaned = document.cleanedContent {
            output += "cleaning_cost: $\(cleaned.totalCost)\n"
        }
        
        output += "---\n\n"
        
        // Use cleaned content if available, otherwise OCR result
        if let cleaned = document.cleanedContent {
            output += cleaned.cleanedMarkdown
        } else if let result = document.result {
            output += result.fullText
        }
        
        return output
    }
}
```

### 7.4 Verification Checkpoint

✅ **Phase 5 Complete When:**
- [ ] "Add to Library" works from OCR tab
- [ ] Library tab shows only explicitly added documents
- [ ] Document preview displays correctly
- [ ] Export produces valid Markdown files
- [ ] Export produces valid JSON files
- [ ] Export produces valid Plain Text files
- [ ] Batch export works correctly
- [ ] Copy to clipboard works
- [ ] Git commit: "Phase 5: Library and export complete"

---

## 8. Phase 6: Cleaning Pipeline

### 8.1 Phase Goals

By the end of this phase:
- Claude API integration for AI-powered cleaning
- 14-step cleaning pipeline with progress tracking
- Clean tab with document selection
- Configuration options for cleaning behavior
- Boundary detection with validation safeguards
- VirtualizedTextView for large document preview

### 8.2 Cleaning Architecture Overview

The cleaning pipeline transforms raw OCR output into clean AI training data:

```
Raw OCR Text
     │
     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CLEANING PIPELINE (14 STEPS)                  │
├─────────────────────────────────────────────────────────────────┤
│ 1. Normalize Text        │ Fix encoding, normalize whitespace   │
│ 2. Detect Patterns       │ Identify headers, footers, TOC, etc. │
│ 3. Remove Front Matter   │ Title pages, copyright, dedications  │
│ 4. Remove TOC            │ Table of contents with validation    │
│ 5. Remove Headers        │ Running headers with safety checks   │
│ 6. Remove Footers        │ Page numbers, running footers        │
│ 7. Remove Back Matter    │ Index, bibliography, appendices      │
│ 8. Remove Footnotes      │ Footnote markers and content         │
│ 9. Remove Citations      │ In-text citations if configured      │
│ 10. Remove End Markers   │ Chapter ends, section breaks         │
│ 11. Fix OCR Artifacts    │ Common OCR errors and artifacts      │
│ 12. Normalize Structure  │ Paragraph and section normalization  │
│ 13. Final Polish         │ Clean up spacing, formatting         │
│ 14. Generate Metadata    │ Extract document metadata            │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
Clean Training Data
```

### 8.3 Cleaning Step Enum

```swift
import Foundation

/// The 14 steps of the cleaning pipeline
enum CleaningStep: Int, CaseIterable, Identifiable {
    case normalizeText = 1
    case detectPatterns = 2
    case removeFrontMatter = 3
    case removeTOC = 4
    case removeHeaders = 5
    case removeFooters = 6
    case removeBackMatter = 7
    case removeFootnotes = 8
    case removeCitations = 9
    case removeEndMarkers = 10
    case fixOCRArtifacts = 11
    case normalizeStructure = 12
    case finalPolish = 13
    case generateMetadata = 14
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .normalizeText: return "Normalize Text"
        case .detectPatterns: return "Detect Patterns"
        case .removeFrontMatter: return "Remove Front Matter"
        case .removeTOC: return "Remove Table of Contents"
        case .removeHeaders: return "Remove Headers"
        case .removeFooters: return "Remove Footers"
        case .removeBackMatter: return "Remove Back Matter"
        case .removeFootnotes: return "Remove Footnotes"
        case .removeCitations: return "Remove Citations"
        case .removeEndMarkers: return "Remove End Markers"
        case .fixOCRArtifacts: return "Fix OCR Artifacts"
        case .normalizeStructure: return "Normalize Structure"
        case .finalPolish: return "Final Polish"
        case .generateMetadata: return "Generate Metadata"
        }
    }
    
    var requiresAI: Bool {
        switch self {
        case .detectPatterns, .removeFrontMatter, .removeTOC, 
             .removeBackMatter, .removeFootnotes:
            return true
        default:
            return false
        }
    }
}
```

### 8.4 Cleaning ViewModel

```swift
import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class CleaningViewModel {
    private let logger = Logger(subsystem: "com.horus.app", category: "Cleaning")
    
    // MARK: - Dependencies
    private let cleaningService: CleaningService
    private let keychainService: KeychainServiceProtocol
    
    // MARK: - State
    private(set) var document: Document?
    private(set) var state: CleaningState = .idle
    private(set) var currentStep: CleaningStep?
    private(set) var progress: CleaningProgress?
    private(set) var cleanedContent: CleanedContent?
    private(set) var detectedPatterns: DetectedPatterns?
    
    var configuration = CleaningConfiguration()
    
    /// Callback when cleaning completes (for session persistence)
    var onCleaningCompleted: ((CleanedContent) -> Void)?
    
    // MARK: - Computed Properties
    
    var canStartCleaning: Bool {
        document?.canClean == true && state != .processing
    }
    
    var originalText: String {
        document?.result?.fullText ?? ""
    }
    
    var cleanedText: String {
        cleanedContent?.cleanedMarkdown ?? originalText
    }
    
    // MARK: - Setup
    
    func setup(with document: Document) {
        self.document = document
        self.state = .ready
        self.cleanedContent = nil
        self.detectedPatterns = nil
    }
    
    func loadExistingCleanedContent(_ content: CleanedContent) {
        self.cleanedContent = content
        self.state = .completed
    }
    
    // MARK: - Actions
    
    func startCleaning() async {
        guard let document, let ocrResult = document.result else { return }
        guard let apiKey = try? keychainService.retrieveClaudeAPIKey() else {
            state = .error(CleaningError.missingAPIKey)
            return
        }
        
        state = .processing
        
        do {
            let result = try await cleaningService.clean(
                text: ocrResult.fullText,
                configuration: configuration,
                apiKey: apiKey,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.progress = progress
                        self?.currentStep = progress.currentStep
                    }
                }
            )
            
            cleanedContent = result
            state = .completed
            
            // Notify for session persistence
            onCleaningCompleted?(result)
            
        } catch {
            state = .error(error)
            logger.error("Cleaning failed: \(error.localizedDescription)")
        }
    }
    
    func applyPreset(_ preset: CleaningPreset) {
        configuration = preset.configuration
    }
}

enum CleaningState: Equatable {
    case idle
    case ready
    case processing
    case completed
    case error(Error)
    
    static func == (lhs: CleaningState, rhs: CleaningState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.ready, .ready), 
             (.processing, .processing), (.completed, .completed):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
```

### 8.5 Clean Tab View

```swift
import SwiftUI

struct CleanTabView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HSplitView {
            // File List
            VStack(spacing: 0) {
                TabHeaderView(
                    title: "Clean",
                    subtitle: cleaningSubtitle,
                    accentColor: DesignConstants.TabColors.clean,
                    icon: "sparkles"
                )
                
                Divider()
                
                if appState.cleanableDocuments.isEmpty {
                    emptyState
                } else {
                    documentList
                }
                
                Divider()
                
                TabFooterView(
                    primaryText: "\(appState.cleanableDocuments.count) documents",
                    secondaryText: nil,
                    accentColor: DesignConstants.TabColors.clean
                )
            }
            .frame(minWidth: DesignConstants.Layout.fileListMinWidth,
                   maxWidth: DesignConstants.Layout.fileListMaxWidth)
            
            // Content Pane - Before/After Preview
            CleaningContentPane()
        }
    }
    
    private var documentList: some View {
        List(selection: $appState.selectedCleanDocumentId) {
            ForEach(appState.cleanableDocuments) { document in
                DocumentListRow(document: document)
                    .tag(document.id)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: appState.selectedCleanDocumentId) { _, newId in
            if let id = newId,
               let document = appState.cleanableDocuments.first(where: { $0.id == id }) {
                appState.setupCleaningViewModel(for: document)
            }
        }
    }
}
```

### 8.6 Boundary Detection with Validation

**Critical Safety Pattern** — All boundary detection operations must validate AI responses:

```swift
import Foundation

/// Validates boundary detection results to prevent catastrophic content removal
struct BoundaryValidation {
    
    /// Maximum percentage of document that can be removed by a single operation
    static let maxRemovalPercentage: Double = 0.30
    
    /// Minimum content that must remain after any removal
    static let minRemainingPercentage: Double = 0.50
    
    /// Validates a proposed boundary detection result
    static func validate(
        proposedStart: Int,
        proposedEnd: Int,
        totalLines: Int,
        operationType: String
    ) -> ValidationResult {
        // Check for obviously wrong boundaries
        guard proposedStart >= 0 && proposedEnd <= totalLines else {
            return .rejected(reason: "Boundaries outside document range")
        }
        
        guard proposedStart < proposedEnd else {
            return .rejected(reason: "Start must be before end")
        }
        
        let linesToRemove = proposedEnd - proposedStart
        let removalPercentage = Double(linesToRemove) / Double(totalLines)
        let remainingPercentage = 1.0 - removalPercentage
        
        // Check removal percentage
        if removalPercentage > maxRemovalPercentage {
            return .rejected(reason: "\(operationType) would remove \(Int(removalPercentage * 100))% of document (max \(Int(maxRemovalPercentage * 100))%)")
        }
        
        // Check remaining content
        if remainingPercentage < minRemainingPercentage {
            return .rejected(reason: "Only \(Int(remainingPercentage * 100))% would remain (min \(Int(minRemainingPercentage * 100))%)")
        }
        
        return .accepted
    }
    
    enum ValidationResult {
        case accepted
        case rejected(reason: String)
    }
}
```

### 8.7 Verification Checkpoint

✅ **Phase 6 Complete When:**
- [ ] Claude API integration works
- [ ] 14-step pipeline executes in order
- [ ] Progress displays per-step updates
- [ ] Boundary validation prevents catastrophic removal
- [ ] Clean tab shows cleanable documents
- [ ] Before/After preview works
- [ ] Cleaning configuration options work
- [ ] "Add to Library" saves cleaned content
- [ ] Session persistence preserves cleaned content
- [ ] Git commit: "Phase 6: Cleaning pipeline complete"

---

## 9. Phase 7: Polish & Testing

### 9.1 Polish Tasks

**Empty States:**
- [ ] Review all empty states for clarity
- [ ] Ensure actionable guidance in empty states
- [ ] Consistent styling across tabs

**Error Messages:**
- [ ] All errors display user-friendly messages
- [ ] Recovery suggestions included
- [ ] Retry actions available where appropriate

**Keyboard Navigation:**
- [ ] ⌘1-5 switch tabs
- [ ] ⌘O opens file picker
- [ ] ⌘R processes all pending
- [ ] ⌘K starts cleaning
- [ ] ⌘L adds to library
- [ ] Delete removes selected
- [ ] Arrow keys navigate lists

**Accessibility:**
- [ ] VoiceOver labels on all controls
- [ ] Sufficient color contrast
- [ ] Keyboard-only navigation works
- [ ] Focus indicators visible

**Visual Polish:**
- [ ] Light/Dark mode tested
- [ ] Consistent spacing (4-point grid)
- [ ] Pixel-perfect alignment
- [ ] Animations smooth (60fps)

### 9.2 Testing Tasks

**Unit Tests:**
- [ ] Document model tests
- [ ] ProcessingSession tests
- [ ] CostCalculator tests
- [ ] BoundaryValidation tests
- [ ] Export format generation tests

**Integration Tests:**
- [ ] OCR service with mock responses
- [ ] Cleaning service with mock responses
- [ ] Export service file generation

**UI Tests:**
- [ ] Tab navigation
- [ ] Document import flow
- [ ] Processing flow
- [ ] Export flow
- [ ] Settings changes

### 9.3 Final Verification

✅ **Phase 7 Complete When:**
- [ ] All polish tasks addressed
- [ ] All tests pass
- [ ] No Xcode warnings
- [ ] Memory usage reasonable
- [ ] Performance acceptable with large documents
- [ ] Documentation complete
- [ ] Git commit: "Phase 7: Polish complete — v1.0"

---

## 10. Verification Checkpoints

### Quick Reference

| Phase | Key Verification |
|:------|:-----------------|
| 1. Foundation | 5-tab navigation, design system in place |
| 2. Services | Dual API keys store/retrieve |
| 3. Documents | Import works, pathway detection correct |
| 4. OCR | Processing completes, cost tracked |
| 5. Library | Explicit library membership, export works |
| 6. Cleaning | Pipeline executes, validation prevents errors |
| 7. Polish | All tests pass, accessibility verified |

---

## 11. Common Pitfalls

### 11.1 SwiftUI Pitfalls

**Problem:** View not updating when state changes  
**Solution:** Ensure model is `@Observable` and view receives it via `@Environment`

**Problem:** List selection not syncing  
**Solution:** Use `.tag()` matching the selection binding type exactly

**Problem:** NavigationSplitView columns collapsing unexpectedly  
**Solution:** Set explicit min/ideal/max widths on all columns

### 11.2 Async/Await Pitfalls

**Problem:** UI not updating from async context  
**Solution:** Use `@MainActor` on ViewModels or explicit `await MainActor.run { }`

**Problem:** Task not cancelling  
**Solution:** Store `Task` reference and call `.cancel()`; check `Task.isCancelled`

**Problem:** Race conditions in progress updates  
**Solution:** Use actors for shared state, ensure single writer

### 11.3 API Integration Pitfalls

**Problem:** Large files causing memory issues  
**Solution:** Stream base64 encoding; don't load entire file into memory

**Problem:** Rate limits causing failures  
**Solution:** Implement exponential backoff with jitter

**Problem:** Timeouts on large documents  
**Solution:** Set appropriate timeouts (300s for OCR); show progress

### 11.4 Boundary Detection Pitfalls

**Problem:** AI boundary detection removes too much content  
**Solution:** Always validate with BoundaryValidation before applying

**Problem:** Heuristic fallbacks not triggering  
**Solution:** Ensure fallback chain: AI → Heuristic → Safe Default

**Problem:** Content verification failing  
**Solution:** Implement content sampling before/after removal

### 11.5 Keychain Pitfalls

**Problem:** Keychain access failing in debug  
**Solution:** Ensure app is signed; add Keychain Sharing entitlement

**Problem:** Keys not persisting between launches  
**Solution:** Check `kSecAttrAccessible` value; use `kSecAttrAccessibleWhenUnlocked`

---

## 12. Appendix: Code Templates

### 12.1 ViewModel Template

```swift
import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class FeatureViewModel {
    private let logger = Logger(subsystem: "com.horus.app", category: "Feature")
    
    // Dependencies
    private let someService: SomeServiceProtocol
    
    // State
    private(set) var isLoading = false
    private(set) var error: Error?
    private(set) var data: [Item] = []
    
    init(someService: SomeServiceProtocol = SomeService.shared) {
        self.someService = someService
    }
    
    func loadData() async {
        isLoading = true
        error = nil
        
        do {
            data = try await someService.fetchData()
        } catch {
            self.error = error
            logger.error("Load failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}
```

### 12.2 Service Protocol Template

```swift
import Foundation

protocol SomeServiceProtocol {
    func fetchData() async throws -> [Item]
    func processItem(_ item: Item) async throws -> Result
}

final class SomeService: SomeServiceProtocol {
    static let shared = SomeService()
    
    func fetchData() async throws -> [Item] {
        // Implementation
    }
    
    func processItem(_ item: Item) async throws -> Result {
        // Implementation
    }
}

// Mock for testing
final class MockSomeService: SomeServiceProtocol {
    var mockData: [Item] = []
    var shouldFail = false
    
    func fetchData() async throws -> [Item] {
        if shouldFail { throw TestError.simulated }
        return mockData
    }
    
    func processItem(_ item: Item) async throws -> Result {
        if shouldFail { throw TestError.simulated }
        return Result()
    }
}
```

### 12.3 Tab View Template

```swift
import SwiftUI

struct FeatureTabView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HSplitView {
            // File List Column
            VStack(spacing: 0) {
                TabHeaderView(
                    title: "Feature",
                    subtitle: subtitle,
                    accentColor: DesignConstants.TabColors.feature,
                    icon: "star"
                )
                
                Divider()
                
                if items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
                
                Divider()
                
                TabFooterView(
                    primaryText: "\(items.count) items",
                    secondaryText: nil,
                    accentColor: DesignConstants.TabColors.feature
                )
            }
            .frame(minWidth: DesignConstants.Layout.fileListMinWidth,
                   maxWidth: DesignConstants.Layout.fileListMaxWidth)
            
            // Content Pane
            ContentPane()
        }
    }
}
```

### 12.4 Inspector Section Template

```swift
import SwiftUI

struct FeatureInspectorView: View {
    let document: Document
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.lg) {
                // Document Info Section
                InspectorSection(title: "Document") {
                    InspectorRow(label: "Name", value: document.displayName)
                    InspectorRow(label: "Type", value: document.fileExtension.uppercased())
                    InspectorRow(label: "Size", value: document.formattedFileSize)
                }
                
                // Processing Section
                if let result = document.result {
                    InspectorSection(title: "Processing") {
                        InspectorRow(label: "Pages", value: "\(result.pages.count)")
                        InspectorRow(label: "Words", value: "\(result.wordCount)")
                        InspectorRow(label: "Cost", value: "$\(result.cost)")
                    }
                }
                
                // Actions Section
                InspectorSection(title: "Actions") {
                    Button("Export...") { /* action */ }
                    Button("Add to Library") { /* action */ }
                }
            }
            .padding(DesignConstants.Spacing.lg)
        }
    }
}
```

---

## Document History

| Version | Date | Author | Changes |
|:--------|:-----|:-------|:--------|
| 1.0 | January 2025 | Claude | Initial draft (Mistral-only, 3-screen) |
| 2.0 | January 2026 | Claude | Complete rewrite for 5-tab architecture, dual API integration, cleaning pipeline |

---

*This document is part of the Horus documentation suite.*

**Related Documents:**
- PRD v2.0 — Product requirements and scope
- Technical Architecture v2.0 — System design and patterns
- API Integration Guide v2.0 — Mistral and Claude API details
- UI/UX Specification v2.0 — Interface design standards
- Cleaning Feature Specification — Cleaning pipeline details
- Cleaning Implementation Plan — Cleaning development guide
