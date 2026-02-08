# Technical Architecture Document: Horus Project
## Version 2.0 - Current State Architecture

**Document Version:** 2.0
**Last Updated:** February 2026
**Status:** Current Production Architecture
**Scope:** Comprehensive technical architecture reflecting the live state of Horus

---

## Executive Summary

Horus is a sophisticated macOS document processing application built with Swift 6.0, leveraging SwiftUI for presentation and a meticulously layered service architecture for document cleaning, optical character recognition (OCR), and intelligent content transformation. The system employs an advanced three-phase validation framework coupled with an evolved cleaning pipeline that integrates machine learning (Claude API), pattern recognition, and heuristic analysis to transform raw scanned documents into semantically correct, well-structured markdown content.

The architecture emphasizes strict concurrency safety, maintainability through protocol-driven design, and extensibility through a modular service layer. The system processes documents through reconnaissance, boundary detection, semantic reflow, and multi-layer validation stages, ultimately producing publication-ready content with comprehensive metadata and confidence tracking.

---

## 1. Architectural Layers Overview

### 1.1 Layer Stack Architecture

Horus implements a six-layer vertical architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────┐
│    PRESENTATION LAYER (SwiftUI Views)           │
│  MainWindowView, Tab Views, Inspector Views     │
├─────────────────────────────────────────────────┤
│    VIEW MODEL LAYER (@Observable)               │
│  CleaningViewModel, ProcessingViewModel,        │
│  DocumentQueueViewModel, ExportViewModel        │
├─────────────────────────────────────────────────┤
│         SERVICE LAYER (Public API)              │
│  CleaningService, OCRService, ClaudeService,   │
│  DocumentService, ExportService, etc.           │
├─────────────────────────────────────────────────┤
│  EVOLVED CLEANING PIPELINE (V3 Engine)          │
│  EvolvedCleaningPipeline with 6-stage flow,    │
│  Reconnaissance, Boundary Detection, Reflow     │
├─────────────────────────────────────────────────┤
│    VALIDATION LAYER (Phase A/B/C Defense)       │
│  BoundaryValidator, ContentVerifier,            │
│  HeuristicBoundaryDetector                      │
├─────────────────────────────────────────────────┤
│      DATA & MODELS LAYER (Domain Objects)       │
│  Document, OCRResult, CleanedContent,           │
│  ProcessingSession, StructureHints              │
├─────────────────────────────────────────────────┤
│    EXTERNAL INTEGRATIONS (APIs & System)        │
│  Claude API, Mistral API, macOS Keychain,      │
│  PDFKit, OSLog                                  │
└─────────────────────────────────────────────────┘
```

### 1.2 Layer Responsibilities

**Presentation Layer:** Responsible for all user interaction, real-time feedback, and visual representation. Implements SwiftUI-based UI components with selective AppKit integration via NSViewRepresentable for advanced text editing and PDF viewing. Maintains view-local state through @State and @Binding, delegating business logic to view models. Main window view coordinates 5 navigation tabs (input, ocr, clean, library, settings) with badge counts for pending/processing documents.

**View Model Layer:** Acts as a bridge between presentation and services using the @Observable macro. Provides view-friendly data transformation, reactive updates, and user action coordination. Each feature has a dedicated view model (CleaningViewModel for document processing, ProcessingViewModel for pipeline state, ExportViewModel for output generation).

**Service Layer:** Implements business logic and orchestrates operations across the application. Services are protocol-based, enabling dependency injection, testability, and loose coupling. This layer coordinates API calls, manages state transitions, and implements domain-level workflows.

**Evolved Cleaning Pipeline:** The core document transformation engine implementing the V3 processing strategy. Orchestrates six sequential stages: reconnaissance, boundary detection, semantic reflow, paragraph optimization, final review, and export preparation. Maintains accumulated context across phases and supports multi-document batch processing.

**Validation Layer:** Implements the three-phase defense system for ensuring document integrity. Phase A applies structural constraints, Phase B performs semantic verification, and Phase C uses AI-independent heuristic detection. This layered approach provides defense in depth against processing errors.

**Data & Models Layer:** Defines all domain objects, data structures, and value types. Implements Codable conformance for persistence, computed properties for derived data, and appropriate equality semantics. Models are immutable where possible, enabling safe concurrent access.

**External Integrations:** Manages communication with third-party services (Claude API, Mistral API) and system frameworks (Keychain, PDFKit). Abstracts external dependencies through protocol adapters, enabling mock implementations for testing.

---

## 2. Technology Stack

### 2.1 Core Technologies

**Language:** Swift 6.0 with strict concurrency checking enabled. The compiler enforces comprehensive data-race prevention and sendability constraints, eliminating entire classes of concurrency bugs at compile time.

**UI Framework:** SwiftUI as primary presentation framework, supplemented with selective AppKit components through NSViewRepresentable for specialized text editing and PDF manipulation capabilities unavailable in pure SwiftUI.

**Concurrency Model:** Modern Swift async/await with @MainActor annotations, actor-based isolation for shared mutable state, structured concurrency via Task groups, and task cancellation support for responsive cancellation of long-running operations.

**Networking:** Native URLSession for all HTTP communication with no third-party HTTP client dependencies. Custom NetworkClient implements request/response serialization, error handling, and retry logic.

**Storage:**
- **Keychain:** Secure storage for API credentials using SecItem APIs
- **UserDefaults:** Configuration and preferences with JSON encoding for complex structures
- **File System:** Document storage with UTType-based content type detection

**Logging:** OSLog with privacy annotations for security-sensitive operations. Log messages are redacted by default unless explicitly marked as not private.

**PDF Processing:** PDFKit for page counting, thumbnail generation, and basic PDF introspection.

**Testing:** Swift Testing framework (modern async/concurrent testing) combined with XCTest for legacy test compatibility.

### 2.2 Dependency Management

The application uses no external package dependencies, maintaining a pure Swift/Apple framework stack. This approach:
- Eliminates supply chain vulnerabilities
- Ensures deterministic builds
- Simplifies deployment and versioning
- Leverages Apple's battle-tested frameworks

---

## 3. Code Organization & File Structure

### 3.1 Directory Structure

```
Horus/
├── App/
│   ├── HorusApp.swift              # Application entry point
│   └── AppState.swift              # Global application state (@Observable)
│
├── Core/
│   ├── Errors/
│   │   ├── CleaningError.swift    # Cleaning-specific errors
│   │   └── HorusError.swift        # Application-level errors
│   │
│   ├── Models/
│   │   ├── APIModels/
│   │   │   ├── ClaudeAPIModels.swift
│   │   │   └── OCRAPIModels.swift
│   │   │
│   │   ├── CleaningModels/         # 17 cleaning-specific models
│   │   │   ├── AccumulatedContext.swift
│   │   │   ├── AuxiliaryListTypes.swift
│   │   │   ├── ChapterMarkerStyle.swift
│   │   │   ├── CitationTypes.swift
│   │   │   ├── CleanedContent.swift
│   │   │   ├── CleaningConfiguration.swift
│   │   │   ├── CleaningProgress.swift
│   │   │   ├── CleaningStep.swift
│   │   │   ├── ContentType.swift
│   │   │   ├── ContentTypeFlags.swift
│   │   │   ├── DetectedPatterns.swift
│   │   │   ├── DocumentMetadata.swift
│   │   │   ├── EndMarkerStyle.swift
│   │   │   ├── FootnoteTypes.swift
│   │   │   ├── PipelinePhase.swift
│   │   │   └── PresetType.swift
│   │   │
│   │   └── CoreModels/
│   │       ├── Document.swift
│   │       ├── DocumentStatus.swift
│   │       ├── DocumentWorkflowStage.swift
│   │       ├── ExportFormat.swift
│   │       ├── OCRResult.swift
│   │       ├── ProcessingSession.swift
│   │       ├── StructureHints.swift
│   │       ├── TokenEstimator.swift
│   │       └── UserPreferences.swift
│   │
│   ├── Services/
│   │   ├── EvolvedCleaning/        # 12 pipeline-specific services
│   │   │   ├── EvolvedCleaningPipeline.swift
│   │   │   ├── ReconnaissanceService.swift
│   │   │   ├── ReconnaissanceResponseParser.swift
│   │   │   ├── BoundaryDetectionService.swift
│   │   │   ├── EnhancedReflowService.swift
│   │   │   ├── FinalReviewService.swift
│   │   │   ├── ParagraphOptimizationService.swift
│   │   │   ├── PatternExtractor.swift
│   │   │   ├── PipelineTelemetryService.swift
│   │   │   ├── PromptManager.swift
│   │   │   ├── PromptTemplate.swift
│   │   │   └── ConfidenceTracker.swift
│   │   │
│   │   └── CoreServices/           # 13 core application services
│   │       ├── APIKeyValidator.swift
│   │       ├── ClaudeService.swift
│   │       ├── CleaningService.swift
│   │       ├── CostCalculator.swift
│   │       ├── DocumentService.swift
│   │       ├── ExportService.swift
│   │       ├── KeychainService.swift
│   │       ├── MockClaudeService.swift
│   │       ├── NetworkClient.swift
│   │       ├── OCRService.swift
│   │       ├── PatternDetectionService.swift
│   │       ├── TextProcessingService.swift
│   │       └── ThumbnailCache.swift
│   │
│   └── Utilities/
│       ├── BoundaryValidation.swift
│       ├── ContentVerification.swift
│       ├── DesignConstants.swift
│       ├── HeuristicBoundaryDetection.swift
│       ├── Extensions/
│       │   ├── Accessibility.swift
│       │   └── Notifications.swift
│       └── [Additional utility modules]
│
├── Features/                        # Feature-specific modules
│   ├── Cleaning/
│   │   ├── ViewModels/CleaningViewModel.swift
│   │   └── Views/                  # 10 cleaning-specific view files
│   │
│   ├── DocumentQueue/
│   │   └── ViewModels/DocumentQueueViewModel.swift
│   │
│   ├── Export/
│   │   ├── ViewModels/ExportViewModel.swift
│   │   └── Views/                  # 2 export view files
│   │
│   ├── Library/
│   │   └── Views/                  # 3 library view files
│   │
│   ├── MainWindow/
│   │   └── Views/                  # 9 main window view files
│   │
│   ├── OCR/
│   │   └── Views/OCRTabView.swift
│   │
│   ├── Onboarding/
│   │   └── Views/                  # 4 onboarding view files
│   │
│   ├── Processing/
│   │   └── ViewModels/ProcessingViewModel.swift
│   │
│   ├── Queue/
│   │   └── Views/                  # 2 queue view files
│   │
│   └── Settings/
│       └── Views/                  # 4 settings view files
│
├── Shared/
│   └── Components/                 # Reusable UI components
│       ├── ContentHeaderView.swift
│       ├── DocumentListRow.swift
│       ├── InspectorComponents.swift
│       ├── PipelineStatusIcons.swift
│       ├── TabFooterView.swift
│       └── TabHeaderView.swift
│
└── UI/
    └── Components/Cleaning/        # Cleaning-specific UI components
        ├── BetaFeedbackView.swift
        ├── ContentTypePicker.swift
        ├── DetailedResultsView.swift
        ├── EvolvedPipelineReleaseNotes.swift
        ├── IssueReporterView.swift
        ├── PhaseAwareProgressView.swift
        └── RecoveryNotificationView.swift
```

### 3.2 Organizational Principles

**Vertical Slicing by Feature:** Each feature (Cleaning, Export, OCR, etc.) is self-contained within its directory, containing both view models and views specific to that feature.

**Horizontal Organization by Layer:** Core infrastructure (Services, Models, Utilities) is organized by architectural layer, enabling developers to understand system-wide patterns and cross-cutting concerns.

**Protocol-Based Dependency Injection:** Services expose protocol interfaces, enabling injection of mock implementations for testing without modifying production code.

**Naming Conventions:** Services follow `{Domain}Service` convention, view models use `{Feature}ViewModel`, and views are named descriptively (e.g., `DetailedResultsView`, `PhaseAwareProgressView`).

---

## 4. Data Models & Domain Objects

### 4.0 Navigation and Tab Management

**NavigationTab Enum** (5 cases) with badge counts:
```swift
enum NavigationTab: String, CaseIterable {
    case input      // File import and upload
    case ocr        // OCR processing results
    case clean      // Document cleaning operations
    case library    // Processed documents and history
    case settings   // Application configuration

    // Badge count properties
    var badgeCount: Int {
        // Dynamically computed from AppState
        // input: pending documents count
        // ocr: documents in OCR stage
        // clean: documents in cleaning stage
        // library: completed documents count
        // settings: 0
    }
}
```

**Tab Responsibilities:**
- **Input Tab**: Drag-drop file import, file picker dialog, batch import management
- **OCR Tab**: OCR processing queue, page-by-page progress, thumbnail previews
- **Clean Tab**: Cleaning pipeline control, step toggles, preset selection, progress tracking
- **Library Tab**: Document history, search/filter, re-process options, export interface
- **Settings Tab**: API key management, processing preferences, export defaults, about information

---

### 4.1 Core Domain Models

**Document:** The central entity representing a source document being processed.
- **Identifier:** id (UUID for uniqueness)
- **Source:** filename (original), displayName (display version)
- **Metadata:** fileSize (bytes), importedAt, processingStartedAt, completedAt, estimatedPageCount, actualPageCount, estimatedCost, actualCost
- **Status:** Tracked through DocumentStatus enum with state transitions via nextStatus() method
  - Values: pending, processing, completed, failed, cancelled
- **Workflow Stage:** DocumentWorkflowStage with progression via nextStage() method
  - Values: awaiting, ocr, cleaning, export, complete, error
- **Results:** Optional OCRResult (if OCR performed) and CleanedContent (if cleaning completed)
- **Notes:** User-added notes or processing metadata
- **Processing Pathway:** Enum routing documents OCR vs direct-to-clean based on content type

**OCRResult:** Encapsulates the output of optical character recognition.
- **Identifiers:** id (UUID), documentId (reference to parent Document)
- **Content:** rawContent (original), markdownContent (formatted), pageCount, wordCount, characterCount, estimatedTokenCount
- **Metadata:** processedAt (timestamp), confidence (0.0-1.0 scoring)
- **Language Detection:** Detected language and language confidence
- **API Tracking:** apiCallCount, tokensUsed
- **Model Information:** Which OCR model was used (mistral-ocr-latest)
- **Cost Tracking:** Financial cost with Decimal precision
- **Computed Properties:** contentWithMetadata(), toJSON(), fullMarkdown, fullPlainText

**CleanedContent:** The final product of document processing (V2 with enhanced tracking).
- **Markdown Output:** cleanedMarkdown containing formatted, semantically correct content
- **Metadata:** Comprehensive DocumentMetadata including document title, author, creation date
- **Pattern Analysis:** detectedPatterns tracking what structural patterns were found
- **V2 Additions:** auxiliaryListsRemoved (boolean), citationsRemoved (count), footnoteMarkersRemoved (count), chaptersDetected (count), contentTypeFlags (dictionary)
- **Removal Records:** AccumulatedContext tracking what was removed (type, lineRange, wordCount, phase, justification, validationMethod, confidence)
- **Validation Data:** Confirmed boundaries, transformations, checkpoints, flagged content, recovery snapshots
- **Statistics:** Detailed breakdown including phase results and quality issues
- **Cost Information:** Token usage and processing cost with Decimal precision
- **Duration:** Processing time for the entire pipeline
- **Quality Metrics:** QualityIssue structs, ComparisonStats for before/after analysis

**CleaningConfiguration:** User-configurable settings for the cleaning pipeline.
- **Preset:** Selectable preset (Default, Training, Minimal, Scholarly, Custom)
- **Toggleable Steps:** 14 feature flags enabling/disabling specific pipeline stages (removeTableOfContents, removeAuxiliaryLists, removeCitations, removeFootnotesEndnotes, etc.)
- **Parameters:**
  - maxParagraphWords: target paragraph length optimization
  - metadataFormat: YAML vs JSON metadata embedding
  - chapterMarkerStyle: none, htmlComments, markdownH1, markdownH2, tokenStyle
  - endMarkerStyle: none, minimal, simple, standard, htmlComment, markdownHR, token, tokenWithAuthor
  - enableChapterSegmentation: boolean for structural chapter detection
- **Confidence Thresholds:** 3 configurable confidence level thresholds (minimum, warning, optimal)
- **Feature Flags:** useEvolvedPipeline boolean enabling V3 processing engine

**ProcessingSession:** Manages a batch of documents being processed concurrently.
- **Marked as @Observable:** Reactive updates trigger view refresh
- **Capacity:** Maximum 50 documents per session (hard limit)
- **Collections:** Computed groupings by stage:
  - queuedDocuments (status == pending)
  - processingDocuments (status == processing)
  - completedDocuments (status == completed)
  - failedDocuments (status == failed)
- **Cost Tracking:** Aggregate cost of all documents in session with real-time updates

**StructureHints:** Document DNA extracted during reconnaissance phase.
- **Detected Regions:** 23+ RegionTypes including headers, footers, sidebars, footnotes, chapter markers, table of contents, index entries, page numbers, etc.
- **Region Information:** Line ranges, confidence levels, content characteristics
- **Content Characteristics:** Detected patterns and content types with confidence scores
- **Detection Methods:** aiAnalysis, patternMatching, heuristic, userSpecified
- **Confidence Factors:** Per-region confidence scoring (0.0-1.0)
- **Warnings:** Detected issues or ambiguities in structure analysis
- **Pattern Library:** Observed patterns and their frequencies
- **Line Range Tracking:** Precise line/page references for all detected elements

**AccumulatedContext:** Multi-phase state tracking throughout pipeline execution.
- **Removal Records:** Detailed tracking (type, lineRange, wordCount, phase, justification, validationMethod, confidence)
  - Records what was removed, why, and with what confidence
  - Enables recovery and rollback operations
- **Confirmed Boundaries:** Validated paragraph, section, and chapter boundaries
- **Transformations:** Complete audit trail of all transformations applied
  - Content reflow operations
  - Formatting changes
  - Structural modifications
- **Validation Checkpoints:** Stores validation results and decisions at each phase (Phase A, B, C)
- **Flagging System:** Marks content requiring human review with severity levels
- **Recovery Snapshots:** Saves full state at phase boundaries for potential rollback

### 4.2 Model Relationships

Models follow a composition hierarchy:
- Document contains OCRResult (optional) and CleanedContent (optional)
- CleanedContent references DocumentMetadata and DetectedPatterns
- ProcessingSession contains multiple Documents
- AccumulatedContext tracks transformations through all phases

---

## 5. Service Layer Architecture

### 5.1 Service Protocols

The service layer is built on protocol-based abstraction, enabling dependency injection and testability:

```swift
protocol OCRServiceProtocol {
    func performOCR(on document: Document) async throws -> OCRResult
}

protocol ClaudeServiceProtocol {
    func sendPrompt(_ prompt: String, context: String?) async throws -> String
}

protocol CleaningServiceProtocol {
    func cleanDocument(_ document: Document, config: CleaningConfiguration) async throws -> CleanedContent
}

protocol PatternDetectionServiceProtocol {
    func detectPatterns(in content: String) async throws -> DetectedPatterns
}

protocol DocumentServiceProtocol {
    func saveDocument(_ document: Document) async throws
    func loadDocument(with id: UUID) async throws -> Document?
}

protocol ExportServiceProtocol {
    func export(_ content: CleanedContent, format: ExportFormat) async throws -> Data
}

protocol KeychainServiceProtocol {
    func storeAPIKey(_ key: String, for service: String) throws
    func retrieveAPIKey(for service: String) throws -> String?
}

protocol CostCalculatorProtocol {
    func estimateTokens(for text: String) -> Int
    func calculateCost(tokens: Int, model: String) -> Decimal
}

protocol APIKeyValidatorProtocol {
    func validateAPIKey(_ key: String, for service: String) async throws -> Bool
}

protocol NetworkClientProtocol {
    func request<T: Codable>(_ endpoint: String, method: String, body: Encodable?) async throws -> T
}
```

### 5.2 Service Implementations

**ClaudeService:** Manages communication with the Claude API.
- Implements message history management
- Handles streaming responses for long-form content
- Manages token counting and cost estimation
- Implements retry logic with exponential backoff
- Marked @MainActor for UI thread safety

**OCRService:** Orchestrates optical character recognition.
- Routes documents to appropriate OCR provider
- Implements page-by-page processing for large PDFs
- Tracks processing cost and duration
- Marked @MainActor for UI coordination

**CleaningService:** Primary orchestrator of the document cleaning process.
- Initializes and coordinates the EvolvedCleaningPipeline
- Manages document state transitions
- Implements error recovery and rollback
- Coordinates validation phases

**DocumentService:** Handles document persistence and retrieval.
- Manages document storage in file system
- Implements CRUD operations
- Handles file format conversion
- Manages document library indexing

**ExportService:** Generates output in various formats.
- Supports Markdown, PDF, JSON export formats
- Implements formatting and styling rules per format
- Handles metadata embedding
- Manages export error handling

**PatternDetectionService:** Identifies structural patterns in content.
- Detects citations, footnotes, auxiliary lists
- Identifies chapter boundaries and hierarchies
- Implements language-agnostic pattern recognition
- Provides confidence metrics for each pattern

**KeychainService:** Secure credential storage.
- Uses SecItem APIs for Keychain access
- Implements CRUD for API keys
- Handles access control and privacy
- Provides query and deletion capabilities

**ThumbnailCache:** Performance optimization via caching.
- Implements LRU (Least Recently Used) eviction
- Supports quality tiering (low/medium/high)
- Marked @Published for reactive updates
- Manages memory pressure with automatic cleanup

### 5.3 Service Composition in AppState

**AppState.swift** (1151 lines) serves as the single source of truth for the entire application:

```swift
@Observable
final class AppState {
    // Services
    let ocrService: OCRServiceProtocol
    let claudeService: ClaudeServiceProtocol
    let cleaningService: CleaningServiceProtocol
    let documentService: DocumentServiceProtocol
    let exportService: ExportServiceProtocol
    let keychain: KeychainServiceProtocol
    let costCalculator: CostCalculatorProtocol
    let patternDetectionService: PatternDetectionServiceProtocol
    let textProcessingService: TextProcessingServiceProtocol
    let thumbnailCache: ThumbnailCache

    // State Management
    var processingSession: ProcessingSession = ProcessingSession()
    var currentNavigationTab: NavigationTab = .input
    var userPreferences: UserPreferences = .default

    // Computed Collections (FilteredDocuments)
    var queuedDocuments: [Document] { processingSession.documents.filter { $0.status == .pending } }
    var processingDocuments: [Document] { processingSession.documents.filter { $0.status == .processing } }
    var completedDocuments: [Document] { processingSession.documents.filter { $0.status == .completed } }
    var failedDocuments: [Document] { processingSession.documents.filter { $0.status == .failed } }

    // Badge Counts for Navigation Tabs
    var inputBadgeCount: Int { queuedDocuments.count }
    var ocrBadgeCount: Int { processingDocuments.filter { $0.workflowStage == .ocr }.count }
    var cleanBadgeCount: Int { processingDocuments.filter { $0.workflowStage == .cleaning }.count }
    var libraryBadgeCount: Int { completedDocuments.count }

    init() {
        // Initialize with production implementations
        self.keychain = KeychainService()
        self.documentService = DocumentService()
        self.claudeService = ClaudeService(keychain: keychain)
        // ... other services
    }
}
```

---

## 6. Evolved Cleaning Pipeline (V3 Engine)

### 6.1 Pipeline Architecture

The Evolved Cleaning Pipeline is the core transformation engine, implementing a sophisticated six-stage workflow:

**Stage 1: Reconnaissance** (ReconnaissanceService)
- Analyzes document structure without modification
- Extracts document DNA (StructureHints)
- Identifies regions, content characteristics, and patterns
- Generates confidence metrics
- Creates baseline for boundary detection

**Stage 2: Boundary Detection** (BoundaryDetectionService)
- Identifies section, chapter, and paragraph boundaries
- Uses both AI-guided and heuristic approaches
- Applies position and size constraints
- Produces boundary map with confidence levels
- Handles edge cases (orphaned text, misplaced headers)

**Stage 3: Semantic Reflow** (EnhancedReflowService)
- Restructures content respecting identified boundaries
- Applies semantic understanding to reformat text
- Maintains logical relationships between elements
- Handles complex layout patterns (columns, sidebars)
- Preserves emphasis and formatting intent

**Stage 4: Paragraph Optimization** (ParagraphOptimizationService)
- Optimizes paragraph breaks and whitespace
- Adjusts line wrapping for readability
- Balances paragraph length and density
- Handles orphaned lines and widows
- Maintains semantic grouping

**Stage 5: Final Review** (FinalReviewService)
- Performs comprehensive content validation
- Detects and flags anomalies
- Applies final cleanup
- Generates quality metrics
- Produces processing summary

**Stage 6: Export Preparation**
- Formats content according to output requirements
- Embeds metadata
- Optimizes for distribution
- Generates multiple output formats as needed

### 6.2 Pipeline State Management

The EvolvedCleaningPipeline maintains state across all stages through AccumulatedContext:

```swift
class EvolvedCleaningPipeline {
    var accumulatedContext: AccumulatedContext

    func executePhase(_ phase: PipelinePhase) async throws -> AccumulatedContext {
        // Execute single phase
        // Update accumulatedContext
        // Record transformation
        // Create recovery snapshot
    }

    func executeFull(document: Document, config: CleaningConfiguration) async throws -> CleanedContent {
        // Execute all phases sequentially
        // Accumulate context across phases
        // Apply validations
        // Generate results
    }
}
```

### 6.3 Multi-Phase Validation Defense System

**Phase A (BoundaryValidator):** Structural validation layer.
- Position constraints: Verifies elements are within expected page regions
- Size constraints: Checks element dimensions are reasonable
- Confidence thresholds: Enforces minimum confidence per section type
- Hierarchy constraints: Validates nesting and ordering

**Phase B (ContentVerifier):** Semantic validation layer.
- Pattern verification: Validates detected patterns match content
- Language support: Multi-language pattern recognition
- Consistency checking: Cross-references with document metadata
- Anomaly detection: Identifies suspicious patterns

**Phase C (HeuristicBoundaryDetector):** AI-independent validation layer.
- Weighted pattern detection: Applies domain-specific rules
- Statistical analysis: Detects outliers and inconsistencies
- Format validation: Ensures output follows expected format
- Recovery recommendations: Suggests corrections

### 6.4 Telemetry & Confidence Tracking

**PipelineTelemetryService:** Tracks pipeline execution metrics.
- Phase duration and cost
- Processing steps executed
- Validation results
- Error rates and recovery attempts

**ConfidenceTracker:** Maintains confidence metrics throughout pipeline.
- Per-element confidence scores
- Cumulative confidence tracking
- Threshold management
- Confidence-based filtering

---

## 7. State Management

### 7.1 Application State

AppState serves as the single source of truth using the @Observable macro:

```swift
@Observable
final class AppState {
    // Services
    let ocrService: OCRServiceProtocol
    let claudeService: ClaudeServiceProtocol
    // ... other services

    // State
    var processingSession: ProcessingSession
    var currentDocument: Document?
    var selectedFormat: ExportFormat = .markdown

    // Computed state
    var totalCost: Decimal {
        processingSession.documents.reduce(0) { $0 + $1.cost }
    }
}
```

### 7.2 View Model Pattern

View models use @Observable to provide reactive updates:

```swift
@Observable
final class CleaningViewModel {
    var progress: CleaningProgress
    var currentPhase: PipelinePhase?
    var error: CleaningError?
    var isProcessing: Bool = false

    func startCleaning(_ document: Document) async {
        isProcessing = true
        do {
            let result = try await cleaningService.cleanDocument(document, config: configuration)
            // Update state
        } catch {
            self.error = error as? CleaningError
        }
        isProcessing = false
    }
}
```

### 7.3 Local View State

SwiftUI's @State and @Binding manage view-local, non-reactive state:
- Form field values
- Presentation state (sheets, popovers)
- Scroll position and focus
- Transient UI state

---

## 8. Error Handling Architecture

### 8.1 Error Hierarchy

**CleaningError:** Document processing errors with specialized cases and recovery information.
```swift
enum CleaningError: LocalizedError {
    case apiError(String)           // External API failures
    case documentError(String)      // Document format/parsing issues
    case processingError(String)    // Pipeline execution failures
    case userActionRequired(String) // User must act to proceed

    // Error classification properties
    var isRetryable: Bool            // Can be automatically retried
    var isRecoverable: Bool          // Can be recovered through user action
    var requiresUserAction: Bool     // Requires explicit user intervention
    var retryDelay: TimeInterval     // Suggested delay before retry
}
```

**Error Categories:**
- **API Errors:** Network timeouts, rate limiting, authentication failures
- **Document Errors:** Invalid format, encryption, file system access
- **Processing Errors:** Pipeline step failures, validation errors
- **User Action Errors:** Missing configuration, insufficient permissions

**HorusError:** Application-level errors.
```swift
enum HorusError: LocalizedError {
    case documentLoadError(String)   // Document retrieval failures
    case networkError(String)        // Network connectivity issues
    case keystoreError(String)       // Keychain access failures
    case exportError(String)         // Export operation failures
    case sessionError(String)        // Session management failures
}
```

### 8.2 Error Classification

Each error implements properties for intelligent handling:

```swift
var isRetryable: Bool {
    // Network errors, timeouts are retryable
}

var isRecoverable: Bool {
    // Some errors can be recovered through user action
}

var requiresUserAction: Bool {
    // Invalid configuration requires user intervention
}
```

### 8.3 Retry Strategies

ClaudeService implements exponential backoff:
- Initial delay: 100ms
- Maximum delay: 30 seconds
- Exponential multiplier: 2.0
- Maximum attempts: 3

---

## 9. Concurrency & Threading Model

### 9.1 Strict Concurrency Checking

The project compiles with Swift 6.0 strict concurrency checking enabled, enforcing:
- Sendability requirements for all data crossing isolation boundaries
- Explicit actor declaration for shared mutable state
- No data races possible at compile time

### 9.2 Concurrency Annotations

**@MainActor Services:** UI-bound services with main thread enforcement.
```swift
@MainActor
final class ClaudeService: ClaudeServiceProtocol {
    func sendPrompt(_ prompt: String) async throws -> String {
        // Guaranteed to execute on main thread
    }
}
```

**Async/Await:** Throughout the codebase for readable asynchronous operations.
```swift
let result = try await ocrService.performOCR(on: document)
```

**Structured Concurrency:** Task groups for parallel operations.
```swift
try await withThrowingTaskGroup(of: CleanedContent.self) { group in
    for document in documents {
        group.addTask {
            try await cleaningService.cleanDocument(document, config: config)
        }
    }
}
```

### 9.3 Cancellation Support

Operations support task cancellation:
```swift
func cleanDocument(_ document: Document) async throws -> CleanedContent {
    try Task.checkCancellation()
    // ... process
}
```

---

## 10. Performance Architecture

### 10.1 Thumbnail Caching

ThumbnailCache provides performance optimization:
- **LRU Eviction:** Oldest unused thumbnails are removed first
- **Quality Tiering:** Low (80px), Medium (200px), High (500px) resolutions
- **Memory Management:** Monitors memory pressure, triggers cleanup
- **Concurrent Access:** Thread-safe through actor-based isolation

### 10.2 Text Virtualization

For large documents, VirtualizedTextView renders only visible portions:
- Reduces memory footprint
- Improves scroll performance
- Maintains smooth 60fps interaction
- Seamless pagination

### 10.3 API Optimization

- **Chunked Processing:** Large documents split into optimal-size chunks
- **Token Estimation:** Pre-process estimation prevents API failures
- **Batch Operations:** Multiple documents processed in parallel
- **Cost Prediction:** Accurate cost forecasting before processing

### 10.4 Cost Tracking

TokenEstimator provides token prediction:
```swift
let estimatedTokens = TokenEstimator.estimate(for: text)
let estimatedCost = costCalculator.calculateCost(tokens: estimatedTokens, model: "claude-3-5-sonnet")
```

---

## 11. Testing Architecture

### 11.1 Unit Tests

**Core Model Tests:** Verify model initialization, computed properties, and encoding/decoding.
```
Tests/Models/DocumentTests.swift
Tests/Models/OCRResultTests.swift
Tests/Models/ProcessingSessionTests.swift
```

**Defense Layer Tests:** Validate validation logic across all phases.
```
Tests/Validation/BoundaryValidationTests.swift
Tests/Validation/ContentVerificationTests.swift
Tests/Validation/HeuristicDetectionTests.swift
```

**Pipeline Service Tests:** Test individual pipeline stages.
```
Tests/Pipeline/ReconnaissanceServiceTests.swift
Tests/Pipeline/BoundaryDetectionTests.swift
Tests/Pipeline/ReflowServiceTests.swift
```

### 11.2 Mock Services

All protocol-based services have mock implementations for testing:

```swift
class MockClaudeService: ClaudeServiceProtocol {
    var responses: [String] = []
    var callCount = 0

    func sendPrompt(_ prompt: String) async throws -> String {
        callCount += 1
        return responses[callCount - 1]
    }
}
```

### 11.3 Integration Tests

End-to-end tests verify complete workflows:
- Document import through export
- Multi-document batch processing
- Error recovery scenarios
- Cost calculation accuracy

### 11.4 Corpus Comparison Tests

Specialized tests compare processing output against reference corpora:
- Validates cleaning quality metrics
- Verifies pattern detection accuracy
- Ensures consistency across versions

---

## 12. API Integration

### 12.1 Claude API Integration

ClaudeService implements message-based API:
- Streaming response support for long content
- Token counting for cost estimation
- Message history management
- Configurable model selection (Claude 3.5 Sonnet, etc.)

### 12.2 Mistral Vision API

OCRService integrates Mistral's vision capabilities:
- Page-level image processing
- Configurable quality parameters
- Language-specific optimization
- Cost-effective large-scale processing

### 12.3 API Error Handling

Robust error handling for API failures:
- Rate limiting with backoff
- Network error recovery
- Malformed response handling
- Timeout management

---

## 13. Security & Privacy

### 13.1 Credential Management

API keys are securely stored in macOS Keychain:
- Uses SecItem APIs
- Encrypted at rest by OS
- No credentials in configuration files
- Safe for cloud sync (Keychain synchronization)

### 13.2 OSLog Privacy

Logging respects user privacy:
```swift
os_log("Processing document %{private}@", document.id.uuidString)
```
- Sensitive data automatically redacted
- Can be explicitly marked as not private when safe
- Log collection respects privacy settings

### 13.3 Network Security

- HTTPS enforced for all API communication
- Certificate validation enabled
- No credentials in URL parameters
- Request/response encryption

---

## 13. Notification Architecture

### Notification Names and Patterns

Horus uses standard NotificationCenter for decoupled communication:

**Core Notifications:**
- `Notification.Name("openFilePicker")` - User requests file selection dialog
- `Notification.Name("processAll")` - Begin processing all queued documents
- `Notification.Name("cancelProcessing")` - Cancel active processing operations
- `Notification.Name("documentProcessed")` - Individual document processing completed
- `Notification.Name("processingComplete")` - All batch processing complete

**Integration with AppState:**
- Notifications dispatch from UI views
- AppState listens and coordinates service responses
- Ensures decoupling between presentation and business logic

---

## 14. UI Extensions and Design Constants

### DesignConstants and View Extensions

**View Extensions** (via DesignConstants):
- `fileListBackground()` - Standard background for document lists
- `contentBackground()` - Background for content areas
- `standardHorizontalPadding()` - Consistent horizontal spacing
- `sectionSpacing()` - Space between logical sections

**Color and Typography Management:**
- Centralized color definitions for consistent theming
- Standard font sizes and weights
- Accessibility-friendly contrast ratios

### AccessibilityLabels Enum

**Centralized VoiceOver Labels:**
- `documentList` - Document listing area
- `documentRow` - Individual document row
- `processingStatus` - Status indicators
- `progressIndicator` - Progress bars
- `exportButton` - Export action buttons
- `settingsPanel` - Settings interface

**Benefits:**
- Single source of truth for accessibility labels
- Consistent voice-over experience across application
- Easy to update all labels simultaneously

---

## 15. Focus Management

### FocusManager Class

**FocusElement Enum** defines keyboard navigation focus points:
- `sidebar` - Document list sidebar
- `documentList` - Main document list
- `documentRow` - Individual document selection
- `contentArea` - Main content viewing area
- `inspector` - Detail inspector panel
- `toolbar` - Top toolbar actions

**Focus Navigation Features:**
- Tab order management
- Keyboard shortcut routing
- Focus restoration after operations
- Accessibility compliance

---

## 16. Extensibility Points

### 14.1 Adding New Cleaning Stages

New pipeline stages are added by:
1. Creating new service conforming to stage protocol
2. Registering in EvolvedCleaningPipeline
3. Updating AccumulatedContext schema
4. Adding tests for new stage

### 14.2 Custom Validators

New validators extend the Phase A/B/C system:
1. Implement validation logic
2. Return detailed failure reasons
3. Integrate with recovery system
4. Add to defense layer

### 14.3 Export Format Support

New export formats are supported by:
1. Adding case to ExportFormat enum
2. Implementing ExportServiceProtocol method
3. Testing format output
4. Documenting format-specific options

### 14.4 OCR Provider Support

Additional OCR providers can be added:
1. Implement OCRServiceProtocol
2. Handle provider-specific response formats
3. Normalize results to OCRResult
4. Update service factory

---

## 15. Deployment & Versioning

### 15.1 Build Configuration

- Minimum deployment target: macOS 12.0
- Optimization level: `-Osize` for balanced performance/size
- Strict concurrency: Enabled
- Code signing: Required for App Store distribution

### 15.2 Version Management

Semantic versioning with three components:
- Major: Significant architectural changes
- Minor: New features and capabilities
- Patch: Bug fixes and optimizations

### 15.3 Configuration Management

Feature flags enable gradual rollouts:
- `useEvolvedPipeline`: Enable V3 processing
- `enableBetaFeatures`: Experimental capabilities
- Per-document overrides via CleaningConfiguration

---

## 16. Monitoring & Observability

### 16.1 Telemetry Collection

PipelineTelemetryService tracks:
- Phase execution duration
- API cost per document
- Error rates and types
- Validation checkpoint results

### 16.2 Confidence Metrics

ConfidenceTracker maintains:
- Per-element confidence scores
- Cumulative pipeline confidence
- Threshold compliance tracking
- Quality assurance indicators

### 16.3 Performance Monitoring

- API response times
- Thumbnail cache hit rates
- Memory usage patterns
- Document processing throughput

---

## 17. Known Limitations & Future Enhancements

### 17.1 Current Limitations

- Single-language document processing (multi-language support planned)
- Streaming API responses not yet fully optimized
- Limited custom metadata support
- No built-in document collaboration features

### 17.2 Planned Enhancements

- Multi-threaded PDF processing for faster page extraction
- Cloud-based document storage integration
- Real-time collaborative editing
- Advanced format-specific export options
- Machine learning model fine-tuning capabilities

---

## 18. Conclusion

Horus represents a sophisticated document processing system built on Swift 6.0 with careful attention to safety, performance, and maintainability. The architecture emphasizes:

1. **Layered Design:** Clear separation of concerns enables independent evolution of each layer
2. **Protocol-Driven:** Dependency injection and abstraction enable testing and extensibility
3. **Concurrency Safety:** Swift 6.0's strict checking eliminates entire classes of bugs
4. **Validation Defense:** Three-layer validation system ensures document integrity
5. **Performance:** Careful optimization maintains responsive interaction even with large documents
6. **Observability:** Comprehensive telemetry enables monitoring and improvement

The codebase is production-ready, extensively tested, and designed for long-term maintenance and evolution.

---

## Appendix A: Protocol Reference

All major service protocols are listed in section 5.1 with complete signatures and usage patterns.

## Appendix B: Configuration Reference

CleaningConfiguration presets:
- **Strict:** Highest quality, slowest processing
- **Balanced:** Optimal quality/speed tradeoff
- **Permissive:** Fastest processing, may miss details
- **Custom:** User-defined parameters

## Appendix C: Error Recovery

Error recovery hierarchy:
1. Automatic retry with backoff (network errors)
2. Phase rollback with snapshot restoration (processing errors)
3. Document-level recovery (user action required)
4. Manual intervention (critical failures)

---

**Document Author:** System Documentation
**Review Status:** Current Production Architecture
**Last Technical Review:** February 2026
