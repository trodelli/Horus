# Technical Architecture Document
## Horus — Document Processing for AI Training Data

> **Document Version:** 2.0  
> **Last Updated:** January 2026  
> **Status:** Active Development  
> **Prerequisite:** PRD v2.0

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Technology Stack](#2-technology-stack)
3. [Application Structure](#3-application-structure)
4. [Data Models](#4-data-models)
5. [Service Layer](#5-service-layer)
6. [Multi-Layer Defense Architecture](#6-multi-layer-defense-architecture)
7. [State Management](#7-state-management)
8. [API Integration](#8-api-integration)
9. [Security Architecture](#9-security-architecture)
10. [Error Handling Architecture](#10-error-handling-architecture)
11. [Performance Considerations](#11-performance-considerations)
12. [Testing Strategy](#12-testing-strategy)

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

Horus follows the **Model-View-ViewModel (MVVM)** pattern with a sophisticated service layer that includes AI integration, validation layers, and defensive processing.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              HORUS APPLICATION                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         PRESENTATION LAYER                           │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────┐   │   │
│  │  │   MainWindow  │  │   Settings    │  │     Onboarding        │   │   │
│  │  │     View      │  │     View      │  │        View           │   │   │
│  │  └───────┬───────┘  └───────┬───────┘  └───────────┬───────────┘   │   │
│  │          │                  │                      │               │   │
│  │  ┌───────┴──────────────────┴──────────────────────┴───────────┐   │   │
│  │  │                      VIEW MODELS                             │   │   │
│  │  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │   │   │
│  │  │  │ DocumentQueue│ │   Cleaning   │ │       Export         │ │   │   │
│  │  │  │  ViewModel   │ │  ViewModel   │ │      ViewModel       │ │   │   │
│  │  │  └──────────────┘ └──────────────┘ └──────────────────────┘ │   │   │
│  │  └──────────────────────────┬──────────────────────────────────┘   │   │
│  └─────────────────────────────┼───────────────────────────────────────┘   │
│                                │                                           │
│  ┌─────────────────────────────┼───────────────────────────────────────┐   │
│  │                      SERVICE LAYER                                   │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐ │   │
│  │  │   OCR        │ │   Claude     │ │   Cleaning   │ │  Pattern   │ │   │
│  │  │   Service    │ │   Service    │ │   Service    │ │  Detection │ │   │
│  │  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬─────┘ │   │
│  │         │                │                │                │       │   │
│  │  ┌──────┴────────────────┴────────────────┴────────────────┴────┐  │   │
│  │  │                     VALIDATION LAYER                          │  │   │
│  │  │  ┌────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │  │   │
│  │  │  │   Boundary     │ │    Content      │ │    Heuristic    │  │  │   │
│  │  │  │   Validator    │ │    Verifier     │ │    Detector     │  │  │   │
│  │  │  │   (Phase A)    │ │    (Phase B)    │ │    (Phase C)    │  │  │   │
│  │  │  └────────────────┘ └─────────────────┘ └─────────────────┘  │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  │                                                                     │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐ │   │
│  │  │   Document   │ │   Export     │ │   Text       │ │  Keychain  │ │   │
│  │  │   Service    │ │   Service    │ │   Processing │ │  Service   │ │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └────────────┘ │   │
│  │                                                                     │   │
│  │  ┌──────────────┐                                                   │   │
│  │  │   Network    │                                                   │   │
│  │  │   Client     │                                                   │   │
│  │  └──────────────┘                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         DATA LAYER                                   │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────────┐ │   │
│  │  │   Document   │ │  OCRResult   │ │      CleaningModels          │ │   │
│  │  │    Model     │ │    Model     │ │  (Configuration, Progress,   │ │   │
│  │  │              │ │              │ │   Patterns, Metadata, etc.)  │ │   │
│  │  └──────────────┘ └──────────────┘ └──────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │       EXTERNAL SERVICES        │
                    │  ┌──────────────────────────┐  │
                    │  │    Mistral OCR API       │  │
                    │  │  api.mistral.ai/v1/ocr   │  │
                    │  └──────────────────────────┘  │
                    │  ┌──────────────────────────┐  │
                    │  │    Claude API            │  │
                    │  │  api.anthropic.com       │  │
                    │  └──────────────────────────┘  │
                    │  ┌──────────────────────────┐  │
                    │  │    macOS Keychain        │  │
                    │  └──────────────────────────┘  │
                    │  ┌──────────────────────────┐  │
                    │  │    File System           │  │
                    │  └──────────────────────────┘  │
                    └────────────────────────────────┘
```

### 1.2 Layer Responsibilities

| Layer | Responsibility | Key Principle |
|:------|:---------------|:--------------|
| **Presentation** | UI rendering, user input handling | Declarative, reactive to state changes |
| **ViewModel** | UI state management, business logic coordination | Observable, testable without UI |
| **Service** | Domain operations, AI integration, external APIs | Protocol-based, injectable, async |
| **Validation** | AI response validation, content verification | Defensive, fail-safe, logged |
| **Data** | Data structures, transformations | Immutable where possible, Codable, Sendable |

### 1.3 Data Flow

```
User Action → View → ViewModel → Service → AI/External System
                ↑                    │
                │              Validation Layer
                │                    │
                └────── State ←──────┘
```

### 1.4 Cleaning Pipeline Flow

The 14-step cleaning pipeline represents the core processing engine:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CLEANING PIPELINE FLOW                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  OCR Content ──┬── Phase 1: Extraction ─── Step 1: Extract Metadata    │
│                │                                                        │
│                ├── Phase 2: Structural ─┬─ Step 2: Remove Front Matter │
│                │                        ├─ Step 3: Remove TOC          │
│                │                        ├─ Step 4: Remove Aux Lists    │
│                │                        ├─ Step 5: Remove Page Numbers │
│                │                        └─ Step 6: Remove Headers      │
│                │                                                        │
│                ├── Phase 3: Content ────┬─ Step 7: Remove Citations    │
│                │                        ├─ Step 8: Remove Footnotes    │
│                │                        ├─ Step 9: Reflow Paragraphs   │
│                │                        └─ Step 10: Clean Characters   │
│                │                                                        │
│                ├── Phase 4: Back Matter ┬─ Step 11: Remove Index       │
│                │                        └─ Step 12: Remove Back Matter │
│                │                                                        │
│                └── Phase 5: Assembly ───┬─ Step 13: Optimize Paragraphs│
│                                         └─ Step 14: Add Structure      │
│                                                        │                │
│                                                        ▼                │
│                                                 Cleaned Content         │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Each boundary detection step uses Multi-Layer Defense:         │   │
│  │  Claude AI Detection → Phase A Validation → Phase B Verification │   │
│  │                     → Phase C Heuristic Fallback                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Technology Stack

### 2.1 Core Technologies

| Component | Technology | Version | Rationale |
|:----------|:-----------|:--------|:----------|
| **Language** | Swift | 6.0 | Latest stable; complete concurrency checking |
| **UI Framework** | SwiftUI | macOS 14+ | Native declarative UI; excellent reactive patterns |
| **Concurrency** | Swift Concurrency | async/await | Clean asynchronous code; built-in cancellation |
| **Networking** | URLSession | Native | No external dependencies; full async/await support |
| **Security** | Keychain Services | Native | macOS-standard secure credential storage |
| **Persistence** | UserDefaults | Native | Appropriate for preferences; no database needed |
| **Logging** | OSLog | Native | Structured logging with privacy controls |

### 2.2 External API Dependencies

| Service | Purpose | Endpoint |
|:--------|:--------|:---------|
| **Mistral AI** | OCR text extraction | api.mistral.ai/v1/chat/completions |
| **Anthropic Claude** | Intelligent boundary detection, pattern analysis | api.anthropic.com/v1/messages |

### 2.3 Why These Choices?

**Dual AI Integration**
- Mistral provides state-of-the-art OCR with excellent document structure preservation
- Claude provides intelligent boundary detection and content analysis that pattern matching cannot achieve
- Separation allows best-in-class capability for each function

**No External Swift Dependencies**
- Reduces maintenance burden and supply chain risk
- Native frameworks are sufficient for all requirements
- Simpler distribution without SPM/CocoaPods complexity

**Multi-Layer Validation**
- AI is powerful but imperfect—responses must be validated
- Defense in depth prevents catastrophic failures
- Heuristic fallbacks ensure operations complete even when AI fails

### 2.4 macOS Framework Usage

| Framework | Purpose |
|:----------|:--------|
| **Foundation** | Data types, file management, networking |
| **SwiftUI** | User interface |
| **UniformTypeIdentifiers** | File type handling |
| **Security** | Keychain access |
| **PDFKit** | PDF page counting, thumbnail generation |
| **OSLog** | Structured logging |

---

## 3. Application Structure

### 3.1 Project Organization

```
Horus/
├── App/
│   ├── HorusApp.swift                 # App entry point, scene configuration
│   └── AppState.swift                 # Global application state
│
├── Features/
│   ├── Cleaning/
│   │   ├── Views/
│   │   │   ├── CleanTabView.swift
│   │   │   ├── CleaningInspectorView.swift
│   │   │   ├── UnifiedCleaningInspector.swift
│   │   │   └── VirtualizedTextView.swift
│   │   └── ViewModels/
│   │       └── CleaningViewModel.swift
│   │
│   ├── DocumentQueue/
│   │   └── ViewModels/
│   │       └── DocumentQueueViewModel.swift
│   │
│   ├── Export/
│   │   ├── Views/
│   │   │   ├── ExportSheetView.swift
│   │   │   └── BatchExportSheetView.swift
│   │   └── ViewModels/
│   │       └── ExportViewModel.swift
│   │
│   ├── Library/
│   │   └── Views/
│   │       └── LibraryView.swift
│   │
│   ├── MainWindow/
│   │   └── Views/
│   │       ├── MainWindowView.swift
│   │       ├── NavigationSidebarView.swift
│   │       ├── ContentAreaView.swift
│   │       └── InspectorView.swift
│   │
│   ├── OCR/
│   │   └── Views/
│   │       └── OCRTabView.swift
│   │
│   ├── Onboarding/
│   │   └── Views/
│   │       ├── OnboardingView.swift
│   │       └── OnboardingWizardView.swift
│   │
│   ├── Processing/
│   │   └── ViewModels/
│   │       └── ProcessingViewModel.swift
│   │
│   ├── Queue/
│   │   └── Views/
│   │       └── InputView.swift
│   │
│   └── Settings/
│       └── Views/
│           ├── SettingsView.swift
│           └── CleaningSettingsView.swift
│
├── Core/
│   ├── Errors/
│   │   ├── HorusError.swift           # Top-level error types
│   │   └── CleaningError.swift        # Cleaning-specific errors
│   │
│   ├── Models/
│   │   ├── Document.swift             # Document model
│   │   ├── DocumentStatus.swift       # Processing status enum
│   │   ├── DocumentWorkflowStage.swift
│   │   ├── OCRResult.swift            # OCR output model
│   │   ├── ProcessingSession.swift    # Session state
│   │   ├── ExportFormat.swift         # Export configuration
│   │   ├── UserPreferences.swift      # User settings
│   │   │
│   │   ├── APIModels/
│   │   │   ├── OCRAPIModels.swift     # Mistral API models
│   │   │   └── ClaudeAPIModels.swift  # Claude API models
│   │   │
│   │   └── CleaningModels/
│   │       ├── CleaningStep.swift     # 14-step pipeline definition
│   │       ├── CleaningConfiguration.swift
│   │       ├── CleaningProgress.swift
│   │       ├── CleanedContent.swift
│   │       ├── PresetType.swift       # Preset configurations
│   │       ├── DetectedPatterns.swift # Pattern detection results
│   │       ├── DocumentMetadata.swift
│   │       ├── ContentTypeFlags.swift # Content classification
│   │       ├── CitationTypes.swift
│   │       ├── FootnoteTypes.swift
│   │       ├── AuxiliaryListTypes.swift
│   │       ├── ChapterMarkerStyle.swift
│   │       └── EndMarkerStyle.swift
│   │
│   ├── Services/
│   │   ├── OCRService.swift           # Mistral API integration
│   │   ├── ClaudeService.swift        # Claude API integration
│   │   ├── CleaningService.swift      # Pipeline orchestration
│   │   ├── PatternDetectionService.swift
│   │   ├── TextProcessingService.swift
│   │   ├── DocumentService.swift
│   │   ├── ExportService.swift
│   │   ├── KeychainService.swift
│   │   ├── NetworkClient.swift
│   │   ├── CostCalculator.swift
│   │   ├── ThumbnailCache.swift
│   │   ├── APIKeyValidator.swift
│   │   └── MockClaudeService.swift    # Testing support
│   │
│   └── Utilities/
│       ├── DesignConstants.swift      # Single source of truth for design
│       ├── BoundaryValidation.swift   # Phase A validation
│       ├── ContentVerification.swift  # Phase B verification
│       ├── HeuristicBoundaryDetection.swift  # Phase C fallback
│       └── Extensions/
│           ├── Accessibility.swift
│           └── Notifications.swift
│
├── Shared/
│   └── Components/
│       ├── InspectorComponents.swift  # Reusable inspector UI
│       ├── TabHeaderView.swift        # Consistent tab headers
│       ├── TabFooterView.swift        # Consistent tab footers
│       ├── ContentHeaderView.swift
│       ├── DocumentListRow.swift
│       └── PipelineStatusIcons.swift
│
└── Resources/
    └── Assets.xcassets/
```

### 3.2 Feature Module Pattern

Each feature follows a consistent MVVM structure:

```
Feature/
├── Views/           # SwiftUI views (UI only)
└── ViewModels/      # Observable state + business logic coordination
```

**Views:**
- Pure UI rendering
- Receive data from ViewModel via `@ObservedObject` or `@StateObject`
- Send user actions to ViewModel via method calls
- No direct service access

**ViewModels:**
- Marked with `@Observable` and `@MainActor` for thread safety
- Hold UI state
- Coordinate service calls
- Transform data for display
- Injectable dependencies for testing

---

## 4. Data Models

### 4.1 Core Document Models

#### Document

```swift
/// Represents a document imported for processing.
struct Document: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceURL: URL
    let contentType: UTType
    let fileSize: Int64
    var estimatedPageCount: Int?
    var status: DocumentStatus
    let importedAt: Date
    var ocrResult: OCRResult?
    var cleanedContent: CleanedContent?
    var workflowStage: DocumentWorkflowStage
    var error: DocumentError?
}

/// Processing status for a document
enum DocumentStatus: Equatable, Sendable {
    case pending
    case validating
    case processing(progress: ProcessingProgress)
    case completed
    case failed
    case cancelled
}

/// Workflow stage tracking
enum DocumentWorkflowStage: Equatable, Sendable {
    case queued
    case ocrProcessing
    case ocrComplete
    case cleaning
    case cleaned
    case exported
}
```

### 4.2 Cleaning Pipeline Models

#### CleaningStep

The 14-step pipeline is defined as an enum with rich metadata:

```swift
/// A single step in the cleaning pipeline.
enum CleaningStep: Int, CaseIterable, Identifiable, Codable, Sendable {
    // Phase 1: Extraction & Analysis
    case extractMetadata = 1
    
    // Phase 2: Structural Removal
    case removeFrontMatter = 2
    case removeTableOfContents = 3
    case removeAuxiliaryLists = 4
    case removePageNumbers = 5
    case removeHeadersFooters = 6
    
    // Phase 3: Content Cleaning
    case removeCitations = 7
    case removeFootnotesEndnotes = 8
    case reflowParagraphs = 9
    case cleanSpecialCharacters = 10
    
    // Phase 4: Back Matter Removal
    case removeIndex = 11
    case removeBackMatter = 12
    
    // Phase 5: Optimization & Assembly
    case optimizeParagraphLength = 13
    case addStructure = 14
    
    /// Processing method for this step
    var processingMethod: ProcessingMethod {
        switch self {
        case .extractMetadata: return .claudeOnly
        case .cleanSpecialCharacters, .addStructure: return .codeOnly
        case .reflowParagraphs, .optimizeParagraphLength: return .claudeChunked
        default: return .hybrid  // Claude detects, code removes
        }
    }
}

/// How a cleaning step is processed
enum ProcessingMethod: String, Codable, Sendable {
    case claudeOnly      // Processed entirely by Claude
    case hybrid          // Claude detects patterns/boundaries, code applies them
    case claudeChunked   // Claude processes in chunks (large documents)
    case codeOnly        // Processed entirely by code (regex, templates)
}
```

#### CleaningConfiguration

```swift
/// Configuration for the cleaning pipeline.
struct CleaningConfiguration: Codable, Equatable, Sendable {
    var basePreset: PresetType?
    
    // Phase 1
    var extractMetadata: Bool = true
    
    // Phase 2
    var removeFrontMatter: Bool = true
    var removeTableOfContents: Bool = true
    var removeAuxiliaryLists: Bool = false  // Toggleable
    var removePageNumbers: Bool = true
    var removeHeadersFooters: Bool = true
    
    // Phase 3
    var removeCitations: Bool = false       // Toggleable
    var removeFootnotesEndnotes: Bool = false  // Toggleable
    var reflowParagraphs: Bool = true
    var cleanSpecialCharacters: Bool = true
    
    // Phase 4
    var removeIndex: Bool = true
    var removeBackMatter: Bool = false
    
    // Phase 5
    var optimizeParagraphLength: Bool = true
    var addStructure: Bool = true
    
    // Parameters
    var maxParagraphWords: Int = 250
    var metadataFormat: MetadataFormat = .yaml
    var chapterMarkerStyle: ChapterMarkerStyle = .htmlComments
    var endMarkerStyle: EndMarkerStyle = .standard
    
    /// Returns list of enabled steps in execution order
    var enabledSteps: [CleaningStep] { /* ... */ }
}
```

#### PresetType

```swift
/// Available cleaning presets with optimized configurations.
enum PresetType: String, Codable, CaseIterable, Sendable {
    case `default`   // Balanced cleaning for most documents
    case training    // Aggressive cleaning for LLM training data
    case minimal     // Light touch, preserve structure
    case scholarly   // Academic documents optimized for training
    
    // Each preset defines defaults for toggleable steps,
    // parameters, and marker styles
}
```

### 4.3 Pattern Detection Models

#### DetectedPatterns

```swift
/// Comprehensive pattern detection results from document analysis.
struct DetectedPatterns: Codable, Sendable {
    // Structure detection
    var hasFrontMatter: Bool
    var frontMatterEndLine: Int?
    var hasTableOfContents: Bool
    var tocStartLine: Int?
    var tocEndLine: Int?
    var hasIndex: Bool
    var indexStartLine: Int?
    var hasBackMatter: Bool
    var backMatterStartLine: Int?
    
    // V2: Auxiliary lists
    var auxiliaryLists: [AuxiliaryListInfo]
    
    // V2: Content type classification
    var contentTypeFlags: ContentTypeFlags?
    
    // V2: Citation detection
    var citationInfo: CitationDetectionResult?
    
    // V2: Footnote detection
    var footnoteInfo: FootnoteDetectionResult?
    
    // V2: Chapter structure
    var chapterInfo: ChapterDetectionResult?
    
    // Formatting patterns
    var pageNumberPatterns: [String]
    var headerPatterns: [String]
    var footerPatterns: [String]
}
```

#### ContentTypeFlags

```swift
/// Content type classification for adaptive processing.
struct ContentTypeFlags: Codable, Sendable {
    var primaryType: ContentType
    var confidence: Double
    
    var isPoetry: Bool
    var isDialogue: Bool
    var hasCodeBlocks: Bool
    var isAcademic: Bool
    var isLegal: Bool
    var isChildrens: Bool
    var hasTabularData: Bool
    var hasMathContent: Bool
}

enum ContentType: String, Codable, Sendable {
    case prose
    case poetry
    case drama
    case academic
    case legal
    case technical
    case mixed
}
```

---

## 5. Service Layer

### 5.1 Service Protocols

All services are defined as protocols to enable testing and dependency injection:

```swift
/// Protocol for OCR processing operations (Mistral)
protocol OCRServiceProtocol: Sendable {
    func processDocument(_ document: Document, ...) async throws -> OCRResult
    func validateAPIKey() async throws -> Bool
}

/// Protocol for Claude API interactions
protocol ClaudeServiceProtocol: Sendable {
    func sendMessage(_ prompt: String, system: String?, maxTokens: Int) async throws -> ClaudeAPIResponse
    func identifyBoundaries(content: String, sectionType: SectionType) async throws -> BoundaryInfo
    func analyzeDocumentComprehensive(content: String, ...) async throws -> DetectedPatterns
    func extractMetadataWithContentType(frontMatter: String, sampleContent: String) async throws -> (DocumentMetadata, ContentTypeFlags)
    func detectCitationPatterns(sampleContent: String) async throws -> CitationDetectionResult
    func detectFootnotePatterns(sampleContent: String) async throws -> FootnoteDetectionResult
    func validateAPIKey() async throws -> Bool
}

/// Protocol for the document cleaning pipeline
protocol CleaningServiceProtocol: Sendable {
    func cleanDocument(
        _ document: Document,
        configuration: CleaningConfiguration,
        onStepStarted: @escaping (CleaningStep) -> Void,
        onStepCompleted: @escaping (CleaningStep, CleaningStepStatus) -> Void,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> CleanedContent
    func cancelCleaning()
    var isProcessing: Bool { get }
}

/// Protocol for pattern detection operations
protocol PatternDetectionServiceProtocol: Sendable {
    func detectAllPatterns(in content: String, configuration: CleaningConfiguration) async throws -> DetectedPatterns
    func detectPageNumberPatterns(in content: String) -> [String]
    func detectHeaderFooterPatterns(in content: String) -> (headers: [String], footers: [String])
}

/// Protocol for text processing operations
protocol TextProcessingServiceProtocol: Sendable {
    func removePatternMatches(from content: String, patterns: [String]) -> String
    func removeLineRange(from content: String, startLine: Int, endLine: Int) -> String
    func cleanOCRArtifacts(in content: String, preserveCodeBlocks: Bool, preserveMath: Bool) -> String
    func normalizeQuotations(in content: String) -> String
}
```

### 5.2 CleaningService Architecture

The CleaningService orchestrates the 14-step pipeline with multi-layer defense:

```swift
@MainActor
final class CleaningService: CleaningServiceProtocol {
    
    // Dependencies
    private let claudeService: ClaudeServiceProtocol
    private let patternService: PatternDetectionServiceProtocol
    private let textService: TextProcessingServiceProtocol
    private let boundaryValidator: BoundaryValidator    // Phase A
    private let contentVerifier: ContentVerifier        // Phase B
    private let heuristicDetector: HeuristicBoundaryDetector  // Phase C
    
    func cleanDocument(
        _ document: Document,
        configuration: CleaningConfiguration,
        /* callbacks */
    ) async throws -> CleanedContent {
        
        var currentContent = document.ocrResult?.fullText ?? ""
        var stepResults: [CleaningStep: StepResult] = [:]
        
        for step in configuration.enabledSteps {
            onStepStarted(step)
            
            do {
                let result = try await executeStep(
                    step,
                    content: currentContent,
                    configuration: configuration,
                    patterns: detectedPatterns
                )
                
                currentContent = result.content
                stepResults[step] = result
                onStepCompleted(step, .completed(wordCount: result.wordCount, changeCount: result.changeCount))
                
            } catch {
                onStepCompleted(step, .failed(message: error.localizedDescription))
                throw error
            }
        }
        
        return CleanedContent(/* ... */)
    }
    
    // Each boundary detection step follows this pattern:
    private func executeRemoveBackMatter(
        content: String,
        configuration: CleaningConfiguration
    ) async throws -> StepResult {
        
        // 1. Claude AI Detection
        let boundary = try await claudeService.identifyBoundaries(
            content: content,
            sectionType: .backMatter
        )
        
        // 2. Phase A: Response Validation
        let validationResult = boundaryValidator.validate(
            boundary: boundary,
            sectionType: .backMatter,
            documentLineCount: content.lineCount
        )
        
        guard validationResult.isValid else {
            logger.warning("Phase A rejected: \(validationResult.explanation)")
            // Fall through to Phase C
            return try executeHeuristicFallback(content: content, sectionType: .backMatter)
        }
        
        // 3. Phase B: Content Verification
        let verificationResult = contentVerifier.verifyBackMatter(
            content: content,
            startLine: boundary.startLine!
        )
        
        guard verificationResult.isValid else {
            logger.warning("Phase B rejected: \(verificationResult.explanation)")
            return try executeHeuristicFallback(content: content, sectionType: .backMatter)
        }
        
        // 4. Apply removal (all validations passed)
        let cleaned = textService.removeLineRange(
            from: content,
            startLine: boundary.startLine!,
            endLine: boundary.endLine ?? content.lineCount - 1
        )
        
        return StepResult(content: cleaned, /* ... */)
    }
}
```

---

## 6. Multi-Layer Defense Architecture

The multi-layer defense architecture protects against catastrophic content loss from AI hallucinations. This architecture was developed after a critical incident where Claude incorrectly identified line 4 as the start of back matter, which would have deleted 99% of the document.

### 6.1 Defense Layer Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    MULTI-LAYER DEFENSE ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Claude AI Detection                                                    │
│         │                                                               │
│         ▼                                                               │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  PHASE A: RESPONSE VALIDATION (BoundaryValidator)                 │  │
│  │  ────────────────────────────────────────────────────────────────│  │
│  │  • Position constraints (back matter must be after 50%)           │  │
│  │  • Size constraints (max removal percentages per section)         │  │
│  │  • Confidence thresholds (reject low-confidence detections)       │  │
│  │  • Bounds checking (lines within document range)                  │  │
│  └─────────────────────────────┬────────────────────────────────────┘  │
│                                │                                        │
│                     Pass?  ────┼──── No ───▶ Phase C Fallback          │
│                                │                                        │
│                               Yes                                       │
│                                ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  PHASE B: CONTENT VERIFICATION (ContentVerifier)                  │  │
│  │  ────────────────────────────────────────────────────────────────│  │
│  │  • Verify section contains expected patterns:                     │  │
│  │    - Back matter: NOTES, APPENDIX, BIBLIOGRAPHY, GLOSSARY, etc.  │  │
│  │    - Index: INDEX header, alphabetized entries, page numbers     │  │
│  │    - Front matter: ©, ISBN, LOC, publisher patterns              │  │
│  │    - TOC: CONTENTS header, chapter/page listings                 │  │
│  └─────────────────────────────┬────────────────────────────────────┘  │
│                                │                                        │
│                     Pass?  ────┼──── No ───▶ Phase C Fallback          │
│                                │                                        │
│                               Yes                                       │
│                                ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  APPLY REMOVAL (Safe to proceed)                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  PHASE C: HEURISTIC FALLBACK (HeuristicBoundaryDetector)         │  │
│  │  ────────────────────────────────────────────────────────────────│  │
│  │  • Pattern-based detection (regex, keyword matching)              │  │
│  │  • Conservative boundaries (better to preserve than destroy)      │  │
│  │  • AI-independent (works when Claude fails or is rejected)        │  │
│  │  • Logged for analysis and improvement                            │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Phase A: Response Validation

The BoundaryValidator enforces position and size constraints:

```swift
/// Configuration constants for boundary validation
enum BoundaryValidationConstraints {
    // Position constraints (as percentage of document)
    static let frontMatterMaxEndPercent: Double = 0.40
    static let tocMaxEndPercent: Double = 0.35
    static let indexMinStartPercent: Double = 0.60
    static let backMatterMinStartPercent: Double = 0.50  // CRITICAL
    
    // Maximum removal constraints
    static let frontMatterMaxRemovalPercent: Double = 0.40
    static let tocMaxRemovalPercent: Double = 0.20
    static let indexMaxRemovalPercent: Double = 0.25
    static let backMatterMaxRemovalPercent: Double = 0.45
    
    // Confidence thresholds
    static let frontMatterMinConfidence: Double = 0.60
    static let backMatterMinConfidence: Double = 0.70  // Higher for high-risk
}
```

### 6.3 Phase B: Content Verification

The ContentVerifier confirms detected sections contain expected patterns:

```swift
/// Verify back matter section contains expected content
func verifyBackMatter(content: String, startLine: Int) -> ContentVerificationResult {
    let sectionContent = extractSection(content, from: startLine)
    
    // Check for expected back matter indicators
    let indicators = [
        "NOTES", "ENDNOTES", "APPENDIX", "BIBLIOGRAPHY",
        "GLOSSARY", "ABOUT THE AUTHOR", "ACKNOWLEDGMENT",
        "REFERENCES", "WORKS CITED", "INDEX"
    ]
    
    let foundIndicators = indicators.filter { indicator in
        sectionContent.localizedCaseInsensitiveContains(indicator)
    }
    
    if foundIndicators.isEmpty {
        return .invalid(
            reason: .missingExpectedPatterns,
            explanation: "Back matter section contains no expected indicators"
        )
    }
    
    return .valid(confidence: Double(foundIndicators.count) / 3.0)
}
```

### 6.4 Phase C: Heuristic Fallback

When AI detection fails or is rejected, pattern-based detection provides conservative boundaries:

```swift
/// Detect back matter using heuristic patterns (AI-independent)
func detectBackMatterHeuristic(content: String) -> BoundaryInfo? {
    let lines = content.components(separatedBy: .newlines)
    let totalLines = lines.count
    
    // Only search in last 40% of document
    let searchStartIndex = Int(Double(totalLines) * 0.60)
    
    let backMatterHeaders = [
        "^#+\\s*(NOTES|ENDNOTES)\\s*$",
        "^#+\\s*APPENDIX",
        "^#+\\s*BIBLIOGRAPHY",
        "^#+\\s*GLOSSARY",
        "^ABOUT THE AUTHOR",
    ]
    
    for (index, line) in lines[searchStartIndex...].enumerated() {
        for pattern in backMatterHeaders {
            if line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return BoundaryInfo(
                    startLine: searchStartIndex + index,
                    endLine: totalLines - 1,
                    confidence: 0.75,
                    notes: "Heuristic detection: matched '\(pattern)'"
                )
            }
        }
    }
    
    return nil  // No back matter detected
}
```

---

## 7. State Management

### 7.1 App State

```swift
/// Global application state, injected into the environment
@Observable
@MainActor
final class AppState {
    
    // Services
    let keychainService: KeychainServiceProtocol
    let ocrService: OCRServiceProtocol
    let claudeService: ClaudeServiceProtocol
    let cleaningService: CleaningServiceProtocol
    let documentService: DocumentServiceProtocol
    let exportService: ExportServiceProtocol
    
    // Session state
    var session: ProcessingSession = ProcessingSession()
    var selectedDocument: Document?
    
    // UI state
    var currentError: HorusError?
    var isShowingSettings: Bool = false
    
    // User preferences
    var preferences: UserPreferences = UserPreferences.load()
    
    // Computed
    var hasCompletedOnboarding: Bool {
        keychainService.hasMistralAPIKey && keychainService.hasClaudeAPIKey
    }
}
```

### 7.2 ViewModel Pattern

Example showing the CleaningViewModel architecture:

```swift
@Observable
@MainActor
final class CleaningViewModel {
    
    // Dependencies (injected)
    private let cleaningService: CleaningServiceProtocol
    private let session: ProcessingSession
    
    // Configuration state
    var configuration: CleaningConfiguration = .default
    var selectedPreset: PresetType = .default
    
    // Processing state
    var isProcessing: Bool = false
    var currentStep: CleaningStep?
    var stepStatuses: [CleaningStep: CleaningStepStatus] = [:]
    var progress: CleaningProgress?
    
    // Results
    var cleanedContent: CleanedContent?
    var error: CleaningError?
    
    // Actions
    func startCleaning(for document: Document) async {
        isProcessing = true
        currentStep = nil
        stepStatuses = [:]
        
        do {
            cleanedContent = try await cleaningService.cleanDocument(
                document,
                configuration: configuration,
                onStepStarted: { [weak self] step in
                    self?.currentStep = step
                    self?.stepStatuses[step] = .processing
                },
                onStepCompleted: { [weak self] step, status in
                    self?.stepStatuses[step] = status
                },
                onProgressUpdate: { [weak self] progress in
                    self?.progress = progress
                }
            )
        } catch let error as CleaningError {
            self.error = error
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        
        isProcessing = false
    }
    
    func cancelCleaning() {
        cleaningService.cancelCleaning()
    }
    
    func applyPreset(_ preset: PresetType) {
        selectedPreset = preset
        configuration = CleaningConfiguration(preset: preset)
    }
}
```

---

## 8. API Integration

### 8.1 Dual API Architecture

Horus integrates with two AI APIs, each serving a distinct purpose:

| API | Service | Purpose |
|:----|:--------|:--------|
| **Mistral AI** | OCRService | Document text extraction via vision model |
| **Anthropic Claude** | ClaudeService | Intelligent boundary detection, pattern analysis |

### 8.2 Network Client

```swift
/// Generic network client for HTTP operations
actor NetworkClient {
    static let shared = NetworkClient()
    
    func post<Body: Encodable, Response: Decodable>(
        url: URL,
        body: Body,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> Response
    
    func get<Response: Decodable>(
        url: URL,
        headers: [String: String] = [:]
    ) async throws -> Response
}
```

### 8.3 Retry and Rate Limiting

```swift
/// Handles rate limiting with exponential backoff
struct RetryPolicy {
    let maxAttempts: Int = 3
    let initialDelay: TimeInterval = 1.0
    let maxDelay: TimeInterval = 30.0
    let multiplier: Double = 2.0
    
    func execute<T>(
        operation: () async throws -> T,
        shouldRetry: (Error) -> Bool
    ) async throws -> T
}
```

---

## 9. Security Architecture

### 9.1 Security Principles

| Principle | Implementation |
|:----------|:---------------|
| **Credentials never in code** | API keys stored only in Keychain |
| **Credentials never logged** | Logger sanitizes sensitive data |
| **Secure storage** | macOS Keychain with `kSecAttrAccessibleWhenUnlocked` |
| **Encrypted transport** | HTTPS only for all API communication |
| **No document persistence** | Session-based; documents not saved to disk |

### 9.2 Dual API Key Management

```swift
/// Service for secure storage of API credentials
final class KeychainService: KeychainServiceProtocol {
    
    // Separate storage for each API
    private let mistralAccountName = "mistral-api-key"
    private let claudeAccountName = "claude-api-key"
    
    var hasMistralAPIKey: Bool
    var hasClaudeAPIKey: Bool
    
    func storeMistralAPIKey(_ key: String) throws
    func retrieveMistralAPIKey() throws -> String?
    func storeClaudeAPIKey(_ key: String) throws
    func retrieveClaudeAPIKey() throws -> String?
}
```

---

## 10. Error Handling Architecture

### 10.1 Error Hierarchy

```swift
/// Top-level error type for Horus
enum HorusError: Error, LocalizedError, Identifiable {
    case document(DocumentLoadError)
    case ocr(OCRError)
    case cleaning(CleaningError)
    case export(ExportError)
    case keychain(KeychainError)
    case network(NetworkError)
    
    var recoverySuggestion: String?
    var isRetryable: Bool
}

/// Cleaning-specific errors
enum CleaningError: Error, LocalizedError {
    case noOCRContent
    case stepFailed(step: CleaningStep, reason: String)
    case validationRejected(step: CleaningStep, reason: BoundaryRejectionReason)
    case apiError(String)
    case cancelled
    case configurationInvalid(String)
}
```

### 10.2 Error Presentation

```swift
/// User-presentable error information
struct PresentableError: Identifiable {
    let title: String
    let message: String
    let suggestion: String?
    let isRetryable: Bool
}

/// Convert any error to user-presentable format
struct ErrorPresenter {
    static func present(_ error: Error) -> PresentableError
}
```

---

## 11. Performance Considerations

### 11.1 Main Thread Protection

All ViewModels are marked `@MainActor` to ensure UI updates happen on the main thread. Heavy computation is dispatched to background:

```swift
@MainActor
final class CleaningViewModel {
    // All published properties update on main thread
    
    func startCleaning() async {
        // Service layer handles background work
        // Callbacks marshal results back to main actor
    }
}
```

### 11.2 Memory Management

| Concern | Strategy |
|:--------|:---------|
| Large documents | Process in chunks; don't load entire content into memory |
| Cleaning results | Store only final cleaned content; intermediate states discarded |
| Thumbnails | Cache with size limits; lazy generation |
| Session cleanup | Clear references when documents removed |

### 11.3 Cancellation

All long-running operations support cancellation:

```swift
/// Cleaning service supports cancellation
func cleanDocument(/* ... */) async throws -> CleanedContent {
    for step in enabledSteps {
        try Task.checkCancellation()  // Check before each step
        // ... process step
    }
}

func cancelCleaning() {
    currentTask?.cancel()
    currentTask = nil
}
```

### 11.4 Performance Targets

| Metric | Target |
|:-------|:-------|
| UI interactions | < 16ms (60fps) |
| Step transitions | < 200ms visual feedback |
| API operations | Show progress for > 500ms |
| Document preview | < 200ms render |

---

## 12. Testing Strategy

### 12.1 Test Organization

```
HorusTests/
├── Models/
│   ├── CleaningStepTests.swift
│   ├── CleaningConfigurationTests.swift
│   ├── PresetTypeTests.swift
│   └── DetectedPatternsTests.swift
├── Services/
│   ├── CleaningServiceTests.swift
│   ├── BoundaryValidationTests.swift
│   ├── ContentVerificationTests.swift
│   ├── HeuristicDetectionTests.swift
│   └── TextProcessingServiceTests.swift
└── ViewModels/
    ├── CleaningViewModelTests.swift
    └── DocumentQueueViewModelTests.swift
```

### 12.2 Mock Services

```swift
/// Mock Claude service for testing
final class MockClaudeService: ClaudeServiceProtocol {
    var identifyBoundariesResult: Result<BoundaryInfo, Error>
    var detectPatternsResult: Result<DetectedPatterns, Error>
    
    // Track calls for verification
    var identifyBoundariesCallCount = 0
    var lastSectionType: SectionType?
}
```

### 12.3 Defense Layer Testing

The multi-layer defense architecture requires comprehensive testing:

```swift
final class BoundaryValidationTests: XCTestCase {
    
    func testBackMatterTooEarly_IsRejected() {
        let validator = BoundaryValidator()
        let boundary = BoundaryInfo(startLine: 4, endLine: 414, confidence: 0.8)
        
        let result = validator.validate(
            boundary: boundary,
            sectionType: .backMatter,
            documentLineCount: 415
        )
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.rejectionReason, .positionTooEarly)
    }
    
    func testBackMatterAfterHalfway_Passes() {
        let validator = BoundaryValidator()
        let boundary = BoundaryInfo(startLine: 300, endLine: 400, confidence: 0.8)
        
        let result = validator.validate(
            boundary: boundary,
            sectionType: .backMatter,
            documentLineCount: 500
        )
        
        XCTAssertTrue(result.isValid)
    }
}
```

---

## Document History

| Version | Date | Author | Changes |
|:--------|:-----|:-------|:--------|
| 1.0 | January 2025 | Claude | Initial draft (OCR-focused) |
| 2.0 | January 2026 | Claude | Major expansion: 14-step cleaning pipeline, multi-layer defense architecture, dual API integration, pattern detection system |

---

*This document is part of the Horus documentation suite.*
*Previous: Product Requirements Document*
*Next: API Integration Guide*
