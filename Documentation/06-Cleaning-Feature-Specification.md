# Technical Specification Document
## Horus V2 — Intelligent Document Cleaning Feature

> **Document Version:** 2.0  
> **Last Updated:** January 2026  
> **Status:** Implemented  
> **Prerequisites:** PRD v2.0, Technical Architecture v2.0, API Integration Guide v2.0

---

## Table of Contents

1. [Feature Overview](#1-feature-overview)
2. [Pipeline Architecture](#2-pipeline-architecture)
3. [Data Models](#3-data-models)
4. [Preset System](#4-preset-system)
5. [Content Type Detection](#5-content-type-detection)
6. [Service Layer Architecture](#6-service-layer-architecture)
7. [Processing Pipeline](#7-processing-pipeline)
8. [Chunking Strategy](#8-chunking-strategy)
9. [Claude API Integration](#9-claude-api-integration)
10. [Error Handling](#10-error-handling)
11. [UI/UX Specification](#11-uiux-specification)
12. [Settings Integration](#12-settings-integration)

---

## 1. Feature Overview

### 1.1 Purpose

The Intelligent Document Cleaning feature provides Claude-powered post-processing capabilities that transform raw OCR output into clean, structured content optimized for reading, RAG systems, and LLM training data preparation.

### 1.2 Problem Statement

While Mistral's OCR technology excellently extracts text from documents, the raw output contains artifacts that reduce its utility:

- Headers and footers repeated on every page
- Page numbers scattered throughout the text
- Paragraphs broken mid-sentence by page breaks
- Front matter (copyright, LOC data, publisher information)
- Back matter (indexes, appendices, about sections)
- Scholarly apparatus (citations, footnotes, auxiliary lists)
- Inconsistent metadata formatting
- Overly long paragraphs unsuitable for chunking

Manual cleaning of these artifacts is time-consuming and error-prone. The variability across document types makes rule-based automation insufficient.

### 1.3 Solution

A hybrid intelligent processing system featuring:

1. **14-Step Pipeline** — Comprehensive cleaning organized into 5 phases
2. **Content-Type Awareness** — Adapts behavior based on detected content (poetry, code, academic, etc.)
3. **Preset System** — Four optimized presets for common use cases (Default, Training, Minimal, Scholarly)
4. **User Control** — All 14 steps are toggleable; presets provide starting points, not mandates
5. **Hybrid Processing** — Claude handles pattern recognition; code handles bulk application
6. **Any Document Size** — Intelligent chunking enables processing of documents from 50 to 1500+ pages

### 1.4 Design Principles

**Intelligence Where Needed**
Claude handles tasks requiring understanding (semantic splitting, pattern detection, boundary identification). Code handles mechanical tasks (regex replacement, section removal, template rendering).

**Content-Type Awareness**
Step 1 detects content characteristics (poetry, dialogue, code, academic). Downstream steps adapt their behavior accordingly—preserving verse structure in poetry, protecting code blocks from character cleaning, etc.

**Transparency**
Users see each cleaning step complete and can verify results before proceeding. Progress tracking shows current step, chunk progress, and elapsed time.

**Adaptability**
No hardcoded patterns—Claude learns each document's unique structure. The preset system provides optimized defaults while allowing full customization.

**Scalability**
Documents of any size process successfully through intelligent chunking with context preservation across chunk boundaries.

**Preservation**
Original OCR output is never modified—cleaned content exists alongside raw content as a separate artifact.

---

## 2. Pipeline Architecture

### 2.1 14-Step Pipeline Overview

The cleaning pipeline consists of 14 steps organized into 5 phases:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PHASE 1: EXTRACTION & ANALYSIS                        │
├─────────────────────────────────────────────────────────────────────────┤
│  Step 1: Extract Metadata                                                │
│          • Bibliographic info (title, author, publisher, date)           │
│          • Content type detection (poetry, dialogue, code, academic)     │
│          • Flags inform downstream step behavior                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PHASE 2: STRUCTURAL REMOVAL                           │
├─────────────────────────────────────────────────────────────────────────┤
│  Step 2: Remove Front Matter (copyright, LOC data, publisher info)       │
│  Step 3: Remove Table of Contents                                        │
│  Step 4: Remove Auxiliary Lists [TOGGLEABLE]                             │
│          (figures, tables, abbreviations, contributors)                  │
│  Step 5: Remove Page Numbers                                             │
│  Step 6: Remove Headers & Footers                                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PHASE 3: CONTENT CLEANING                             │
│           (Optimized order: pattern detection before text modification)  │
├─────────────────────────────────────────────────────────────────────────┤
│  Step 7: Remove Citations [TOGGLEABLE]                                   │
│          (APA, MLA, IEEE, Chicago, Harvard, legal styles)                │
│  Step 8: Remove Footnotes & Endnotes [TOGGLEABLE]                        │
│          (markers and content sections)                                  │
│  Step 9: Reflow Paragraphs                                               │
│          (content-type aware: preserves poetry, code, tables)            │
│  Step 10: Clean Special Characters                                       │
│           (OCR artifacts, ligatures, quotation normalization)            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PHASE 4: BACK MATTER REMOVAL                          │
├─────────────────────────────────────────────────────────────────────────┤
│  Step 11: Remove Index (alphabetical index section)                      │
│  Step 12: Remove Back Matter                                             │
│           (appendices, about author; preserves epilogues)                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    PHASE 5: OPTIMIZATION & ASSEMBLY                      │
├─────────────────────────────────────────────────────────────────────────┤
│  Step 13: Optimize Paragraph Length                                      │
│           (semantic splitting at configurable word limit)                │
│  Step 14: Add Document Structure                                         │
│           (title header, metadata block, chapter markers, end marker)    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Step Execution Order

Steps execute in numerical order (1→14), but the order within Phase 3 was specifically optimized:

**Pattern Detection Before Text Modification:**
- Steps 7-8 (Citations, Footnotes) execute before Steps 9-10 (Reflow, Clean)
- Rationale: Pattern detection works better on unmodified text
- Citation and footnote patterns are more accurately identified before paragraph boundaries change

### 2.3 Step Classification

| Step | Name | Method | Toggleable | Content-Aware |
|:----:|:-----|:-------|:----------:|:-------------:|
| 1 | Extract Metadata | Claude-only | ✓ | — |
| 2 | Remove Front Matter | Hybrid | ✓ | — |
| 3 | Remove Table of Contents | Hybrid | ✓ | — |
| 4 | Remove Auxiliary Lists | Hybrid | ✓ (preset-controlled) | — |
| 5 | Remove Page Numbers | Hybrid | ✓ | — |
| 6 | Remove Headers & Footers | Hybrid | ✓ | — |
| 7 | Remove Citations | Hybrid | ✓ (preset-controlled) | ✓ |
| 8 | Remove Footnotes/Endnotes | Hybrid | ✓ (preset-controlled) | ✓ |
| 9 | Reflow Paragraphs | Claude-chunked | ✓ | ✓ |
| 10 | Clean Special Characters | Code-only | ✓ | ✓ |
| 11 | Remove Index | Hybrid | ✓ | — |
| 12 | Remove Back Matter | Hybrid | ✓ | — |
| 13 | Optimize Paragraph Length | Claude-chunked | ✓ | ✓ |
| 14 | Add Document Structure | Code-only | ✓ | — |

**Processing Methods:**
- **Claude-only**: Processed entirely by Claude (small input)
- **Hybrid**: Claude detects patterns/boundaries, code applies them
- **Claude-chunked**: Claude processes in chunks (large documents)
- **Code-only**: Processed entirely by code (regex, templates)

---

## 3. Data Models

### 3.1 CleaningStep

Represents a single step in the cleaning pipeline.

```swift
/// A single step in the cleaning pipeline.
enum CleaningStep: Int, CaseIterable, Identifiable, Codable, Comparable, Sendable {
    
    // Phase 1: Extraction & Analysis
    case extractMetadata = 1
    
    // Phase 2: Structural Removal
    case removeFrontMatter = 2
    case removeTableOfContents = 3
    case removeAuxiliaryLists = 4      // Toggleable
    case removePageNumbers = 5
    case removeHeadersFooters = 6
    
    // Phase 3: Content Cleaning (optimized order)
    case removeCitations = 7           // Toggleable
    case removeFootnotesEndnotes = 8   // Toggleable
    case reflowParagraphs = 9
    case cleanSpecialCharacters = 10
    
    // Phase 4: Back Matter Removal
    case removeIndex = 11
    case removeBackMatter = 12
    
    // Phase 5: Optimization & Assembly
    case optimizeParagraphLength = 13
    case addStructure = 14
    
    var id: Int { rawValue }
    
    /// Display name for UI
    var displayName: String { ... }
    
    /// Short activity description for progress UI
    var shortDescription: String { ... }
    
    /// Detailed description for tooltips
    var description: String { ... }
    
    /// SF Symbol for UI
    var symbolName: String { ... }
    
    /// Processing method for this step
    var processingMethod: ProcessingMethod { ... }
    
    /// Whether this step requires Claude API
    var requiresClaude: Bool { processingMethod != .codeOnly }
    
    /// Whether this step processes content in chunks
    var isChunked: Bool { processingMethod == .claudeChunked }
    
    /// Estimated relative time (1-5 scale)
    var estimatedRelativeTime: Int { ... }
    
    /// Whether this step is toggleable by user
    var isToggleable: Bool { ... }
    
    /// The pipeline phase this step belongs to
    var phase: CleaningPhase { ... }
    
    /// Whether this step is content-type aware
    var isContentTypeAware: Bool { ... }
}
```

### 3.2 CleaningPhase

Organizes steps into logical phases.

```swift
/// Phases of the cleaning pipeline.
enum CleaningPhase: Int, CaseIterable, Identifiable, Codable, Sendable {
    case extractionAnalysis = 1
    case structuralRemoval = 2
    case contentCleaning = 3
    case backMatterRemoval = 4
    case optimizationAssembly = 5
    
    var displayName: String { ... }
    var description: String { ... }
    var symbolName: String { ... }
    var steps: [CleaningStep] { ... }
    var stepRange: String { ... }  // e.g., "Steps 2-6"
}
```

### 3.3 ProcessingMethod

```swift
/// How a cleaning step is processed.
enum ProcessingMethod: String, Codable, Sendable {
    case claudeOnly      // Processed entirely by Claude (small input)
    case hybrid          // Claude detects patterns, code applies them
    case claudeChunked   // Claude processes in chunks (large documents)
    case codeOnly        // Processed entirely by code (regex, templates)
    
    var displayName: String { ... }
    var shortDisplayName: String { ... }
    var requiresAPI: Bool { self != .codeOnly }
    var relativeCost: Int { ... }  // 0-3 scale
}
```

### 3.4 CleaningConfiguration

Configuration for the cleaning pipeline, integrating with the preset system.

```swift
/// Configuration for the document cleaning pipeline.
struct CleaningConfiguration: Codable, Equatable, Sendable {
    
    // MARK: - Preset Tracking
    
    var basePreset: PresetType?
    var isModifiedFromPreset: Bool = false
    
    // MARK: - Phase 1: Extraction & Analysis
    var extractMetadata: Bool = true
    
    // MARK: - Phase 2: Structural Removal
    var removeFrontMatter: Bool = true
    var removeTableOfContents: Bool = true
    var removeAuxiliaryLists: Bool = false  // Toggleable, preset-controlled
    var removePageNumbers: Bool = true
    var removeHeadersFooters: Bool = true
    
    // MARK: - Phase 3: Content Cleaning
    var removeCitations: Bool = false       // Toggleable, preset-controlled
    var removeFootnotesEndnotes: Bool = false  // Toggleable, preset-controlled
    var reflowParagraphs: Bool = true
    var cleanSpecialCharacters: Bool = true
    
    // MARK: - Phase 4: Back Matter Removal
    var removeIndex: Bool = true
    var removeBackMatter: Bool = false
    
    // MARK: - Phase 5: Optimization & Assembly
    var optimizeParagraphLength: Bool = true
    var addStructure: Bool = true
    
    // MARK: - Parameters
    var maxParagraphWords: Int = 250
    var metadataFormat: MetadataFormat = .yaml
    var chapterMarkerStyle: ChapterMarkerStyle = .htmlComments
    var endMarkerStyle: EndMarkerStyle = .standard
    var enableChapterSegmentation: Bool = true
    
    // MARK: - Confidence Thresholds
    var boundaryConfidenceThreshold: Double = 0.7
    var citationConfidenceThreshold: Double = 0.7
    var footnoteConfidenceThreshold: Double = 0.7
    
    // MARK: - Content Type Behavior
    var respectContentTypeFlags: Bool = true
    var adjustForChildrensContent: Bool = true
    var preserveCodeBlocks: Bool = true
    var preserveMathSymbols: Bool = true
    
    // MARK: - Initialization
    
    init() { self.basePreset = .default }
    init(preset: PresetType) { ... }
    
    // MARK: - Preset Application
    mutating func applyPreset(_ preset: PresetType) { ... }
    mutating func applyContentTypeAdjustments(_ flags: ContentTypeFlags) { ... }
    mutating func resetToPreset() { ... }
    
    // MARK: - Computed Properties
    var enabledSteps: [CleaningStep] { ... }
    var enabledStepCount: Int { ... }
    var requiresClaudeAPI: Bool { ... }
    var estimatedComplexity: Int { ... }
    var differsFromPreset: Bool { ... }
    var modifiedSettings: [String] { ... }
    
    // MARK: - Static Presets
    static let `default` = CleaningConfiguration(preset: .default)
    static let forTraining = CleaningConfiguration(preset: .training)
    static let minimal = CleaningConfiguration(preset: .minimal)
    static let scholarly = CleaningConfiguration(preset: .scholarly)
}
```

### 3.5 CleaningStepStatus

Tracks the status of each step during processing.

```swift
/// Status of a cleaning step during processing.
enum CleaningStepStatus: Equatable, Sendable {
    case pending
    case processing
    case completed(wordCount: Int, changeCount: Int)
    case skipped
    case failed(message: String)
    case cancelled
    
    var isTerminal: Bool { ... }
    var isSuccess: Bool { ... }
    var isFailed: Bool { ... }
    var isSkipped: Bool { ... }
    var displayText: String { ... }
    var shortText: String { ... }
    var symbolName: String { ... }
    var statusColor: String { ... }
}
```

### 3.6 CleaningProgress

Tracks overall progress of the cleaning pipeline.

```swift
/// Progress tracking for the cleaning pipeline.
struct CleaningProgress: Equatable, Sendable {
    let currentStep: CleaningStep?
    var stepStatuses: [CleaningStep: CleaningStepStatus]
    let enabledSteps: [CleaningStep]
    let startedAt: Date
    var currentChunk: Int = 0
    var totalChunks: Int = 0
    
    var completedCount: Int { ... }
    var overallProgress: Double { ... }
    var elapsedTime: TimeInterval { ... }
    var isComplete: Bool { ... }
    var hasFailed: Bool { ... }
    
    init(enabledSteps: [CleaningStep], startedAt: Date = Date()) { ... }
}
```

### 3.7 DocumentMetadata

Structured metadata extracted from the document during Step 1.

```swift
/// Metadata extracted from a document.
struct DocumentMetadata: Codable, Equatable, Sendable {
    var title: String
    var author: String?
    var publisher: String?
    var publishDate: String?
    var isbn: String?
    var language: String?
    var genre: String?
    var series: String?
    var edition: String?
    
    func toYAML() -> String { ... }
    func toJSON() -> String { ... }
    func toMarkdown() -> String { ... }
}
```

### 3.8 DetectedPatterns

Patterns identified by Claude during pattern detection phase.

```swift
/// Patterns detected in a document by Claude.
struct DetectedPatterns: Codable, Equatable, Sendable {
    
    // Identity
    let documentId: UUID
    var detectedAt: Date
    
    // Page Number Patterns
    var pageNumberPatterns: [String]
    
    // Header/Footer Patterns
    var headerPatterns: [String]
    var footerPatterns: [String]
    
    // Front Matter Boundaries
    var frontMatterEndLine: Int?
    var frontMatterConfidence: Double?
    
    // Table of Contents Boundaries
    var tocStartLine: Int?
    var tocEndLine: Int?
    var tocConfidence: Double?
    
    // Auxiliary Lists (V2 - Step 4)
    var auxiliaryLists: [AuxiliaryListInfo]
    var auxiliaryListConfidence: Double?
    
    // Citation Patterns (V2 - Step 7)
    var citationStyle: CitationStyle?
    var citationPatterns: [String]
    var citationCount: Int?
    var citationConfidence: Double?
    var citationSamples: [String]
    
    // Footnote/Endnote Patterns (V2 - Step 8)
    var footnoteMarkerStyle: FootnoteMarkerStyle?
    var footnoteMarkerPattern: String?
    var footnoteMarkerCount: Int?
    var footnoteSections: [FootnoteSectionInfo]
    var footnoteConfidence: Double?
    
    // Index Boundaries
    var indexStartLine: Int?
    var indexEndLine: Int?
    var indexType: String?
    var indexConfidence: Double?
    
    // Back Matter Boundaries
    var backMatterStartLine: Int?
    var backMatterEndLine: Int?
    var backMatterType: String?
    var backMatterConfidence: Double?
    var preservedSections: [String]
    var hasEpilogueContent: Bool?
    var hasEndAcknowledgments: Bool?
    
    // Chapter Detection (V2 - Step 14)
    var chapterStartLines: [Int]
    var chapterTitles: [String]
    var hasParts: Bool?
    var partStartLines: [Int]
    var partTitles: [String]
    var chapterConfidence: Double?
    
    // Content Type Cache (V2)
    var contentTypeFlags: ContentTypeFlags?
    
    // Paragraph/Reflow Patterns
    var paragraphBreakIndicators: [String]
    var specialCharactersToRemove: [String]
    
    // Overall Confidence
    var confidence: Double
    var analysisNotes: String?
    
    // Default Patterns
    static let defaultPageNumberPatterns: [String] = [
        "^\\d+$",                          // Standalone digits
        "^[ivxlcdm]+$",                    // Roman numerals
        "^Page\\s+\\d+$",                  // "Page 42"
        "^-\\s*\\d+\\s*-$",                // "- 42 -"
        "^\u{2014}\\s*\\d+\\s*\u{2014}$",  // "— 42 —" (em-dash)
        // ... additional patterns
    ]
}
```

### 3.9 CleanedContent

The result of the cleaning pipeline.

```swift
/// Result of the cleaning pipeline.
struct CleanedContent: Codable, Equatable, Sendable {
    let id: UUID
    let documentId: UUID
    let ocrResultId: UUID
    let metadata: DocumentMetadata
    let cleanedMarkdown: String
    let configuration: CleaningConfiguration
    let detectedPatterns: DetectedPatterns
    let completedAt: Date
    let cleaningDuration: TimeInterval
    let apiCallCount: Int
    let tokensUsed: Int
    let executedSteps: [CleaningStep]
    let contentTypeFlags: ContentTypeFlags?
    
    var cleanedPlainText: String { ... }
    var wordCount: Int { ... }
    var characterCount: Int { ... }
    var estimatedTokenCount: Int { ... }
    var formattedDuration: String { ... }
}
```

---

## 4. Preset System

### 4.1 PresetType

Four optimized presets for common use cases.

```swift
/// Available cleaning presets with optimized configurations.
enum PresetType: String, Codable, CaseIterable, Identifiable, Sendable {
    case `default` = "default"
    case training = "training"
    case minimal = "minimal"
    case scholarly = "scholarly"
    
    var displayName: String { ... }
    var shortDescription: String { ... }
    var detailedDescription: String { ... }
    var symbolName: String { ... }
    var targetUsers: String { ... }
    var targetDocuments: String { ... }
    
    // Toggleable Step Defaults
    var removeAuxiliaryLists: Bool { ... }
    var removeCitations: Bool { ... }
    var removeFootnotesEndnotes: Bool { ... }
    
    // Step Parameters
    var maxParagraphWords: Int { ... }
    var enableParagraphOptimization: Bool { ... }
    var enableChapterSegmentation: Bool { ... }
    var chapterMarkerStyle: ChapterMarkerStyle { ... }
    var endMarkerStyle: EndMarkerStyle { ... }
    var boundaryConfidenceThreshold: Double { ... }
    
    // Core Step Behavior
    var removeFrontMatter: Bool { ... }
    var removeTableOfContents: Bool { ... }
    var removeIndex: Bool { ... }
    var removeBackMatter: Bool { ... }
}
```

### 4.2 Preset Comparison

| Setting | Default | Training | Minimal | Scholarly |
|:--------|:-------:|:--------:|:-------:|:---------:|
| **Remove Front Matter** | ✓ | ✓ | ✗ | ✓ |
| **Remove TOC** | ✓ | ✓ | ✗ | ✓ |
| **Remove Auxiliary Lists** | ✗ | ✓ | ✗ | ✓ |
| **Remove Citations** | ✗ | ✓ | ✗ | ✓ |
| **Remove Footnotes** | ✗ | ✓ | ✗ | ✓ |
| **Remove Index** | ✓ | ✓ | ✗ | ✗ |
| **Remove Back Matter** | ✓ | ✓ | ✗ | ✗ |
| **Optimize Paragraphs** | ✓ | ✓ | ✗ | ✓ |
| **Max Words** | 250 | 250 | — | 300 |
| **Chapter Markers** | HTML | Token | None | HTML |
| **End Marker** | Standard | Token | Minimal | Standard |

### 4.3 Preset Philosophy

**Default**: Balanced cleaning for most documents. Removes structural artifacts while preserving content integrity. Conservative with scholarly apparatus—citations and footnotes preserved unless explicitly enabled. Suitable for fiction, non-fiction, general prose.

**Training**: Maximum content purity for LLM training. Removes all scholarly apparatus (citations, footnotes, auxiliary lists) and structural noise. Produces clean, flowing text optimized for language model consumption. Uses token-style markers for clear structural signals.

**Minimal**: Light-touch cleaning focused on OCR artifact removal. Preserves document structure including front matter, table of contents, index, and back matter. Ideal when original formatting is important or for documents requiring structure preservation.

**Scholarly**: Optimized for academic documents. Removes citations, footnotes, and bibliography while preserving core scholarly content. Uses higher paragraph word limits (300) appropriate for academic writing. Keeps index for reference works.

---

## 5. Content Type Detection

### 5.1 ContentTypeFlags

Content characteristics detected during Step 1 that inform downstream processing.

```swift
/// Content type characteristics detected during Step 1.
struct ContentTypeFlags: Codable, Equatable, Sendable {
    
    // Content Presence Flags
    var hasPoetry: Bool = false          // Verse with intentional line structure
    var hasDialogue: Bool = false        // Novels, plays, screenplays
    var hasCode: Bool = false            // Programming content
    var isAcademic: Bool = false         // Papers, dissertations, journals
    var isLegal: Bool = false            // Contracts, statutes, case law
    var isChildrens: Bool = false        // Children's literature
    var hasReligiousVerses: Bool = false // Chapter:verse numbering
    var hasTabularData: Bool = false     // Tables, columnar formatting
    var hasMathematical: Bool = false    // Equations, formulas
    
    // Summary Fields
    var primaryType: ContentPrimaryType = .prose
    var confidence: Double = 0.0
    var notes: String?
    
    // Computed Properties
    var hasSpecialContent: Bool { ... }
    var shouldSkipReflow: Bool { ... }
    var hasCitationLikelihood: Bool { ... }
    var hasFootnoteLikelihood: Bool { ... }
    var recommendedMaxParagraphWords: Int { ... }
    var shouldSuggestScholarlyPreset: Bool { ... }
    var shouldSuggestMinimalPreset: Bool { ... }
}
```

### 5.2 Content Type Impact on Steps

| Content Type | Affected Steps | Behavior |
|:-------------|:---------------|:---------|
| **Poetry** | 9, 13 | Preserves line breaks; skips paragraph optimization |
| **Dialogue** | 9, 13 | Preserves conversational flow |
| **Code** | 9, 10 | Skips reflow; preserves syntax characters |
| **Academic** | 7, 8 | Enables citation/footnote awareness |
| **Legal** | 8, 9 | Preserves legal symbols; legal citation patterns |
| **Children's** | 13 | Lowers max words to 150 |
| **Religious** | 9 | Preserves verse structure and numbering |
| **Tabular** | 9 | Skips tables entirely |
| **Mathematical** | 10 | Preserves math symbols and notation |

### 5.3 ContentPrimaryType

```swift
/// Primary content classification for a document.
enum ContentPrimaryType: String, Codable, CaseIterable, Sendable {
    case prose = "Prose"
    case poetry = "Poetry"
    case dialogue = "Dialogue"
    case technical = "Technical"
    case academic = "Academic"
    case legal = "Legal"
    case childrens = "Children's"
    case religious = "Religious"
    case mixed = "Mixed"
    
    var suggestedPresetHint: String? { ... }
    var typicallyHasCitations: Bool { ... }
    var requiresStructurePreservation: Bool { ... }
}
```

---

## 6. Service Layer Architecture

### 6.1 Service Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CleaningService                               │
│                      (Pipeline Orchestrator)                         │
├─────────────────────────────────────────────────────────────────────┤
│  • Manages 14-step sequencing                                        │
│  • Tracks progress with phase awareness                              │
│  • Handles cancellation                                              │
│  • Coordinates content-type aware processing                         │
│  • Integrates preset configuration                                   │
└───────────────────┬─────────────────────────────────────────────────┘
                    │
    ┌───────────────┼───────────────────────────┐
    │               │                           │
    ▼               ▼                           ▼
┌─────────────┐ ┌─────────────────┐ ┌─────────────────────┐
│   Claude    │ │ PatternDetection │ │ TextProcessing     │
│   Service   │ │ Service          │ │ Service            │
├─────────────┤ ├─────────────────┤ ├─────────────────────┤
│ API calls   │ │ Pattern learning │ │ Regex operations   │
│ Chunking    │ │ Boundary detect  │ │ Template rendering │
│ Validation  │ │ Caching          │ │ Character cleaning │
│             │ │ V2: Citation,    │ │ V2: OCR artifacts  │
│             │ │ footnote, chapter│ │ ligatures, quotes  │
└─────────────┘ └─────────────────┘ └─────────────────────┘
```

### 6.2 CleaningService Protocol

```swift
/// Protocol for the cleaning pipeline orchestrator.
@MainActor
protocol CleaningServiceProtocol {
    
    /// Clean a document with the given configuration.
    func cleanDocument(
        _ document: Document,
        configuration: CleaningConfiguration,
        onStepStarted: @escaping (CleaningStep) -> Void,
        onStepCompleted: @escaping (CleaningStep, CleaningStepStatus) -> Void,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> CleanedContent
    
    /// Cancel ongoing cleaning.
    func cancelCleaning()
    
    /// Preview a single step without committing.
    func previewStep(
        _ step: CleaningStep,
        content: String,
        configuration: CleaningConfiguration
    ) async throws -> String
    
    /// Validate that cleaning can proceed.
    func validateConfiguration(_ configuration: CleaningConfiguration) throws
}
```

### 6.3 ClaudeService Protocol

```swift
/// Protocol for Claude API interactions.
@MainActor
protocol ClaudeServiceProtocol {
    
    /// Analyze document to detect patterns and content type.
    func analyzeDocument(
        content: String,
        documentType: String?
    ) async throws -> (patterns: DetectedPatterns, contentType: ContentTypeFlags)
    
    /// Extract metadata from front matter.
    func extractMetadata(
        frontMatter: String
    ) async throws -> DocumentMetadata
    
    /// Detect citation patterns and style.
    func detectCitations(
        content: String,
        sampleSize: Int
    ) async throws -> (style: CitationStyle?, patterns: [String], count: Int)
    
    /// Detect footnote markers and sections.
    func detectFootnotes(
        content: String
    ) async throws -> (markerStyle: FootnoteMarkerStyle?, sections: [FootnoteSectionInfo])
    
    /// Detect chapter boundaries.
    func detectChapters(
        content: String
    ) async throws -> (startLines: [Int], titles: [String], hasParts: Bool)
    
    /// Reflow paragraphs in a chunk (content-type aware).
    func reflowParagraphs(
        chunk: String,
        previousContext: String?,
        patterns: DetectedPatterns,
        contentTypeFlags: ContentTypeFlags
    ) async throws -> String
    
    /// Optimize paragraph lengths (content-type aware).
    func optimizeParagraphLength(
        chunk: String,
        maxWords: Int,
        contentTypeFlags: ContentTypeFlags
    ) async throws -> String
    
    /// Identify section boundaries.
    func identifyBoundaries(
        content: String,
        sectionType: SectionType
    ) async throws -> (startLine: Int?, endLine: Int?, confidence: Double)
    
    /// Validate API key.
    func validateAPIKey() async throws -> Bool
}
```

### 6.4 TextProcessingService Protocol

```swift
/// Service for code-based text transformations.
protocol TextProcessingServiceProtocol {
    
    // Basic Operations
    func removeMatchingLines(content: String, patterns: [String]) -> String
    func removeSection(content: String, startLine: Int, endLine: Int) -> String
    
    // V2: Enhanced Character Cleaning
    func cleanSpecialCharacters(
        content: String,
        charactersToRemove: [String],
        preserveCodeBlocks: Bool,
        preserveMathSymbols: Bool
    ) -> String
    func expandLigatures(content: String) -> String
    func normalizeQuotations(content: String) -> String
    func removeInvisibleCharacters(content: String) -> String
    func cleanOCRArtifacts(content: String) -> String
    
    // V2: Citation and Footnote Removal
    func removeCitations(content: String, patterns: [String]) -> String
    func removeFootnoteMarkers(content: String, pattern: String) -> String
    func removeFootnoteSections(content: String, sections: [FootnoteSectionInfo]) -> String
    
    // V2: Auxiliary List Removal
    func removeAuxiliaryLists(content: String, lists: [AuxiliaryListInfo]) -> String
    
    // Structure Application
    func applyStructure(
        content: String,
        metadata: DocumentMetadata,
        format: MetadataFormat,
        chapterMarkerStyle: ChapterMarkerStyle,
        endMarkerStyle: EndMarkerStyle,
        chapters: [(line: Int, title: String)]
    ) -> String
    
    // Chunking
    func chunkContent(content: String, targetChunkSize: Int, overlapSize: Int) -> [TextChunk]
    func mergeChunks(chunks: [TextChunk]) -> String
}
```

---

## 7. Processing Pipeline

### 7.1 Pipeline Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           CLEANING PIPELINE                               │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  PHASE 0: INITIALIZATION                                                  │
│  • Validate document has OCR result                                       │
│  • Validate Claude API key (if needed)                                    │
│  • Apply preset configuration                                             │
│  • Determine enabled steps                                                │
│  • Initialize progress tracking                                           │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  STEP 1: EXTRACT METADATA & CONTENT TYPE                                  │
│  • Extract bibliographic metadata (title, author, publisher, etc.)        │
│  • Detect content type flags (poetry, code, academic, etc.)               │
│  • Cache content type for downstream steps                                │
│  • Suggest preset if content type warrants (academic → scholarly)         │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  PATTERN DETECTION PHASE                                                  │
│  • Extract sample content (first 100 pages)                               │
│  • Detect page number patterns, headers, footers                          │
│  • Detect section boundaries (front matter, TOC, index, back matter)      │
│  • V2: Detect auxiliary lists, citations, footnotes, chapters             │
│  • Cache all patterns for step execution                                  │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  STEPS 2-14: SEQUENTIAL EXECUTION                                         │
│                                                                           │
│  For each enabled step:                                                   │
│    1. Check for cancellation                                              │
│    2. Update progress (step started)                                      │
│    3. Execute step logic (content-type aware where applicable)            │
│    4. Validate output (multi-layer defense for boundary detection)        │
│    5. Update working content                                              │
│    6. Update progress (step completed)                                    │
│    7. Notify UI for preview update                                        │
│                                                                           │
│  V2 execution order (Phase 3):                                            │
│    7 → 8 → 9 → 10 (pattern detection before text modification)            │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  FINALIZATION                                                             │
│  • Create CleanedContent object                                           │
│  • Include content type flags, detected patterns, executed steps          │
│  • Attach to Document                                                     │
│  • Update session state                                                   │
│  • Notify UI of completion                                                │
└──────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Step Execution Details

#### Step 1: Extract Metadata & Content Type

```
Input:  Full document content
Method: Claude-only
Output: DocumentMetadata + ContentTypeFlags

Process:
1. Extract front matter area (~5000 characters)
2. Sample middle and end sections for content type detection
3. Send multi-section sample to Claude
4. Parse response into DocumentMetadata and ContentTypeFlags
5. Cache ContentTypeFlags for downstream steps
6. If academic content detected with high confidence, suggest Scholarly preset
```

#### Step 4: Remove Auxiliary Lists (V2 - Toggleable)

```
Input:  Content after TOC removal
Method: Hybrid
Output: Content with auxiliary lists removed

Process:
1. Use patterns.auxiliaryLists if available
2. Each list has type (figures, tables, abbreviations, contributors)
3. Each list has startLine, endLine, confidence
4. Remove only high-confidence lists (>0.7)
5. Log removed lists for verification
```

#### Step 7: Remove Citations (V2 - Toggleable)

```
Input:  Content after headers/footers removal
Method: Hybrid
Output: Content with citations removed

Process:
1. Use patterns.citationStyle and patterns.citationPatterns
2. Supported styles: APA, MLA, IEEE, Chicago, Harvard, Legal
3. Apply style-specific regex patterns
4. Remove parenthetical citations: (Author, Year), [1], etc.
5. Preserve non-citation brackets and parentheses
6. Count removals for verification
```

#### Step 8: Remove Footnotes & Endnotes (V2 - Toggleable)

```
Input:  Content after citation removal
Method: Hybrid
Output: Content with footnotes/endnotes removed

Process:
1. Phase 1: Remove markers from body text
   - Use patterns.footnoteMarkerStyle and patterns.footnoteMarkerPattern
   - Remove superscript numbers, bracketed numbers, asterisks, daggers
2. Phase 2: Remove footnote/endnote sections
   - Use patterns.footnoteSections with startLine, endLine
   - Remove only high-confidence sections (>0.7)
3. Preserve legitimate superscripts (e.g., "1st", "2nd")
```

#### Step 10: Clean Special Characters (V2 Enhanced)

```
Input:  Content after paragraph reflow
Method: Code-only (content-type aware)
Output: Content with OCR artifacts and special characters cleaned

Process:
1. Expand ligatures (ﬁ→fi, ﬂ→fl, œ→oe, etc.)
2. Remove invisible characters (zero-width spaces, BOM, soft hyphens)
3. Clean OCR artifacts:
   - Broken words across lines
   - Misrecognized characters
   - Malformed dividers
4. Normalize quotations (straight quotes → curly quotes consistently)
5. Remove markdown artifacts (*, [], etc.) from prose
6. PRESERVE if contentTypeFlags indicates:
   - Code blocks (preserveCodeBlocks)
   - Math symbols (preserveMathSymbols)
```

#### Step 14: Add Document Structure (V2 Enhanced)

```
Input:  Content after paragraph optimization
Method: Code-only
Output: Final structured document

Process:
1. Generate title header based on metadata
2. Generate metadata block (YAML/JSON/Markdown per configuration)
3. Insert chapter markers if enableChapterSegmentation:
   - Use chapterMarkerStyle (none, htmlComments, markdownH1/H2, tokenStyle)
   - Use detected chapter boundaries from patterns
   - Handle parts (Part I, Part II) if detected
4. Prepend structure to content
5. Append end marker based on endMarkerStyle:
   - Standard: "*** <!-- END OF [TITLE] -->"
   - Token: "<END_DOCUMENT>"
   - Minimal: "***"
6. Final cleanup (normalize whitespace, line endings)
```

---

## 8. Chunking Strategy

### 8.1 Why Chunking Is Necessary

Claude's context window has practical limits. For documents of 1500+ pages:
- Estimated tokens: 750K-1M
- Cannot fit in single API call

Chunking allows processing documents of any size while maintaining quality and context.

### 8.2 Chunk Parameters

```swift
/// Configuration for text chunking.
struct ChunkingConfig {
    /// Target size for each chunk (in lines) — ~50 pages
    static let targetChunkLines = 2500
    
    /// Overlap between chunks (in lines) — ~1 page
    static let overlapLines = 60
    
    /// Maximum tokens per chunk (safety limit)
    static let maxTokensPerChunk = 50000
    
    /// Minimum chunk size (avoid tiny final chunks)
    static let minChunkLines = 500
}
```

### 8.3 Context Preservation

For paragraph-aware operations (Steps 9 and 13), we maintain context across chunk boundaries:

1. **Overlap Region**: Include ~60 lines (1 page) of overlap from previous chunk
2. **Paragraph Context**: Send last paragraph of previous chunk as explicit context
3. **Content-Type Awareness**: Chunking respects detected content type boundaries (don't split mid-poem, mid-code-block)

### 8.4 Chunk Merging

When merging processed chunks:

1. Identify overlap region in processed output
2. Use fuzzy matching to find merge point (Claude may have modified overlap)
3. Deduplicate content from overlap region
4. Maintain paragraph integrity at merge points

---

## 9. Claude API Integration

### 9.1 API Configuration

```swift
/// Configuration for Claude API.
struct ClaudeAPIConfig {
    static let baseURL = URL(string: "https://api.anthropic.com/v1")!
    static let model = "claude-sonnet-4-20250514"
    static let maxTokens = 8192
    static let timeout: TimeInterval = 120
    static let apiVersion = "2024-01-01"
}
```

### 9.2 System Prompt

```
You are an expert document processor specializing in cleaning OCR output 
for use in RAG systems and LLM training. You are precise, consistent, 
and preserve the semantic meaning of text while removing artifacts.

You are content-type aware:
- Preserve intentional formatting in poetry, verse, and religious texts
- Protect code blocks and technical notation
- Recognize academic and legal citation patterns
- Adapt paragraph handling for different content types

Always respond with only the requested output. Do not include explanations 
or commentary unless specifically asked.
```

### 9.3 Multi-Layer Defense for Boundary Detection

All boundary detection operations implement defensive validation:

```
┌────────────────────────────────────────────────────────────────────┐
│                    BOUNDARY DETECTION DEFENSE                       │
├────────────────────────────────────────────────────────────────────┤
│  Layer 1: Intelligent Prompts                                       │
│  • Request confidence scores with each boundary                     │
│  • Ask Claude to explain reasoning                                  │
│  • Include sanity check constraints in prompt                       │
├────────────────────────────────────────────────────────────────────┤
│  Layer 2: Response Validation                                       │
│  • Reject boundaries with confidence < threshold                    │
│  • Reject boundaries that would remove >50% of content              │
│  • Reject boundaries at line 0-10 for front matter                  │
│  • Cross-validate with heuristic patterns                           │
├────────────────────────────────────────────────────────────────────┤
│  Layer 3: Heuristic Fallbacks                                       │
│  • Pattern matching for known section markers                       │
│  • Statistical analysis of line characteristics                     │
│  • Conservative defaults when detection uncertain                   │
├────────────────────────────────────────────────────────────────────┤
│  Layer 4: Content Verification                                      │
│  • Preview content to be removed before execution                   │
│  • Log boundaries and removals for audit                            │
│  • Allow user override of detected boundaries                       │
└────────────────────────────────────────────────────────────────────┘
```

---

## 10. Error Handling

### 10.1 Error Types

```swift
/// Errors that can occur during cleaning.
enum CleaningError: Error, LocalizedError {
    // API Errors
    case missingAPIKey
    case authenticationFailed
    case apiError(code: Int, message: String)
    case rateLimited
    case timeout
    case invalidResponse
    
    // Document Errors
    case noOCRResult
    case contentTooShort
    case unsupportedContent
    
    // Processing Errors
    case patternDetectionFailed(String)
    case stepFailed(step: CleaningStep, reason: String)
    case chunkingFailed(String)
    case boundaryValidationFailed(String)
    
    // Content Type Errors
    case contentTypeMismatch(expected: String, detected: String)
    
    // User Actions
    case cancelled
    
    var errorDescription: String? { ... }
    var recoverySuggestion: String? { ... }
    var isRetryable: Bool { ... }
}
```

### 10.2 Recovery Strategies

| Error Type | Recovery Strategy |
|:-----------|:------------------|
| `missingAPIKey` | Prompt user to add API key in Settings |
| `authenticationFailed` | Prompt user to verify/update API key |
| `rateLimited` | Automatic retry with exponential backoff |
| `timeout` | Retry once; if fails, suggest fewer steps |
| `stepFailed` | Mark step as failed; user can retry or skip |
| `boundaryValidationFailed` | Fall back to heuristics; warn user |
| `cancelled` | Clean up state; preserve completed work |

---

## 11. UI/UX Specification

### 11.1 Clean Tab Integration

The Clean tab is the fourth tab in the 5-tab navigation:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  [Input]  [OCR]  [Clean]  [Library]  [Settings]                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Cleaning View Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│  CLEAN                                                      [Document ▼]│
├──────────────────────────────┬──────────────────────────────────────────┤
│                              │                                          │
│  PRESET                      │  PREVIEW                                 │
│  ┌────────────────────────┐  │                                          │
│  │ [Default ▼]  Modified  │  │  ┌────────────────────────────────────┐  │
│  └────────────────────────┘  │  │ # HANDBOOK OF CHINESE MYTHOLOGY    │  │
│                              │  │                                    │  │
│  CLEANING STEPS              │  │ ---                                │  │
│                              │  │ title: HANDBOOK OF CHINESE...      │  │
│  Phase 1: Extraction         │  │ author: LIHUI YANG, DEMING AN      │  │
│  ☑ 1. Extract Metadata       │  │ ---                                │  │
│                              │  │                                    │  │
│  Phase 2: Structural         │  │ Content type: Academic (87%)       │  │
│  ☑ 2. Remove Front Matter    │  │                                    │  │
│  ☑ 3. Remove TOC             │  │ ## PREFACE                         │  │
│  ☐ 4. Remove Auxiliary Lists │  │                                    │  │
│  ☑ 5. Remove Page Numbers    │  │ On October 30, 2000, I received... │  │
│  ☑ 6. Remove Headers/Footers │  │                                    │  │
│                              │  └────────────────────────────────────┘  │
│  Phase 3: Content            │                                          │
│  ☐ 7. Remove Citations       │  Toggle: [Raw OCR] [Cleaned ●]          │
│  ☐ 8. Remove Footnotes       │                                          │
│  ☑ 9. Reflow Paragraphs      │                                          │
│  ☑ 10. Clean Characters      │                                          │
│                              │                                          │
│  Phase 4: Back Matter        │                                          │
│  ☑ 11. Remove Index          │                                          │
│  ☐ 12. Remove Back Matter    │                                          │
│                              │                                          │
│  Phase 5: Optimization       │                                          │
│  ☑ 13. Optimize Paragraphs   │                                          │
│     Max words: [250    ]     │                                          │
│  ☑ 14. Add Structure         │                                          │
│                              │                                          │
│  ─────────────────────────── │                                          │
│                              │                                          │
│  PROGRESS                    │                                          │
│  Step 9 of 12: Reflow...     │                                          │
│  [████████░░░░░░░░░░] 75%    │                                          │
│  Chunk 18 of 24              │                                          │
│  Elapsed: 1m 45s             │                                          │
│                              │                                          │
│  ─────────────────────────── │                                          │
│                              │                                          │
│  [Start Cleaning]  [Cancel]  │                                          │
│                              │                                          │
└──────────────────────────────┴──────────────────────────────────────────┘
```

### 11.3 Preset Selector with "Modified" Badge

When user changes settings from preset defaults, a "Modified" badge appears:

```
┌────────────────────────────────────┐
│  Preset: [Training ▼]   Modified   │
│                         ~~~~~~~~   │
│  (Modified badge shows when any    │
│   setting differs from preset)     │
└────────────────────────────────────┘
```

### 11.4 Content Type Detection Display

After Step 1 completes, show detected content type:

```
┌────────────────────────────────────┐
│  Content Type Detected:            │
│  📚 Academic (87% confidence)      │
│                                    │
│  Flags: Academic, Citations        │
│                                    │
│  💡 Scholarly preset recommended   │
│     [Apply Scholarly Preset]       │
└────────────────────────────────────┘
```

### 11.5 Keyboard Shortcuts

| Shortcut | Action |
|:---------|:-------|
| ⌘⇧C | Open Clean tab |
| ⌘↵ | Start/Continue cleaning |
| ⎋ | Cancel cleaning |
| ⌘1-9 | Toggle steps 1-9 |
| ⌘0 | Toggle all steps |
| ⌘P | Cycle through presets |

---

## 12. Settings Integration

### 12.1 Claude API Section

```
┌─────────────────────────────────────────────────────────────────────────┐
│  CLAUDE API                                                             │
│  ─────────────────────────────────────────────────────────────────────  │
│  API Key: [••••••••••••••••••••••]  [Validate]  ✓ Valid                 │
│                                                                         │
│  Get your Claude API key at console.anthropic.com                       │
└─────────────────────────────────────────────────────────────────────────┘
```

### 12.2 Cleaning Defaults Section

```
┌─────────────────────────────────────────────────────────────────────────┐
│  CLEANING DEFAULTS                                                      │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  Default Preset: [Default ▼]                                            │
│                                                                         │
│  Paragraph Optimization:                                                │
│  Max words per paragraph: [250    ]                                     │
│                                                                         │
│  Output Format:                                                         │
│  Metadata format: [YAML ▼]                                              │
│  Chapter markers: [HTML Comments ▼]                                     │
│  End marker: [Standard ▼]                                               │
│                                                                         │
│  Content Type Behavior:                                                 │
│  ☑ Respect content type flags                                           │
│  ☑ Adjust paragraph length for children's content                       │
│  ☑ Preserve code blocks from cleaning                                   │
│  ☑ Preserve math symbols from cleaning                                  │
│                                                                         │
│  [Reset to Defaults]                                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Document History

| Version | Date | Author | Changes |
|:--------|:-----|:-------|:--------|
| 1.0 | January 2026 | Claude | Initial draft (11-step pipeline) |
| 2.0 | January 2026 | Claude | V2 Implementation: 14-step pipeline, preset system, content-type awareness, enhanced pattern detection |

---

*This document is part of the Horus V2 documentation suite.*  
*Previous: Implementation Guide*  
*Next: Implementation Plan*
