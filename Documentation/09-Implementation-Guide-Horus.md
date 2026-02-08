# Horus — Implementation Guide (Complete Rebuild from Zero)

**Version:** 3.0 — February 2026

**Document Purpose:** This guide enables a developer (human or AI pair) to reconstruct Horus in its current production form from an empty Xcode project. It specifies exact build order, dependency relationships, file structure, and implementation sequence to minimize circular dependencies and maximize maintainability.

---

## Executive Summary

Horus is a macOS document processing application that combines OCR (via Mistral's API) and intelligent document cleaning (via Claude's API). The implementation spans 9 sequential phases over 33 days, moving from foundational architecture through core services, document management, processing pipelines, and UI.

This guide is organized by phase with explicit build order within each phase. Each step specifies:
- File name and purpose
- Dependencies (what must exist first)
- Key types and protocols
- Integration points
- Verification criteria

---

## Phase 1: Foundation (Days 1-3)

### Step 1.1: Xcode Project Setup

**Objective:** Create the base project with correct configuration.

**Actions:**
1. Open Xcode → File → New → Project
2. Select "macOS" → "App"
3. Configure:
   - **Product Name:** Horus
   - **Team:** Your Apple Developer Team
   - **Organization Identifier:** com.yourdomain
   - **Language:** Swift
   - **Interface:** SwiftUI
   - **Include Tests:** Yes
   - **Include Core Data:** No

4. **Enable App Sandbox:**
   - Select project in navigator
   - Select Horus target
   - Capabilities tab → "+ Capability"
   - Add "App Sandbox"
   - Check: "Outgoing Connections (Client)"

5. **Enable Keychain Access:**
   - "+ Capability" → "Keychain Sharing"
   - Keep default keychain group: com.apple.security.application-groups

6. **Code Signing:**
   - Signing & Capabilities tab
   - Ensure "Automatically manage signing" is checked

7. **Swift Version:**
   - Build Settings → Search "Swift Version"
   - Set to "5.10" or higher (Swift 6.0 if available)

**Output:** Empty SwiftUI macOS project ready for model definitions.

---

### Step 1.2: Core Models (Build Order Critical)

The order below prevents circular imports:

#### 1.2.1: ExportFormat.swift

**File:** `Horus/Models/ExportFormat.swift`

**Purpose:** Define supported export formats with UTType mapping.

**Key Types:**
```swift
enum ExportFormat: String, CaseIterable, Codable {
    case markdown = "Markdown"
    case json = "JSON"
    case plainText = "Plain Text"

    var fileExtension: String { /* .md, .json, .txt */ }
    var utType: UTType { /* application/pdf, etc */ }
    var mimeType: String { /* text/markdown, etc */ }
}
```

**Dependencies:** None

---

#### 1.2.2: DocumentStatus.swift

**File:** `Horus/Models/DocumentStatus.swift`

**Purpose:** Enum for document processing lifecycle.

**Key Types:**
```swift
enum DocumentStatus: String, Codable, Hashable {
    case pending, validating, processing, completed, failed, cancelled

    var isTerminal: Bool { /* completed, failed, cancelled */ }
    var isProcessing: Bool { /* validating, processing */ }
}
```

**Dependencies:** None

---

#### 1.2.3: DocumentWorkflowStage.swift

**File:** `Horus/Models/DocumentWorkflowStage.swift`

**Purpose:** Multi-stage pipeline tracking.

**Key Types:**
```swift
enum DocumentWorkflowStage: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case complete = "complete"
}
```

**Dependencies:** None

---

#### 1.2.4: Document.swift

**File:** `Horus/Models/Document.swift`

**Purpose:** Core document model representing a file through processing.

**Key Types:**
```swift
@Observable
final class Document: Identifiable, Codable {
    let id: UUID
    var sourceURL: URL
    var contentType: UTType
    var fileSize: Int
    var status: DocumentStatus
    var pageCount: Int
    var metadata: DocumentMetadata?
    var ocrResult: OCRResult?
    var cleanedContent: CleanedContent?
    var validationErrors: [String]
    var pathways: [ProcessingPathway] // OCR, Clean, both

    // Properties determine workflow
}

struct ProcessingPathway: Codable {
    var includeOCR: Bool
    var includeCleaning: Bool
    var cleaningPreset: PresetType?
}
```

**Dependencies:** ExportFormat, DocumentStatus, DocumentWorkflowStage (will add DocumentMetadata, OCRResult, CleanedContent later)

---

#### 1.2.5: OCRResult.swift

**File:** `Horus/Models/OCRResult.swift`

**Purpose:** OCR processing output model.

**Key Types:**
```swift
struct OCRResult: Codable {
    let id: UUID
    let pages: [OCRPage]
    let tables: [OCRTable]
    let images: [OCRImage]
    let processingTime: TimeInterval
    let characterCount: Int
    let estimatedCost: Decimal

    var totalPages: Int { pages.count }
}

struct OCRPage: Codable {
    let pageNumber: Int
    let text: String
    let confidence: Double
    let dimensions: OCRDimensions
}

struct OCRDimensions: Codable {
    let width: Double, height: Double, dpi: Int
}
```

**Dependencies:** None

---

#### 1.2.6: ProcessingSession.swift

**File:** `Horus/Models/ProcessingSession.swift`

**Purpose:** Session-level aggregation and state management.

**Key Types:**
```swift
@Observable
final class ProcessingSession: Identifiable {
    let id: UUID
    @ObservationIgnored var documents: [Document] = []
    var currentDocumentID: UUID?
    var totalCost: Decimal = 0
    var isProcessing: Bool = false

    // Computed collections
    var activeDocuments: [Document] { /* status != completed, failed */ }
    var completedDocuments: [Document] { /* status == completed */ }
    var failedDocuments: [Document] { /* status == failed */ }

    // Limit to 50 documents max
    func addDocument(_ doc: Document) throws { /* throws if > 50 */ }
}
```

**Dependencies:** Document, DocumentStatus

**Key Note:** Use @Observable (Xcode 15+, Swift 5.9+), not ObservableObject. This ensures reactive updates across the app.

---

#### 1.2.7: TokenEstimator.swift

**File:** `Horus/Models/TokenEstimator.swift`

**Purpose:** Estimate OCR token consumption.

**Key Types:**
```swift
struct TokenEstimator {
    static func estimateTokens(forText text: String) -> Int {
        // Hybrid model: characters / 4 + words / 1.3
        let charTokens = text.count / 4
        let wordTokens = text.split(separator: " ").count / 1.3
        return Int(Double(charTokens) + wordTokens)
    }

    static func estimateCost(tokens: Int, pricePerThousand: Decimal) -> Decimal {
        // $0.001 per page (Mistral)
        return (Decimal(tokens) / 1000) * pricePerThousand
    }
}
```

**Dependencies:** None

---

#### 1.2.8: UserPreferences.swift

**File:** `Horus/Models/UserPreferences.swift`

**Purpose:** User settings persisted to UserDefaults.

**Key Types:**
```swift
@Observable
final class UserPreferences {
    @ObservationIgnored private let defaults = UserDefaults.standard

    // Cost tracking
    var showEstimatedCosts: Bool { /* get/set */ }
    var costWarningThreshold: Decimal { /* get/set */ }

    // Export preferences
    var defaultExportFormat: ExportFormat { /* get/set */ }
    var autoOpenExportedFiles: Bool { /* get/set */ }

    // Processing
    var autoStartProcessing: Bool { /* get/set */ }
    var maxConcurrentDocuments: Int { /* get/set */ }

    // UI
    var sidebarWidth: Double { /* get/set */ }
    var inspectorWidth: Double { /* get/set */ }
    var darkMode: Bool { /* get/set */ }

    // Cleaning
    var defaultCleaningPreset: PresetType { /* get/set */ }
    var autoDetectContentType: Bool { /* get/set */ }
}
```

**Dependencies:** ExportFormat, PresetType (will define later)

---

### Step 1.3: Error Types

#### 1.3.1: HorusError.swift

**File:** `Horus/Errors/HorusError.swift`

**Purpose:** Top-level error hierarchy.

**Key Types:**
```swift
enum HorusError: LocalizedError {
    case documentLoadError(String)
    case networkError(String)
    case keyChainError(String)
    case ocrProcessingError(String)
    case cleaningError(String)
    case exportError(String)
    case validationError(String)

    var errorDescription: String? { /* localized messages */ }
    var recoverySuggestion: String? { /* actionable suggestions */ }
}
```

**Dependencies:** None

---

#### 1.3.2: CleaningError.swift

**File:** `Horus/Errors/CleaningError.swift`

**Purpose:** Domain-specific cleaning pipeline errors.

**Key Types:**
```swift
enum CleaningError: LocalizedError {
    case invalidContentType
    case boundaryDetectionFailed(String)
    case reflowFailed(String)
    case verificationFailed(String)
    case phaseTimeout

    var isRetryable: Bool { /* some errors warrant retry */ }
}
```

**Dependencies:** None

---

### Step 1.4: Design Constants

#### 1.4.1: DesignConstants.swift

**File:** `Horus/Utilities/DesignConstants.swift`

**Purpose:** Centralized design system values.

**Key Values:**
```swift
struct DesignConstants {
    // Spacing (8pt grid)
    static let spacing8 = 8.0
    static let spacing12 = 12.0
    static let spacing16 = 16.0
    static let spacing20 = 20.0
    static let spacing24 = 24.0

    // Layout
    static let sidebarMinWidth = 280.0
    static let inspectorMinWidth = 300.0
    static let contentMinWidth = 400.0

    // Typography
    static let titleFont = Font.system(size: 24, weight: .bold)
    static let headlineFont = Font.system(size: 18, weight: .semibold)
    static let bodyFont = Font.system(size: 14)

    // Corner radius
    static let smallRadius = 4.0
    static let mediumRadius = 8.0
    static let largeRadius = 12.0

    // Animations
    static let standardDuration = 0.3
    static let quickDuration = 0.15
}
```

**Dependencies:** None

---

### Step 1.5: Extensions

#### 1.5.1: Accessibility.swift

**File:** `Horus/Extensions/Accessibility.swift`

**Purpose:** VoiceOver and accessibility helpers.

**Key Extensions:**
```swift
extension View {
    func accessibilityLabel(_ label: String) -> some View {
        self.accessibilityLabel(Text(label))
    }

    func accessibilityHint(_ hint: String) -> some View {
        self.accessibilityHint(Text(hint))
    }
}
```

**Dependencies:** None

---

#### 1.5.2: Notifications.swift

**File:** `Horus/Extensions/Notifications.swift`

**Purpose:** App event notification definitions.

**Key Definitions:**
```swift
extension NSNotification.Name {
    static let documentImported = NSNotification.Name("documentImported")
    static let processingStarted = NSNotification.Name("processingStarted")
    static let processingCompleted = NSNotification.Name("processingCompleted")
    static let cleaningCompleted = NSNotification.Name("cleaningCompleted")
}
```

**Dependencies:** None

---

### Step 1.6: App Shell

#### 1.6.1: AppState.swift

**File:** `Horus/App/AppState.swift`

**Purpose:** Singleton app state with service injection.

**Key Types:**
```swift
@Observable
final class AppState: ObservableObject {
    // Services
    var documentService: DocumentServiceProtocol
    var keyChainService: KeyChainServiceProtocol
    var networkClient: NetworkClientProtocol

    // State
    var session: ProcessingSession
    var preferences: UserPreferences
    var selectedDocumentID: UUID?
    var navigationTab: NavigationTab = .input

    // Computed
    var selectedDocument: Document? {
        session.documents.first { $0.id == selectedDocumentID }
    }

    init(
        documentService: DocumentServiceProtocol? = nil,
        keyChainService: KeyChainServiceProtocol? = nil,
        networkClient: NetworkClientProtocol? = nil
    ) {
        self.documentService = documentService ?? DocumentService()
        self.keyChainService = keyChainService ?? KeyChainService()
        self.networkClient = networkClient ?? NetworkClient()
        self.session = ProcessingSession()
        self.preferences = UserPreferences()
    }
}

enum NavigationTab: String, CaseIterable {
    case input, ocr, library, clean, settings

    var label: String {
        switch self {
        case .input: return "Input"
        case .ocr: return "OCR"
        case .library: return "Library"
        case .clean: return "Clean"
        case .settings: return "Settings"
        }
    }
}
```

**Dependencies:** Document, ProcessingSession, UserPreferences, (will add service protocols in Phase 2)

**Critical:** Use @Observable for state updates to propagate correctly through SwiftUI views.

---

#### 1.6.2: HorusApp.swift

**File:** `Horus/HorusApp.swift`

**Purpose:** @main entry point.

**Key Structure:**
```swift
@main
struct HorusApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
                .environment(appState.session)
                .environment(appState.preferences)
        }
        .commands {
            CommandGroup(replacing: .appMenu) {
                Button("About Horus") { /* show about */ }
            }
            CommandGroup(replacing: .newItem) {
                Button("Import Documents") { /* file picker */ }
                    .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}
```

**Dependencies:** AppState, MainWindowView (will create next)

---

#### 1.6.3: MainWindowView.swift

**File:** `Horus/Views/MainWindowView.swift`

**Purpose:** Root window with NavigationSplitView + HSplitView.

**Key Structure:**
```swift
struct MainWindowView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationSplitView {
            // Sidebar with 5 tabs
            NavigationSidebarView()
        } detail: {
            HSplitView {
                // Content area
                ContentAreaView()

                // Right inspector
                InspectorView()
            }
        }
        .frame(minWidth: 1200, minHeight: 700)
    }
}
```

**Dependencies:** AppState, NavigationSidebarView, ContentAreaView, InspectorView (will create in Phase 3)

---

### Step 1: Verification Checklist

- [ ] Xcode project builds without errors
- [ ] App launches and shows main window
- [ ] NavigationSplitView displays without errors
- [ ] Models compile and have proper Codable conformance
- [ ] AppState initializes with default services
- [ ] UserPreferences reads/writes to UserDefaults

**Output:** App launches with 5-tab navigation structure (empty content)

---

## Phase 2: Core Services (Days 4-6)

### Step 2.1: Keychain Service

#### 2.1.1: KeychainServiceProtocol.swift

**File:** `Horus/Services/KeychainServiceProtocol.swift`

**Purpose:** Protocol for secure credential storage.

**Key Protocol:**
```swift
protocol KeychainServiceProtocol {
    func storeAPIKey(_ key: String, forService service: String) throws
    func retrieveAPIKey(forService service: String) throws -> String?
    func deleteAPIKey(forService service: String) throws
    func hasAPIKey(forService service: String) -> Bool
}

enum KeychainService {
    static let mistralService = "com.horus.mistral"
    static let claudeService = "com.horus.claude"
}
```

**Dependencies:** None

---

#### 2.1.2: KeychainService.swift

**File:** `Horus/Services/KeychainService.swift`

**Purpose:** SecItem-based Keychain implementation.

**Key Implementation:**
```swift
final class KeychainService: KeychainServiceProtocol {
    func storeAPIKey(_ key: String, forService service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: key.data(using: .utf8) ?? Data()
        ]

        try SecItem.delete(with: query)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HorusError.keyChainError("Failed to store key: \(status)")
        }
    }

    func retrieveAPIKey(forService service: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

**Dependencies:** HorusError

---

### Step 2.2: Network Client

#### 2.2.1: NetworkClientProtocol.swift

**File:** `Horus/Services/NetworkClientProtocol.swift`

**Purpose:** HTTP client abstraction.

**Key Protocol:**
```swift
protocol NetworkClientProtocol {
    func get<T: Decodable>(url: URL, headers: [String: String]?) async throws -> T
    func post<T: Decodable>(
        url: URL,
        body: Encodable,
        headers: [String: String]?
    ) async throws -> T
}
```

**Dependencies:** None

---

#### 2.2.2: NetworkClient.swift

**File:** `Horus/Services/NetworkClient.swift`

**Purpose:** URLSession-based HTTP implementation.

**Key Implementation:**
```swift
final class NetworkClient: NetworkClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func post<T: Decodable>(
        url: URL,
        body: Encodable,
        headers: [String: String]?
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw HorusError.networkError("Invalid HTTP response")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
```

**Dependencies:** HorusError

---

### Step 2.3: API Key Validator

#### 2.3.1: APIKeyValidatorProtocol.swift

**File:** `Horus/Services/APIKeyValidatorProtocol.swift`

**Purpose:** Validate API keys with provider.

**Key Protocol:**
```swift
protocol APIKeyValidatorProtocol {
    func validateMistralKey(_ key: String) async throws -> Bool
    func validateClaudeKey(_ key: String) async throws -> Bool
}
```

**Dependencies:** None

---

#### 2.3.2: APIKeyValidator.swift

**File:** `Horus/Services/APIKeyValidator.swift`

**Purpose:** Mistral /v1/models validation endpoint.

**Key Implementation:**
```swift
final class APIKeyValidator: APIKeyValidatorProtocol {
    private let networkClient: NetworkClientProtocol

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    func validateMistralKey(_ key: String) async throws -> Bool {
        let url = URL(string: "https://api.mistral.ai/v1/models")!
        let headers = ["Authorization": "Bearer \(key)"]

        do {
            struct Response: Decodable {
                let object: String
            }
            let _: Response = try await networkClient.get(url: url, headers: headers)
            return true
        } catch {
            return false
        }
    }

    func validateClaudeKey(_ key: String) async throws -> Bool {
        // Similar pattern with Claude API endpoint
        return true
    }
}
```

**Dependencies:** NetworkClientProtocol

---

### Step 2.4: Cost Calculator

#### 2.4.1: CostCalculatorProtocol.swift

**File:** `Horus/Services/CostCalculatorProtocol.swift`

**Purpose:** Calculate processing costs.

**Key Protocol:**
```swift
protocol CostCalculatorProtocol {
    func calculateOCRCost(pageCount: Int) -> Decimal
    func calculateCleaningCost(tokens: Int) -> Decimal
    func formatCurrency(_ amount: Decimal) -> String
}
```

**Dependencies:** None

---

#### 2.4.2: CostCalculator.swift

**File:** `Horus/Services/CostCalculator.swift`

**Purpose:** Pricing calculations.

**Key Implementation:**
```swift
final class CostCalculator: CostCalculatorProtocol {
    private let ocrCostPerPage: Decimal = 0.001 // Mistral pricing
    private let cleaningCostPerThousandTokens: Decimal = 0.003 // Claude

    func calculateOCRCost(pageCount: Int) -> Decimal {
        Decimal(pageCount) * ocrCostPerPage
    }

    func calculateCleaningCost(tokens: Int) -> Decimal {
        (Decimal(tokens) / 1000) * cleaningCostPerThousandTokens
    }

    func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}
```

**Dependencies:** None

---

### Step 2.5: Document Service

#### 2.5.1: DocumentServiceProtocol.swift

**File:** `Horus/Services/DocumentServiceProtocol.swift`

**Purpose:** File loading and validation.

**Key Protocol:**
```swift
protocol DocumentServiceProtocol {
    func loadDocument(from url: URL) throws -> Document
    func getPageCount(for document: Document) throws -> Int
    func validateDocument(_ document: Document) throws -> [String]
}
```

**Dependencies:** Document, HorusError

---

#### 2.5.2: DocumentService.swift

**File:** `Horus/Services/DocumentService.swift`

**Purpose:** PDF loading and metadata extraction.

**Key Implementation:**
```swift
final class DocumentService: DocumentServiceProtocol {
    func loadDocument(from url: URL) throws -> Document {
        guard url.startAccessingSecurityScopedResource() else {
            throw HorusError.documentLoadError("Cannot access file")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int ?? 0

        let document = Document(
            id: UUID(),
            sourceURL: url,
            contentType: url.contentType ?? .pdf,
            fileSize: fileSize,
            status: .pending,
            pageCount: try getPageCount(for: Document(...)),
            metadata: nil,
            ocrResult: nil,
            cleanedContent: nil,
            validationErrors: [],
            pathways: []
        )

        return document
    }

    func getPageCount(for document: Document) throws -> Int {
        guard document.contentType == .pdf else { return 1 }

        guard let pdf = PDFDocument(url: document.sourceURL) else {
            throw HorusError.documentLoadError("Invalid PDF")
        }

        return pdf.pageCount
    }

    func validateDocument(_ document: Document) throws -> [String] {
        var errors: [String] = []

        if document.fileSize > 100 * 1024 * 1024 {
            errors.append("File exceeds 100MB limit")
        }

        if document.pageCount > 1000 {
            errors.append("PDF exceeds 1000 pages")
        }

        return errors
    }
}
```

**Dependencies:** Document, HorusError

---

### Step 2.6: Settings Views

#### 2.6.1: SettingsView.swift

**File:** `Horus/Views/Settings/SettingsView.swift`

**Purpose:** Root settings container.

**Key Structure:**
```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            SettingsTabView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            CleaningSettingsView()
                .tabItem {
                    Label("Cleaning", systemImage: "sparkles")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}
```

**Dependencies:** (stub implementations)

---

#### 2.6.2: SettingsTabView.swift

**File:** `Horus/Views/Settings/SettingsTabView.swift`

**Purpose:** General settings (API keys, cost warnings).

**Key Structure:**
```swift
struct SettingsTabView: View {
    @Environment(AppState.self) var appState
    @State private var mistralKey = ""
    @State private var claudeKey = ""

    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("Mistral API Key", text: $mistralKey)
                SecureField("Claude API Key", text: $claudeKey)
                Button("Save Keys") {
                    try? appState.keyChainService.storeAPIKey(mistralKey, forService: .mistralService)
                    try? appState.keyChainService.storeAPIKey(claudeKey, forService: .claudeService)
                }
            }
        }
    }
}
```

**Dependencies:** AppState

---

### Step 2: Verification Checklist

- [ ] KeychainService stores/retrieves API keys without errors
- [ ] NetworkClient successfully makes HTTP requests (mock test)
- [ ] APIKeyValidator validates against test keys
- [ ] CostCalculator produces expected currency formatting
- [ ] DocumentService loads PDF and counts pages correctly
- [ ] Settings views compile and display

**Output:** All services tested and integrated with app shell

---

## Phase 3: Document Management & Input (Days 7-9)

### Step 3.1: Navigation & Sidebar

#### 3.1.1: NavigationSidebarView.swift

**File:** `Horus/Views/Navigation/NavigationSidebarView.swift`

**Purpose:** 5-tab main navigation sidebar.

**Key Structure:**
```swift
struct NavigationSidebarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        List(NavigationTab.allCases, id: \.self, selection: $appState.navigationTab) { tab in
            NavigationLink(value: tab) {
                Label(tab.label, systemImage: tab.icon)
            }
        }
        .listStyle(.sidebar)
    }
}

extension NavigationTab {
    var icon: String {
        switch self {
        case .input: return "arrow.down.doc"
        case .ocr: return "text.viewfinder"
        case .library: return "books.vertical"
        case .clean: return "sparkles"
        case .settings: return "gear"
        }
    }
}
```

**Dependencies:** AppState, NavigationTab

---

#### 3.1.2: SidebarView.swift

**File:** `Horus/Views/Navigation/SidebarView.swift`

**Purpose:** Document list with filtering and status badges.

**Key Structure:**
```swift
struct SidebarView: View {
    @Environment(AppState.self) var appState
    @State private var searchText = ""

    var filteredDocuments: [Document] {
        appState.session.documents.filter { doc in
            searchText.isEmpty || doc.sourceURL.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack {
            SearchField("Search documents", text: $searchText)

            List(filteredDocuments, id: \.id, selection: $appState.selectedDocumentID) { doc in
                DocumentListRow(document: doc)
                    .tag(doc.id)
            }
        }
    }
}
```

**Dependencies:** AppState, Document, DocumentListRow

---

### Step 3.2: Document Queue

#### 3.2.1: DocumentQueueViewModel.swift

**File:** `Horus/ViewModels/DocumentQueueViewModel.swift`

**Purpose:** Import and batch loading logic.

**Key Types:**
```swift
@Observable
final class DocumentQueueViewModel {
    var documents: [Document] = []
    var isImporting = false
    var importError: HorusError?

    func importDocuments(from urls: [URL], appState: AppState) async {
        isImporting = true
        defer { isImporting = false }

        for url in urls {
            do {
                let doc = try appState.documentService.loadDocument(from: url)
                let errors = try appState.documentService.validateDocument(doc)
                doc.validationErrors = errors

                try appState.session.addDocument(doc)
                documents.append(doc)
            } catch let error as HorusError {
                importError = error
            } catch {
                importError = HorusError.documentLoadError(error.localizedDescription)
            }
        }
    }
}
```

**Dependencies:** Document, AppState, HorusError

---

#### 3.2.2: InputView.swift

**File:** `Horus/Views/InputView.swift`

**Purpose:** Drag-and-drop document import.

**Key Structure:**
```swift
struct InputView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel = DocumentQueueViewModel()

    var body: some View {
        VStack {
            TabHeaderView(title: "Import Documents", icon: "arrow.down.doc")

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(.gray)

                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 48))
                    Text("Drag PDFs here or click to browse")
                    Button("Select Files") {
                        // File picker
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    _ = provider.loadFileRepresentation(forTypeIdentifier: "com.adobe.pdf") { url, _ in
                        if let url = url {
                            Task {
                                await viewModel.importDocuments(from: [url], appState: appState)
                            }
                        }
                    }
                }
                return true
            }

            Spacer()
            TabFooterView()
        }
        .padding()
    }
}
```

**Dependencies:** AppState, DocumentQueueViewModel, TabHeaderView, TabFooterView

---

#### 3.2.3: QuickProcessingOptionsView.swift

**File:** `Horus/Views/QuickProcessingOptionsView.swift`

**Purpose:** Quick action buttons (Process All, Export, etc).

**Key Structure:**
```swift
struct QuickProcessingOptionsView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { /* process all */ }) {
                Label("Process All", systemImage: "play.fill")
            }

            Button(action: { /* export selection */ }) {
                Label("Export", systemImage: "arrow.up.doc")
            }

            Button(action: { /* clear completed */ }) {
                Label("Clear Completed", systemImage: "trash")
            }
        }
        .buttonStyle(.bordered)
    }
}
```

**Dependencies:** AppState

---

### Step 3.3: Shared Components

#### 3.3.1: TabHeaderView.swift & TabFooterView.swift

**File:** `Horus/Views/Components/TabHeaderView.swift`

**Purpose:** Consistent tab title and icon.

**Key Structure:**
```swift
struct TabHeaderView: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .font(.title2.weight(.semibold))
            Spacer()
        }
        .padding(.bottom, DesignConstants.spacing16)
    }
}
```

**Dependencies:** DesignConstants

---

#### 3.3.2: DocumentListRow.swift

**File:** `Horus/Views/Components/DocumentListRow.swift`

**Purpose:** List row with status badges and pipeline info.

**Key Structure:**
```swift
struct DocumentListRow: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.sourceURL.lastPathComponent)
                        .font(.body.weight(.medium))

                    HStack(spacing: 8) {
                        Text("\(document.pageCount) pages")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        PipelineStatusIcons(document: document)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: document.status)

                    if let cost = document.ocrResult?.estimatedCost {
                        Text("$\(cost)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

**Dependencies:** Document, PipelineStatusIcons

---

#### 3.3.3: InspectorComponents.swift

**File:** `Horus/Views/Components/InspectorComponents.swift`

**Purpose:** Reusable inspector patterns.

**Key Types:**
```swift
struct InspectorCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(DesignConstants.spacing12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(DesignConstants.mediumRadius)
    }
}

struct InspectorRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct InspectorSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, DesignConstants.spacing12)
    }
}
```

**Dependencies:** DesignConstants

---

#### 3.3.4: PipelineStatusIcons.swift

**File:** `Horus/Views/Components/PipelineStatusIcons.swift`

**Purpose:** Visual indicators for OCR/Clean pipeline status.

**Key Structure:**
```swift
struct PipelineStatusIcons: View {
    let document: Document

    var body: some View {
        HStack(spacing: 4) {
            if document.pathways.contains(where: { $0.includeOCR }) {
                Image(systemName: document.ocrResult != nil ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(document.ocrResult != nil ? .green : .gray)
                    .font(.caption2)
            }

            if document.pathways.contains(where: { $0.includeCleaning }) {
                Image(systemName: document.cleanedContent != nil ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(document.cleanedContent != nil ? .green : .gray)
                    .font(.caption2)
            }
        }
    }
}
```

**Dependencies:** Document

---

### Step 3.4: Inspector & Content Area

#### 3.4.1: InspectorView.swift

**File:** `Horus/Views/InspectorView.swift`

**Purpose:** Context-aware right panel with document metadata.

**Key Structure:**
```swift
struct InspectorView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        if let document = appState.selectedDocument {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignConstants.spacing16) {
                    InspectorSectionHeader(title: "Document Info")
                    InspectorCard {
                        InspectorRow(label: "File", value: document.sourceURL.lastPathComponent)
                        InspectorRow(label: "Pages", value: "\(document.pageCount)")
                        InspectorRow(label: "Size", value: formatFileSize(document.fileSize))
                        InspectorRow(label: "Status", value: document.status.rawValue)
                    }

                    if let result = document.ocrResult {
                        InspectorSectionHeader(title: "OCR Results")
                        InspectorCard {
                            InspectorRow(label: "Characters", value: "\(result.characterCount)")
                            InspectorRow(label: "Cost", value: "$\(result.estimatedCost)")
                        }
                    }

                    Spacer()
                }
                .padding(DesignConstants.spacing16)
            }
        } else {
            EmptyStateView(
                icon: "info.circle",
                title: "No Selection",
                message: "Select a document to view details"
            )
        }
    }
}
```

**Dependencies:** AppState, Document, InspectorComponents, EmptyStateView

---

#### 3.4.2: ContentAreaView.swift

**File:** `Horus/Views/ContentAreaView.swift`

**Purpose:** Dynamic content routing based on active tab.

**Key Structure:**
```swift
struct ContentAreaView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        switch appState.navigationTab {
        case .input:
            InputView()
        case .ocr:
            OCRTabView()
        case .library:
            LibraryView()
        case .clean:
            CleanTabView()
        case .settings:
            SettingsView()
        }
    }
}
```

**Dependencies:** AppState, views for each tab

---

#### 3.4.3: EmptyStateView.swift

**File:** `Horus/Views/EmptyStateView.swift`

**Purpose:** Consistent empty state UI.

**Key Structure:**
```swift
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)?
    var actionLabel: String?

    var body: some View {
        VStack(spacing: DesignConstants.spacing16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}
```

**Dependencies:** DesignConstants

---

### Step 3: Verification Checklist

- [ ] Input View accepts drag-and-drop PDFs
- [ ] Documents appear in sidebar after import
- [ ] Document list filters by search text
- [ ] Clicking document updates inspector details
- [ ] TabHeaderView and TabFooterView display correctly
- [ ] PipelineStatusIcons show OCR/Clean status

**Output:** Document import and basic UI navigation working

---

## Phase 3.5: Core View Models (Days 7-9, continuation)

### Step 3.5.1: CleaningViewModel.swift

**File:** `Horus/Features/Cleaning/ViewModels/CleaningViewModel.swift`

**Purpose:** Manage cleaning pipeline state and orchestration.

**Key Types:**
```swift
enum CleaningState {
    case idle
    case processing
    case completed
    case failed
    case cancelled
}

@Observable
final class CleaningViewModel {
    var selectedDocument: Document?
    var state: CleaningState = .idle
    var progress: Double = 0
    var currentPhase: String = ""
    var totalCost: Decimal = 0
    var confidenceScore: Int = 0

    func startCleaning(_ document: Document) async throws
    func pauseCleaning()
    func resumeCleaning() async throws
    func cancelCleaning()
}
```

**Dependencies:** Document, CleaningService, ProcessingViewModel

---

## Phase 4: OCR Processing (Days 10-13)

### Step 4.1: OCR API Models

#### 4.1.1: OCRAPIModels.swift

**File:** `Horus/Models/OCRAPIModels.swift`

**Purpose:** Request/response models for Mistral OCR API.

**Key Types:**
```swift
struct DocumentPayload: Codable {
    let document_id: String
    let document_type: String
    let pages: [DocumentPage]
    let processing_settings: ProcessingSettings
}

struct DocumentPage: Codable {
    let page_number: Int
    let page_data: String // Base64 encoded image
}

struct ProcessingSettings: Codable {
    let language: String = "en"
    let output_format: String = "detailed"
    let extract_tables: Bool = true
    let extract_images: Bool = false
}

// Presets for quick configuration
enum OCRPreset: String {
    case standard, detailed, fast, economical

    var settings: ProcessingSettings { /* ... */ }
}

struct OCRResponse: Codable {
    let document_id: String
    let status: String
    let results: OCRResultData
}

struct OCRResultData: Codable {
    let pages: [OCRPageData]
    let metadata: OCRMetadata
}
```

**Dependencies:** Codable (stdlib)

---

### Step 4.2: OCR Service

#### 4.2.1: OCRServiceProtocol.swift

**File:** `Horus/Services/OCRServiceProtocol.swift`

**Purpose:** Protocol for OCR processing.

**Key Protocol:**
```swift
protocol OCRServiceProtocol {
    func processDocuments(
        _ documents: [Document],
        preset: OCRPreset
    ) async throws -> [String: OCRResult]
}
```

**Dependencies:** Document, OCRResult

---

#### 4.2.2: OCRService.swift

**File:** `Horus/Services/OCRService.swift`

**Purpose:** 4-phase OCR processing (prepare, upload, process, finalize).

**Key Implementation:**
```swift
final class OCRService: OCRServiceProtocol {
    private let networkClient: NetworkClientProtocol
    private let keyChainService: KeychainServiceProtocol

    func processDocuments(
        _ documents: [Document],
        preset: OCRPreset
    ) async throws -> [String: OCRResult] {
        var results: [String: OCRResult] = [:]

        for document in documents {
            do {
                // Phase 1: Prepare
                let payload = try preparePayload(for: document, preset: preset)

                // Phase 2: Upload
                let uploadResponse = try await uploadDocument(payload)

                // Phase 3: Process
                let processingResponse = try await pollProcessing(uploadResponse.id)

                // Phase 4: Finalize
                let ocrResult = try finalizeResult(processingResponse, for: document)
                results[document.id.uuidString] = ocrResult

            } catch let error {
                // Retry logic
                print("OCR failed for \(document.sourceURL.lastPathComponent): \(error)")
            }
        }

        return results
    }

    private func preparePayload(for document: Document, preset: OCRPreset) throws -> DocumentPayload {
        let pdfData = try Data(contentsOf: document.sourceURL)
        let pages = try extractPages(from: pdfData, limit: document.pageCount)

        return DocumentPayload(
            document_id: document.id.uuidString,
            document_type: "pdf",
            pages: pages,
            processing_settings: preset.settings
        )
    }

    private func uploadDocument(_ payload: DocumentPayload) async throws -> UploadResponse {
        let mistralKey = try keyChainService.retrieveAPIKey(forService: "com.horus.mistral")
        guard let key = mistralKey else {
            throw HorusError.ocrProcessingError("Mistral API key not configured")
        }

        let url = URL(string: "https://api.mistral.ai/v1/ocr/documents")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(UploadResponse.self, from: data)
    }

    private func pollProcessing(_ id: String, maxAttempts: Int = 30) async throws -> ProcessingResponse {
        for attempt in 0..<maxAttempts {
            let url = URL(string: "https://api.mistral.ai/v1/ocr/documents/\(id)/status")!

            let response: StatusResponse = try await networkClient.get(url: url, headers: [:])

            if response.status == "completed" {
                return response.result
            }

            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
        }

        throw HorusError.ocrProcessingError("Processing timeout")
    }

    private func finalizeResult(_ response: ProcessingResponse, for document: Document) throws -> OCRResult {
        let characterCount = response.pages.reduce(0) { $0 + $1.text.count }
        let cost = Decimal(document.pageCount) * Decimal("0.001")

        return OCRResult(
            id: document.id,
            pages: response.pages.map { page in
                OCRPage(
                    pageNumber: page.page_number,
                    text: page.text,
                    confidence: page.confidence,
                    dimensions: OCRDimensions(
                        width: page.width,
                        height: page.height,
                        dpi: page.dpi
                    )
                )
            },
            tables: response.tables.map { /* ... */ } ?? [],
            images: response.images.map { /* ... */ } ?? [],
            processingTime: response.processing_time,
            characterCount: characterCount,
            estimatedCost: cost
        )
    }
}
```

**Dependencies:** NetworkClientProtocol, KeychainServiceProtocol, Document, OCRResult, HorusError

---

### Step 4.3: Processing ViewModel

#### 4.3.1: ProcessingViewModel.swift

**File:** `Horus/ViewModels/ProcessingViewModel.swift`

**Purpose:** OCR orchestration and progress tracking.

**Key Types:**
```swift
@Observable
final class ProcessingViewModel {
    var isProcessing = false
    var progress: Double = 0
    var currentDocument: Document?
    var totalCost: Decimal = 0
    var ocrService: OCRServiceProtocol

    func processSelectedDocuments(_ appState: AppState) async {
        isProcessing = true
        defer { isProcessing = false }

        let toProcess = appState.session.documents.filter { $0.status == .pending }
        let totalCount = toProcess.count

        for (index, document) in toProcess.enumerated() {
            currentDocument = document
            progress = Double(index) / Double(totalCount)

            do {
                document.status = .processing

                let results = try await ocrService.processDocuments(
                    [document],
                    preset: .standard
                )

                if let result = results[document.id.uuidString] {
                    document.ocrResult = result
                    totalCost += result.estimatedCost
                    document.status = .completed
                }
            } catch {
                document.status = .failed
                document.validationErrors.append(error.localizedDescription)
            }
        }
    }
}
```

**Dependencies:** Document, AppState, OCRServiceProtocol

---

### Step 4.4: OCR Tab View

#### 4.4.1: OCRTabView.swift

**File:** `Horus/Views/OCRTabView.swift`

**Purpose:** OCR processing interface with document table and preview.

**Key Structure:**
```swift
struct OCRTabView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel = ProcessingViewModel()
    @State private var selectedResultID: UUID?

    var body: some View {
        VStack {
            TabHeaderView(title: "OCR Processing", icon: "text.viewfinder")

            if appState.session.documents.isEmpty {
                EmptyStateView(
                    icon: "doc.badge.arrow.up",
                    title: "No Documents",
                    message: "Import documents from the Input tab to begin processing"
                )
            } else {
                HSplitView {
                    // Document table
                    Table(appState.session.documents) {
                        TableColumn("File", value: \.sourceURL.lastPathComponent)
                        TableColumn("Pages", value: \.pageCount) { doc in
                            Text("\(doc.pageCount)")
                        }
                        TableColumn("Status") { doc in
                            StatusBadge(status: doc.status)
                        }
                        TableColumn("Cost") { doc in
                            if let cost = doc.ocrResult?.estimatedCost {
                                Text("$\(cost)")
                            }
                        }
                    }
                    .onChange(of: selectedResultID) { _, newID in
                        appState.selectedDocumentID = newID
                    }

                    // Preview area
                    if let document = appState.selectedDocument {
                        VStack {
                            if let result = document.ocrResult {
                                ScrollView {
                                    VStack(alignment: .leading) {
                                        ForEach(result.pages, id: \.pageNumber) { page in
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Page \(page.pageNumber)")
                                                    .font(.headline)
                                                Text(page.text)
                                                    .font(.body)
                                                    .lineLimit(10)
                                                Divider()
                                            }
                                            .padding(.vertical, 8)
                                        }
                                    }
                                    .padding()
                                }
                            } else {
                                EmptyStateView(
                                    icon: "doc.text",
                                    title: "No Results",
                                    message: "Process this document to view OCR results"
                                )
                            }
                        }
                    }
                }
            }

            HStack {
                Button(action: {
                    Task {
                        await viewModel.processSelectedDocuments(appState)
                    }
                }) {
                    Label("Process Selected", systemImage: "play.fill")
                }
                .disabled(appState.selectedDocument?.status != .pending)

                Spacer()

                if viewModel.isProcessing {
                    ProgressView(value: viewModel.progress)
                        .frame(maxWidth: 200)
                }
            }
            .padding()
        }
    }
}
```

**Dependencies:** AppState, Document, ProcessingViewModel, StatusBadge, EmptyStateView

---

### Step 4.5: Thumbnail System

#### 4.5.1: ThumbnailCache.swift

**File:** `Horus/Services/ThumbnailCache.swift`

**Purpose:** LRU cache with quality tiering.

**Key Types:**
```swift
final class ThumbnailCache {
    private var cache: [String: NSImage] = [:]
    private let maxSize = 50
    private var accessOrder: [String] = []

    func thumbnail(for documentID: String, size: CGSize) -> NSImage? {
        let key = "\(documentID)_\(Int(size.width))x\(Int(size.height))"

        if let image = cache[key] {
            // Update LRU order
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return image
        }

        return nil
    }

    func cacheThumbnail(_ image: NSImage, for documentID: String, size: CGSize) {
        let key = "\(documentID)_\(Int(size.width))x\(Int(size.height))"

        if cache.count >= maxSize {
            if let oldest = accessOrder.first {
                cache.removeValue(forKey: oldest)
                accessOrder.removeFirst()
            }
        }

        cache[key] = image
        accessOrder.append(key)
    }
}
```

**Dependencies:** None

---

#### 4.5.2: PDFThumbnailView.swift

**File:** `Horus/Views/Components/PDFThumbnailView.swift`

**Purpose:** Generate thumbnail from PDF page.

**Key Structure:**
```swift
struct PDFThumbnailView: View {
    let document: Document
    let pageNumber: Int
    let size: CGSize

    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.2))
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            generateThumbnail()
        }
    }

    private func generateThumbnail() {
        guard let pdf = PDFDocument(url: document.sourceURL),
              let page = pdf.page(at: pageNumber - 1) else { return }

        let bounds = page.bounds(for: .mediaBox)
        let scale = size.width / bounds.width

        let image = NSImage(size: CGSize(width: size.width, height: bounds.height * scale))
        image.lockFocus()
        NSColor.white.setFill()
        bounds.fill()
        page.draw(with: .mediaBox, to: NSGraphicsContext.current!)
        image.unlockFocus()

        self.thumbnail = image
    }
}
```

**Dependencies:** Document

---

### Step 4.6: Session Stats

#### 4.6.1: SessionStatsView.swift

**File:** `Horus/Views/SessionStatsView.swift`

**Purpose:** Display session-level metrics.

**Key Structure:**
```swift
struct SessionStatsView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        InspectorCard {
            Grid {
                GridRow {
                    Text("Total Documents")
                    Spacer()
                    Text("\(appState.session.documents.count)")
                }

                GridRow {
                    Text("Completed")
                    Spacer()
                    Text("\(appState.session.completedDocuments.count)")
                }

                GridRow {
                    Text("Failed")
                    Spacer()
                    Text("\(appState.session.failedDocuments.count)")
                }

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                GridRow {
                    Text("Total Cost")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(appState.session.totalCost)")
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
```

**Dependencies:** AppState, InspectorComponents

---

### Step 4.7: PageThumbnailsView

**File:** `Horus/Features/MainWindow/Views/PageThumbnailsView.swift`

**Purpose:** Virtualized page thumbnail display with scroll velocity detection.

**Key Types:**
```swift
struct PageThumbnailsView: View {
    let document: Document
    @State private var scrollPosition: Int = 0
    @State private var scrollVelocity: ScrollVelocity = .stationary

    // Scroll velocity detection: stationary, normal, fast
    // Adaptive prefetch buffer based on velocity
    // Large document warning (>100 pages)
}

struct PageThumbnailsStripView: View {
    // Horizontal compact variant (50×65 thumbnails)
    // Used in OCR tab for quick page navigation
}

enum ScrollVelocity {
    case stationary, normal, fast
}
```

**Implementation Details:**
- Implements lazy loading with scroll velocity detection
- Prefetch buffer adapts based on scroll speed (2-10 pages ahead)
- Shows warning for large documents (>100 pages)
- 444 lines total, handles pagination efficiently

**Dependencies:** Document, PDFThumbnailView, ThumbnailCache

---

### Step 4.8: SessionStatsView

**File:** `Horus/Features/MainWindow/Views/SessionStatsView.swift`

**Purpose:** Display session-level metrics in inspector.

**Key Types:**
```swift
struct SessionStatsView: View {
    @Environment(AppState.self) var appState

    // Displays:
    // - Total Documents
    // - Completed count with OCR/Clean badges
    // - Failed count
    // - Total Spending

    // Updates reactively as session state changes
}
```

**Dependencies:** AppState, InspectorComponents

---

### Step 4: Verification Checklist

- [ ] OCRService successfully uploads documents to Mistral API (or mock)
- [ ] Processing polling works with status checks
- [ ] OCRTabView displays document table with results
- [ ] Thumbnails generate for PDF pages with scroll velocity detection
- [ ] Cost accumulation works correctly with Decimal precision
- [ ] Progress bar updates during processing
- [ ] SessionStatsView displays accurate metrics
- [ ] Page navigation works smoothly with LazyVStack

**Output:** Full OCR pipeline working end-to-end with thumbnail system

---

## Phase 5: Library & Export (Days 14-16)

### Step 5.1: Export Service

#### 5.1.1: ExportServiceProtocol.swift

**File:** `Horus/Services/ExportServiceProtocol.swift`

**Purpose:** Abstract export operations.

**Key Protocol:**
```swift
protocol ExportServiceProtocol {
    func exportToMarkdown(_ document: Document) throws -> String
    func exportToJSON(_ document: Document) throws -> String
    func exportToPlainText(_ document: Document) throws -> String
    func saveToFile(_ content: String, format: ExportFormat, fileName: String) throws -> URL
}
```

**Dependencies:** Document, ExportFormat

---

#### 5.1.2: ExportService.swift

**File:** `Horus/Services/ExportService.swift`

**Purpose:** File generation for all formats.

**Key Implementation:**
```swift
final class ExportService: ExportServiceProtocol {
    func exportToMarkdown(_ document: Document) throws -> String {
        guard let ocrResult = document.ocrResult else {
            throw HorusError.exportError("No OCR results to export")
        }

        var markdown = "# \(document.sourceURL.deletingPathExtension().lastPathComponent)\n\n"

        for page in ocrResult.pages {
            markdown += "## Page \(page.pageNumber)\n\n"
            markdown += page.text + "\n\n"
        }

        return markdown
    }

    func exportToJSON(_ document: Document) throws -> String {
        guard let ocrResult = document.ocrResult else {
            throw HorusError.exportError("No OCR results to export")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(ocrResult)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func exportToPlainText(_ document: Document) throws -> String {
        guard let ocrResult = document.ocrResult else {
            throw HorusError.exportError("No OCR results to export")
        }

        return ocrResult.pages.map { $0.text }.joined(separator: "\n\n---\n\n")
    }

    func saveToFile(_ content: String, format: ExportFormat, fileName: String) throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let fileURL = documentsURL.appendingPathComponent("\(fileName).\(format.fileExtension)")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }
}
```

**Dependencies:** Document, ExportFormat, HorusError

---

### Step 5.2: Export ViewModel

#### 5.2.1: ExportViewModel.swift

**File:** `Horus/ViewModels/ExportViewModel.swift`

**Purpose:** Single/batch export orchestration.

**Key Types:**
```swift
@Observable
final class ExportViewModel {
    var selectedFormat: ExportFormat = .markdown
    var exportProgress: Double = 0
    var isExporting = false
    var exportService: ExportServiceProtocol

    func exportDocument(_ document: Document) async throws {
        isExporting = true
        defer { isExporting = false }

        let content = switch selectedFormat {
        case .markdown:
            try exportService.exportToMarkdown(document)
        case .json:
            try exportService.exportToJSON(document)
        case .plainText:
            try exportService.exportToPlainText(document)
        }

        _ = try exportService.saveToFile(
            content,
            format: selectedFormat,
            fileName: document.sourceURL.deletingPathExtension().lastPathComponent
        )
    }

    func exportBatch(_ documents: [Document]) async throws {
        isExporting = true
        defer { isExporting = false }

        for (index, document) in documents.enumerated() {
            try await exportDocument(document)
            exportProgress = Double(index + 1) / Double(documents.count)
        }
    }
}
```

**Dependencies:** Document, ExportFormat, ExportServiceProtocol

---

### Step 5.3: Export Views

#### 5.3.1: ExportSheetView.swift

**File:** `Horus/Views/ExportSheetView.swift`

**Purpose:** Single document export dialog.

**Key Structure:**
```swift
struct ExportSheetView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel = ExportViewModel()
    @Environment(\.dismiss) var dismiss

    let document: Document

    var body: some View {
        VStack(spacing: DesignConstants.spacing16) {
            Text("Export Document")
                .font(.headline)

            Picker("Format", selection: $viewModel.selectedFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Export") {
                    Task {
                        try await viewModel.exportDocument(document)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
```

**Dependencies:** AppState, Document, ExportViewModel, DesignConstants

---

#### 5.3.2: BatchExportSheetView.swift

**File:** `Horus/Views/BatchExportSheetView.swift`

**Purpose:** Multi-document export with progress.

**Key Structure:**
```swift
struct BatchExportSheetView: View {
    @Environment(AppState.self) var appState
    @State private var viewModel = ExportViewModel()
    @Environment(\.dismiss) var dismiss

    let documents: [Document]

    var body: some View {
        VStack(spacing: DesignConstants.spacing16) {
            Text("Export \(documents.count) Documents")
                .font(.headline)

            Picker("Format", selection: $viewModel.selectedFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isExporting)

            if viewModel.isExporting {
                ProgressView(value: viewModel.exportProgress)
                Text("\(Int(viewModel.exportProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Export All") {
                    Task {
                        try await viewModel.exportBatch(documents)
                        dismiss()
                    }
                }
                .disabled(viewModel.isExporting)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
```

**Dependencies:** AppState, Document, ExportViewModel, DesignConstants

---

### Step 5.4: Library View

#### 5.4.1: LibraryView.swift

**File:** `Horus/Views/LibraryView.swift`

**Purpose:** Processed documents browser with preview.

**Key Structure:**
```swift
struct LibraryView: View {
    @Environment(AppState.self) var appState
    @State private var selectedDocument: Document?

    var completedDocuments: [Document] {
        appState.session.completedDocuments
    }

    var body: some View {
        VStack {
            TabHeaderView(title: "Library", icon: "books.vertical")

            if completedDocuments.isEmpty {
                EmptyStateView(
                    icon: "books.vertical",
                    title: "No Completed Documents",
                    message: "Process documents in the OCR tab to add them to your library"
                )
            } else {
                HSplitView {
                    // List
                    Table(completedDocuments, selection: $selectedDocument) {
                        TableColumn("File", value: \.sourceURL.lastPathComponent)
                        TableColumn("Pages") { doc in
                            Text("\(doc.pageCount)")
                        }
                        TableColumn("Processed") { doc in
                            Image(systemName: doc.ocrResult != nil ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(doc.ocrResult != nil ? .green : .gray)
                        }
                    }

                    // Preview
                    if let document = selectedDocument {
                        PagedPreviewView(document: document)
                    }
                }
            }

            HStack {
                if let document = selectedDocument {
                    Button(action: {
                        // Export action
                    }) {
                        Label("Export", systemImage: "arrow.up.doc")
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
}
```

**Dependencies:** AppState, Document, PagedPreviewView

---

#### 5.4.2: PagedPreviewComponents.swift

**File:** `Horus/Views/Components/PagedPreviewComponents.swift`

**Purpose:** Multi-page document preview.

**Key Types:**
```swift
struct PagedPreviewView: View {
    let document: Document
    @State private var currentPageIndex = 0

    var pages: [OCRPage] {
        document.ocrResult?.pages ?? []
    }

    var body: some View {
        VStack {
            if pages.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Content",
                    message: "This document has no OCR results"
                )
            } else {
                VirtualizedTextView(text: pages[currentPageIndex].text)

                HStack {
                    Button(action: {
                        currentPageIndex = max(0, currentPageIndex - 1)
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentPageIndex == 0)

                    Text("Page \(currentPageIndex + 1) of \(pages.count)")
                        .font(.caption)

                    Button(action: {
                        currentPageIndex = min(pages.count - 1, currentPageIndex + 1)
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentPageIndex == pages.count - 1)

                    Spacer()
                }
                .padding()
            }
        }
    }
}
```

**Dependencies:** Document, OCRResult

---

### Step 5: Verification Checklist

- [ ] ExportService generates valid Markdown/JSON/PlainText
- [ ] Export files save to Documents folder
- [ ] Batch export works with progress tracking
- [ ] Library shows only completed documents
- [ ] Page navigation works in preview
- [ ] Export buttons integrate with views

**Output:** Complete export and library workflows

---

## Phase 6: Cleaning Pipeline — Foundation (Days 17-21)

*This phase is extensive. Below is the core structure; full implementation would follow similar patterns to previous phases.*

### Step 6.1: Cleaning Models (Build Order Critical — 17 models, 880+ lines total)

The following models build upon each other. Create in this exact order to avoid circular imports:

1. **CleaningStep.swift** — 16-step enum with phases (Normalization, Enhancement, Validation)
2. **PipelinePhase.swift** — Phase organization enum
3. **ContentType.swift** — 11 content types (academic, news, technical, business, fiction, legal, marketing, medical, email, code, generic)
4. **ContentTypeFlags.swift** — Feature detection flags for content characterization
5. **PresetType.swift** — 4 presets (conservative, balanced, aggressive, custom)
6. **CleaningConfiguration.swift** — Settings object for pipeline execution
7. **CleaningProgress.swift** — Real-time tracking with phase awareness
8. **DetectedPatterns.swift** — Cached document patterns from Claude analysis
9. **DocumentMetadata.swift** — Bibliographic data (title, author, publisher, ISBN, etc.) with export
10. **CleanedContent.swift** — Pipeline output with statistics (word count, reduction %, tokens)
11. **AuxiliaryListTypes.swift** — 13 list types (LOF, LOT, Illustrations, Bibliography, Index, etc.)
12. **CitationTypes.swift** — 13 citation styles (APA, MLA, Chicago, IEEE, etc.)
13. **FootnoteTypes.swift** — 8 marker styles (superscript, bracketed, symbols, letters)
14. **ChapterMarkerStyle.swift** — 5 chapter markers (Chapter N, Part N, Section N, etc.)
15. **EndMarkerStyle.swift** — 8 end markers (Appendix, References, Colophon, etc.)
16. **StructureHints.swift** — Reconnaissance output from initial document analysis
17. **AccumulatedContext.swift** — Multi-phase state accumulation across pipeline stages

### Step 6.2: Claude API Models & Service

**ClaudeAPIModels.swift** (~400 lines)
- All API request/response models as documented in 07-API-Integration-Guide
- Includes ClaudeAPIConfig constants, ClaudeAPIRequest, ClaudeMessage, MessageRole
- ClaudeAPIResponse, ClaudeContentBlock, ClaudeUsage, AnyCodable, ClaudeAPIRequestInfo

**ClaudeService.swift** (~2000 lines)
- Implements ClaudeServiceProtocol with all 13 operations
- Handles all Claude API interactions with retry logic, error handling
- Manages request tracking via ClaudeAPIRequestInfo
- Maintains recentRequests array (max 50) for debugging
- Response parsing handles markdown fences and trailing commas

### Step 6.3: Core Cleaning Infrastructure

**TextProcessingService.swift** (~2000 lines)
- Handles 9 character-level cleaning steps
- Normalizes encoding, removes control characters, fixes whitespace
- Smart punctuation handling, URL preservation
- Implements text validation and corruption detection

**PatternDetectionService.swift** (~1500 lines)
- Analyzes document for: citations, footnotes, chapters, boundaries
- Caches Claude patterns for 1-hour window to reduce API calls
- Returns DetectedPatterns struct with all metadata
- Supports content type detection and confidence scoring

### Step 6.4-6.6: Multi-Layer Defense System

The three-layer defense system prevents catastrophic content removal (880 + 1289 + 1825 = 3994 lines):

- **BoundaryValidation.swift** (880 lines)
  - Phase A: Validates proposed boundary removals
  - Section-specific constraints (front matter, main, back matter)
  - Prevents removal of critical content markers
  - Fallback to conservative phase if >30% removal detected

- **ContentVerification.swift** (1289 lines)
  - Phase B: Verifies content integrity post-cleaning
  - Multi-language pattern recognition
  - Detects corrupted or incomplete sections
  - Validates sentence structure, citation consistency

- **HeuristicBoundaryDetection.swift** (1825 lines)
  - Phase C: Heuristic patterns for accurate boundary detection
  - Weighted scoring for boundary confidence
  - Handles edge cases and malformed content
  - Adaptive thresholds based on document type

**CleaningService.swift** (3429 lines)
- Orchestrates the complete 16-step pipeline
- Manages all three defense layers
- Coordinates Claude operations, text processing, verification
- Tracks progress, cost, confidence per step
- Implements retry logic and error recovery

### Step 6: Verification Checklist

- [ ] All cleaning models compile without circular imports
- [ ] ClaudeService connects to Claude API
- [ ] Multi-layer defense prevents removal of critical content
- [ ] TextProcessingService handles 9 character cleaning steps
- [ ] PatternDetectionService caches Claude patterns for 1 hour
- [ ] CleaningService completes all 16 steps without errors

**Output:** Foundation of cleaning pipeline with safety guardrails

---

## Phase 7: Evolved Cleaning Pipeline (Days 22-26)

### Step 7.1: Prompt System

**PromptTemplate.swift** and **PromptManager.swift** provide variable substitution and actor-based template loading from bundle. Create 8 `.txt` prompt template files in `Resources/Prompts/`.

### Step 7.2: Evolved Services (Build Order — 12 files, ~3500 lines total)

1. **PromptTemplate.swift** — Template loader with variable substitution
2. **PromptManager.swift** — Actor-based thread-safe template management
3. **PatternExtractor.swift** (~300 lines) — Regex pattern detection for citations, footnotes, chapters
4. **ReconnaissanceResponseParser.swift** (~250 lines) — JSON parsing with type coercion for Claude responses
5. **ReconnaissanceService.swift** (~400 lines) — Document structure analysis (Claude-powered)
6. **BoundaryDetectionService.swift** (~450 lines) — Front/back matter detection with phase-aware constraints
7. **EnhancedReflowService.swift** (~350 lines) — AI paragraph reflow with poetry/verse detection
8. **ParagraphOptimizationService.swift** (~300 lines) — Long paragraph splitting with semantic preservation
9. **FinalReviewService.swift** (~250 lines) — Quality assessment and confidence rating
10. **ConfidenceTracker.swift** (~200 lines) — Real-time confidence aggregation across pipeline
11. **PipelineTelemetryService.swift** (~200 lines) — Local-only metrics (no external telemetry)
12. **EvolvedCleaningPipeline.swift** (~400 lines) — Orchestrator coordinating all evolved services

**Key Features:**
- All 8 prompt templates in Resources/Prompts/ directory
- Prompt variable substitution: {documentContent}, {sampleLength}, {contentType}, etc.
- Confidence scoring: per-step confidence aggregated to document confidence
- Telemetry: session-local only (no network transmission)

### Step 7: Verification Checklist

- [ ] Reconnaissance accurately identifies document structure
- [ ] Boundary detection distinguishes front/back matter
- [ ] Enhanced reflow improves paragraph readability
- [ ] Paragraph optimization handles long sections
- [ ] Final review identifies quality issues
- [ ] Confidence tracker aggregates pipeline confidence
- [ ] Telemetry collects local metrics only

**Output:** V3 evolved cleaning pipeline with intelligence

---

## Phase 8: Clean Tab UI (Days 27-30)

### Step 8.1-8.3: Cleaning ViewModel & UI Components

**CleaningViewModel.swift** integrates V3 pipeline. **CleanTabView.swift** provides the main interface with:
- Document selector
- Content preview
- Processing overlay
- Preset selector
- Content type detection
- Pipeline progress with phase awareness
- Detailed results and export

### Step 8: Verification Checklist

- [ ] Clean tab loads and displays documents
- [ ] Content type auto-detection works
- [ ] Preset selection changes pipeline behavior
- [ ] Processing overlay shows real-time progress
- [ ] Cleaned content preview renders correctly
- [ ] Export integration works

**Output:** Full cleaning UI for end-user interaction

---

## Phase 9: Onboarding & Polish (Days 31-33)

### Step 9.1: Onboarding

**OnboardingView.swift**, **OnboardingWizardView.swift**, and related components provide first-run experience.

### Step 9.2: Testing

Test files to implement (11 test files under HorusTests/):

**Core Model Tests:**
- DocumentTests.swift — Document model, status, workflow stage
- OCRResultTests.swift — OCR result validation, page parsing
- ProcessingSessionTests.swift — Session state, document collection limits

**Multi-Layer Defense Tests:**
- MultiLayerDefenseTests.swift (~500 lines) — Comprehensive defense system validation
  - Phase A (BoundaryValidation) safety
  - Phase B (ContentVerification) pattern matching
  - Phase C (HeuristicBoundaryDetection) weighted scoring
  - Integration: fallback mechanism when >30% removal detected

**Evolved Services Unit Tests:**
- ReconnaissanceServiceTests.swift — Document structure analysis
- BoundaryDetectionServiceTests.swift — Front/back matter detection
- EnhancedReflowServiceTests.swift — Paragraph reflow with poetry detection
- ParagraphOptimizationServiceTests.swift — Long paragraph splitting
- FinalReviewServiceTests.swift — Quality assessment
- ConfidenceTrackerTests.swift — Confidence aggregation
- PromptManagerTests.swift — Template loading and substitution
- StructureHintsTests.swift — Structure hint generation
- ContentTypeTests.swift — Content type detection

**Integration Tests:**
- CorpusTestRunner.swift (~200 lines) — Runs corpus tests on real documents
- CorpusComparisonTests.swift (~300 lines) — Compares before/after cleaning quality

**Infrastructure:**
- MockServices.swift — Mock implementations for testing without API calls
- ServiceTests.swift — Core service integration tests

All tests verify:
- Correct behavior and output format
- Edge cases (empty documents, large documents, malformed content)
- No catastrophic content removal
- Confidence scoring accuracy
- Performance within acceptable bounds

### Step 9.3: Polish

- Accessibility review (VoiceOver, keyboard navigation)
- Performance profiling and optimization
- Memory leak detection
- Edge case handling

### Step 9: Verification Checklist

- [ ] All unit tests pass
- [ ] Onboarding guides user through setup
- [ ] App meets WCAG accessibility standards
- [ ] Memory usage stays under 500MB during processing
- [ ] No console errors or warnings

**Output:** Production-ready Horus application

---

## Common Pitfalls & Solutions

### State Management
**Problem:** SwiftUI state not updating after async operations
**Solution:** Use `@Observable` (not `ObservableObject`). Mark AppState with `@MainActor`. Call state mutations from `@MainActor` context.

### List Selection
**Problem:** List selection doesn't sync with app state
**Solution:** Use exact type matching with `.tag()`. Ensure `Identifiable` conformance with `id` property. Use separate selection states per tab (selectedInputDocumentId, selectedLibraryDocumentId, selectedCleanDocumentId).

### Navigation
**Problem:** NavigationSplitView columns collapse unexpectedly
**Solution:** Set explicit `minWidth: 1110, idealWidth: 1400, minHeight: 600, idealHeight: 800` on MainWindowView. Use `navigationSplitViewColumnWidth()` modifier.

### Async Race Conditions
**Problem:** UI updates don't appear after network requests
**Solution:** Mark service methods with `@MainActor` for UI updates. Use `DispatchQueue.main.async` if needed. Ensure ClaudeService operations run on main thread.

### Boundary Removal Safety
**Problem:** Multi-layer defense catastrophically removes content
**Solution:** Test Phase A, B, C independently before integration. Implement fallback to Phase A if later phases remove >30% of content. Always preserve uncertain boundaries.

### Keychain Failures
**Problem:** "Operation not permitted" errors
**Solution:** Ensure app is signed with correct Team ID. Enable Keychain Sharing capability. Use "com.horus.app" service identifier. Test on actual macOS (simulator has Keychain issues).

### Claude JSON Parsing
**Problem:** JSONDecoder fails on Claude API responses
**Solution:** Handle markdown fences (```json, ```) in responses. Account for trailing commas in JSON. Use `AnyCodable` for flexible responses. Implement response text extraction via `textContent` computed property.

### Large Document Rendering
**Problem:** VirtualizedTextView scrolling is jittery
**Solution:** Use `LazyVStack` with `.id()` modifiers. Load 2000-character chunks on-demand. Implement scroll velocity detection for adaptive prefetch buffering. Limit visible text to 10,000 characters at once.

### Cost Precision
**Problem:** Decimal arithmetic produces rounding errors
**Solution:** Always use `Decimal` type (not `Double`). Use `NSDecimalNumber` for formatting. ClaudeUsage.estimatedCost automatically calculates with proper precision. CostCalculator uses Decimal for all calculations.

### Processing State Consistency
**Problem:** Document status gets out of sync with actual processing state
**Solution:** Use `@Observable` on Document model. Update status atomically with results. Persist to Keychain or UserDefaults as needed. Validate state transitions (pending → processing → completed/failed).

### Memory with Large PDFs
**Problem:** App crashes when processing 100+ page documents
**Solution:** Implement lazy page loading. Use PDFDocument page-by-page processing. Implement thumbnail caching with LRU eviction (max 50). Clear unused cached pages during scrolling.

### API Rate Limiting
**Problem:** "Too Many Requests" (429) errors from Claude/Mistral
**Solution:** Implement exponential backoff: 2s × 2^(attempt-1). Maximum 2 retries for Claude, 3 for Mistral. Sequential processing (not parallel) for predictable throttling. Respect server-side rate limit headers.

### File I/O on macOS App Sandbox
**Problem:** Cannot access user files or save to Documents
**Solution:** Require security-scoped bookmark URLs. Call startAccessingSecurityScopedResource(). Use Documents directory from FileManager. Enable "App Sandbox" capability with "Outgoing Connections (Client)" and "Keychain Sharing".

---

## Dependency Map

```
Phase 1 (Foundation)
├─ Models: ExportFormat, DocumentStatus, Document, OCRResult, ProcessingSession, UserPreferences
├─ Errors: HorusError, CleaningError
├─ Extensions: Accessibility, Notifications
└─ App Shell: AppState, HorusApp, MainWindowView

Phase 2 (Services)
├─ Depends on: Phase 1 models
├─ Services: Keychain, Network, APIValidator, CostCalculator, DocumentService
└─ Settings Views

Phase 3 (Document Management)
├─ Depends on: Phase 1, 2
├─ Navigation: Sidebar, DocumentQueue, InputView
└─ Components: TabHeader, DocumentListRow, Inspector, ContentArea

Phase 4 (OCR Processing)
├─ Depends on: Phase 1, 2, 3
├─ OCRService: API models, service implementation, ViewModel
├─ OCRTabView
└─ Thumbnails & Stats

Phase 5 (Library & Export)
├─ Depends on: Phase 1, 2, 3, 4
├─ ExportService: Markdown, JSON, PlainText generation
├─ LibraryView: Document browser
└─ Preview Components

Phase 6 (Cleaning Foundation)
├─ Depends on: Phase 1, 2
├─ Models: CleaningStep, ContentType, Preset, CleanedContent (17 types)
├─ Services: Claude, TextProcessing, PatternDetection
└─ Defense: BoundaryValidation, ContentVerification, HeuristicDetection

Phase 7 (Evolved Pipeline)
├─ Depends on: Phase 6
├─ Services: Reconnaissance, BoundaryDetection, Reflow, Optimization, FinalReview
├─ Confidence & Telemetry
└─ EvolvedCleaningPipeline Orchestrator

Phase 8 (Clean Tab UI)
├─ Depends on: Phase 3, 6, 7
├─ ViewModel: CleaningViewModel
├─ Views: CleanTabView, Inspector, Components
└─ Export Integration

Phase 9 (Onboarding & Polish)
└─ Depends on: All above
```

---

## Implementation Timeline Summary

| Phase | Duration | Key Output |
|-------|----------|-----------|
| 1 | Days 1-3 | Foundation: Models, errors, app shell (launches) |
| 2 | Days 4-6 | Services: Keychain, network, API validation |
| 3 | Days 7-9 | UI: Navigation, sidebar, document import |
| 4 | Days 10-13 | OCR: Processing, API integration, results display |
| 5 | Days 14-16 | Export: Library, file generation, batch operations |
| 6 | Days 17-21 | Cleaning: Models, Claude integration, multi-layer defense |
| 7 | Days 22-26 | Evolved: Intelligence services, pipeline orchestration |
| 8 | Days 27-30 | UI: Cleaning tab, presets, content detection |
| 9 | Days 31-33 | Polish: Testing, accessibility, performance |

**File Statistics:**
- Total Swift files: ~114
- Production code files: ~80
- Test files: ~11 (CorpusTests, UnitTests, MultiLayerDefenseTests, ServiceTests)
- Model files: ~30
- Service files: ~20
- View/ViewModel files: ~25

**Lines of Code (Estimated):**
- Total production: ~25,000 lines
- Core services: ~12,000 lines (ClaudeService, OCRService, CleaningService + defense layers)
- UI/Views: ~8,000 lines (MainWindow, Input, OCR, Library, Clean tabs + components)
- Models: ~3,000 lines
- Tests: ~2,000 lines

**Total: 33 days, 114 Swift files (~25,000 lines of production code)**

---

## Success Criteria

At completion, Horus should:

1. **Import** PDFs, images, DOCX via drag-and-drop or file picker (InputView with QuickProcessingOptionsView)
2. **Process** documents with OCR (Mistral API) showing real-time progress (ProcessingViewModel, OCRTabView, PhaseAwareProgressView)
3. **Display** OCR results with page navigation and cost tracking (PageThumbnailsView, SessionStatsView)
4. **Export** to Markdown, JSON, and Plain Text formats with metadata (ExportService, ExportSheetView, BatchExportSheetView)
5. **Clean** documents with V3 pipeline: reconnaissance, boundaries, reflow, optimization, review (CleaningService, EvolvedCleaningPipeline)
6. **Detect** content type automatically: 11 types with confidence scoring (ContentTypeDetection Claude operation)
7. **Apply** presets: conservative, balanced, aggressive, custom (PresetType, PresetSelectorView)
8. **Track** session costs and statistics with Decimal precision (CostCalculator, SessionStats, sessionStats in AppState)
9. **Store** API keys securely in Keychain: com.horus.mistral and com.horus.claude (KeychainService)
10. **Persist** preferences to UserDefaults: presets, export formats, UI state (UserPreferences)
11. **Support** accessibility with VoiceOver and keyboard navigation (Accessibility.swift, all views with accessibilityLabel/accessibilityHint)
12. **Handle** errors gracefully with recovery suggestions (HorusError, CleaningError, RecoveryNotificationView)
13. **Show** 16-step cleaning pipeline with real-time phase progress (CleanTabView, PipelineStepRow, PhaseAwareProgressView)
14. **Prevent** catastrophic content removal via multi-layer defense (BoundaryValidation, ContentVerification, HeuristicBoundaryDetection)
15. **Validate** all API keys before use (APIKeyValidator, validateAPIKey operations)
16. **Support** onboarding wizard for first-time setup (OnboardingWizardView, OnboardingStepView)

---

## Entitlements & Capabilities

**App Sandbox Entitlements (required):**
- Outgoing Connections (Client): For API communication to Mistral/Claude
- Keychain Sharing: For secure API key storage (com.apple.security.application-groups)

**Required Capabilities:**
- App Sandbox: Enabled (read-only file access for document processing)
- Keychain Sharing: Enabled (kSecAttrAccessibleWhenUnlocked)

**NOT Required (for privacy):**
- No network server capabilities (client-only connections)
- No local networking
- No system extensions
- No accessibility permissions (VoiceOver provided by system)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 2026 | Initial implementation guide |
| 2.0 | Jan 2026 | V2 redesign with evolved pipeline structure |
| 3.0 | Feb 2026 | Comprehensive rebuild guide with detailed file specifications |
| 3.1 | Feb 8, 2026 | Quality review: Added missing details for API models, services, UI architecture, test structure, line counts |

---

**Document Owner:** Horus Project Lead
**Last Updated:** February 8, 2026
**Status:** Current & Complete
