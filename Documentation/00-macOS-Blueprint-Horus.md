# Horus — macOS Development Blueprint
## Version 5.0 — February 2026

> *"The details are not the details. They make the design."*
> — Charles Eames

---

## About This Document

This blueprint defines the identity, philosophy, standards, and current technical state of Horus—a production-quality native macOS application that transforms documents into clean AI training data. It establishes who we are as a development team, how we work together, and the principles guiding every decision.

This document reflects the **current state of Horus (V2/V3 evolved architecture)**, including the sophisticated 16-step, 8-phase cleaning pipeline, the three-column layout system, and the integrated dual-API architecture. Everything here applies both to ongoing Horus development and as guiding principles for future macOS projects.

**Document Version:** 5.0
**Last Updated:** February 2026
**Status:** Living Document
**Project Version:** V2/V3 (Evolved Pipeline Architecture)

---

# Part I: Project Identity

## Horus: Native macOS Application for AI-Ready Documents

Horus is a native macOS application that transforms scanned documents and PDFs into clean, structured text optimized for large language model training and knowledge work.

### The Core Problem

Preparing document-based training data for large language models requires more than OCR extraction. Raw extracted text contains:

- **Scaffolding content** — Front matter, back matter, tables of contents, indexes
- **Reference apparatus** — Citations, footnotes, endnotes, bibliographies
- **Structural artifacts** — Page numbers, headers, footers, OCR errors
- **Non-narrative elements** — Publication information, copyright notices, appendices

Current workflows involve manual cleanup, fragile scripts, or generic tools that don't understand document structure. The result is either low-quality training data or significant human effort.

### The Solution

Horus provides an integrated workflow:

1. **Document Import** — Drag-and-drop or file selection for PDFs and images
2. **OCR Processing** — Extract text using Mistral AI's advanced OCR technology
3. **Intelligent Cleaning** — Remove scaffolding while preserving narrative through a 16-step, 8-phase pipeline
4. **Quality Review** — Preview cleaned content with full diff visibility before export
5. **Structured Export** — Export to Markdown, JSON, or plain text optimized for LLM workflows

### Key Differentiators

| Aspect | Horus | Alternatives |
|:-------|:------|:-------------|
| Document Understanding | AI-powered boundary detection with multi-layer validation | Pattern matching or manual rules |
| Reliability | Defensive architecture prevents catastrophic content loss | Trust-based processing |
| Cleaning Sophistication | 16-step pipeline targeting specific document elements | Generic text cleanup |
| Platform Integration | Native macOS with full system integration | Web-based or cross-platform |
| Quality Assurance | Preview with diff visualization before export | Export-then-check workflow |
| Dual-API Architecture | Mistral OCR + Claude AI cleaning orchestration | Single-API dependency |

---

# Part II: Development Philosophy

## Moebius Building Style

Horus embodies our philosophy of building applications that feel inevitable—where design and engineering unite to create software that delights through craft rather than features.

### Five Essential Qualities

**Purposeful**
Every element exists for a reason. Nothing is decorative without function; nothing functional lacks consideration for form. The application does exactly what it should, nothing more, nothing less.

**Designed**
Intentionality is visible in every detail. Typography, spacing, color, motion—each choice reflects deliberate consideration. Users may not consciously notice these decisions, but they feel their cumulative effect as quality.

**Capable**
The application handles its domain with depth and sophistication. Power users discover advanced capabilities; new users find clear paths to productivity. Capability never comes at the cost of approachability.

**Straightforward**
Complexity lives in the engine, not the interface. Users think about their work, not about the application. When something isn't obvious, it's discoverable. When it's discoverable, it's memorable.

**Efficient**
Respects the user's time at every level. Fast to launch, quick to respond, minimal clicks to accomplish tasks. Common actions are effortless; uncommon actions are possible.

### Core Principles

- **Documentation-first development** — Complete clarity before code
- **Quality over speed** — Shipping when ready, not when rushed
- **Completeness over shortcuts** — Finishing the job thoroughly
- **Elegance over cleverness** — Simple solutions that feel inevitable
- **Privacy-respecting** — User data stays with the user
- **AI as amplification** — Technology serves users, not vice versa

---

# Part III: Collaborative Partnership Model

## Integrated Expertise Roles

Horus development is designed as a strategic partnership between human vision and AI capability. Claude assumes the following integrated roles:

**Technical Architect**
Defines system-wide strategy, ensures components work as a coherent whole, anticipates integration challenges, resolves competing constraints.

**Platform Developer**
Designs and implements using Swift, SwiftUI, and Apple frameworks. Maintains production-quality code exemplifying modern Swift practices.

**Swift Expert**
Deep expertise in Swift 6, strict concurrency, async/await patterns, protocol-driven design, and performance optimization.

**UX Designer**
Ensures the application exceeds Apple's Human Interface Guidelines while achieving cutting-edge design quality. Creates experiences where every interaction seems inevitable.

**AI Expert**
Designs intelligent features with transparency and safety. Validates AI outputs, implements fallback mechanisms, prevents hallucinations.

**Data Scientist**
Analyzes document processing patterns, identifies cleaning pipeline edge cases, optimizes heuristics, drives evidence-based improvements.

**Quality Advocate**
Maintains unwavering standards for accessibility, performance, security, and polish throughout development.

### Working Together

- **Alignment before action** — Confirm understanding of objectives before implementing changes
- **Reasoning transparency** — Explain the thinking behind recommendations so learning compounds
- **Proactive problem identification** — Flag concerns early, propose alternatives when better approaches exist
- **Phased implementation** — Break large tasks into completable phases with verification gates
- **Balanced autonomy** — Propose solutions with rationale; implement minor critical issues with explanation

---

# Part IV: Architecture Overview

## System Architecture

Horus follows a layered architecture designed for testability, maintainability, and extensibility:

```
┌─────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                   │
│  Views (SwiftUI) + ViewModels (State Management)        │
├─────────────────────────────────────────────────────────┤
│                    BUSINESS LOGIC LAYER                 │
│  Services: Cleaning, OCR, Claude, Export, etc.          │
├─────────────────────────────────────────────────────────┤
│                    EVOLVED CLEANING PIPELINE             │
│  16-step, 8-phase specialized cleaning services         │
├─────────────────────────────────────────────────────────┤
│                    DATA & INTEGRATION LAYER              │
│  Models, API Clients, Storage (Keychain, UserDefaults)  │
├─────────────────────────────────────────────────────────┤
│                    VALIDATION & DEFENSE LAYER            │
│  Multi-layer validation, boundary detection, heuristics │
└─────────────────────────────────────────────────────────┘
```

## Navigation & Layout Structure

Horus uses a **5-tab, three-column layout** system:

### Tab Navigation
1. **Input Tab** — Document import and OCR processing
2. **OCR Tab** — Raw OCR results and validation
3. **Clean Tab** — Cleaning configuration and processing
4. **Library Tab** — Processed documents and history
5. **Settings Tab** — API keys, preferences, system configuration

### Three-Column Layout
1. **Sidebar** (180-250pt, 200pt ideal) — Navigation tabs, document list, session stats footer
2. **Content Pane** (400pt minimum) — Main view area with consistent TabHeader/TabFooter framing
3. **Inspector** (300-580pt, 470pt ideal) — Context-aware metadata, details, configuration, actions

### Window Configuration
- **Minimum size:** 1110 × 600 points
- **Ideal size:** 1400 × 800 points
- **Inspector toggle:** ⌥⌘I (Option-Command-I)
- **Inspector hidden:** For Settings tab (full-width content)

### Keyboard Shortcuts (HorusCommands)
| Category | Shortcut | Action |
|:---------|:---------|:-------|
| File | ⌘N | New Session |
| File | ⌘O | Add Documents |
| Export | ⌘E | Export Selected |
| Export | ⇧⌘E | Export All |
| Export | ⇧⌘C | Copy to Clipboard |
| Edit | ⌫ (Delete) | Delete Selected |
| Edit | ⌘⌫ | Clear Queue |
| Edit | ⇧⌘⌫ | Clear Library |
| Process | ⌘R | Process All |
| Process | ⇧⌘R | Process Selected |
| Process | ⇧⌘P | Resume/Pause |
| Process | ⌘. | Cancel Processing |
| Clean | ⌘K | Clean Selected |
| Library | ⌘L | Add to Library |
| Library | ⌘3 | Go to Library |
| View | ⌘1–4 | Switch tabs (Input, OCR, Clean, Library) |
| View | ⌥⌘I | Toggle Inspector |

This layout scales elegantly from compact to ultra-wide displays while maintaining usability on all screen sizes.

## State Management via @Observable

The application uses Swift's `@Observable` macro for reactive state management:

```swift
@Observable
final class AppState {
    // Global state for documents, sessions, API keys, preferences
    var documents: [Document]
    var currentSession: ProcessingSession?
    var apiKeys: APIKeyManager
    var preferences: UserPreferences

    // Service coordination
    let ocrService: OCRService
    let claudeService: ClaudeService
    let cleaningService: CleaningService
    let documentService: DocumentService
}
```

Services are injected through the environment rather than created globally, enabling:
- Easy testing with mock services
- Clear dependency tracking
- Flexible service lifecycle management

## The Evolved Cleaning Pipeline (V3 Architecture)

The cleaning pipeline represents Horus's core competitive advantage—a sophisticated 16-step process organized into 8 conceptual phases:

### 8 Pipeline Phases

**Phase 0: Reconnaissance**
Analyze document structure, detect boundaries, identify document type and patterns.

**Phase 1: Metadata Extraction**
Extract author, title, publication date, and other metadata for preservation.

**Phase 2: Semantic Cleaning**
Remove page numbers, headers, footers, and other per-page artifacts.

**Phase 3: Structural Cleaning**
Identify and remove front matter, back matter, table of contents, and indexes.

**Phase 4: Reference Cleaning**
Handle auxiliary lists, citations, footnotes, and endnotes intelligently.

**Phase 5: Finishing**
Normalize special characters, fix encoding issues, clean whitespace.

**Phase 6: Optimization**
Reflow text, optimize paragraph breaks, enhance readability.

**Phase 7: Assembly**
Add structural markup (Markdown headers, sections, lists).

**Phase 8: Final Review**
Quality assessment, confidence scoring, validation against original.

### Multi-Layer Defense System

The pipeline implements a defensive architecture preventing catastrophic content loss. This system was designed after a critical incident where incorrect boundary detection nearly deleted 99% of a document's content:

**Phase A: Boundary Validation (BoundaryValidator)**
Validates detected boundaries against position constraints, size limits, and confidence thresholds. Section-specific rules prevent dangerous removals — for example, back matter must start at ≥50% of the document, front matter must end by ≤40%, index must start at ≥60%. Each section type has calibrated maximum removal percentages and minimum confidence scores.

**Phase B: Content Verification (ContentVerifier)**
Verifies that content at detected boundaries matches expected patterns for that section type. Back matter should contain headers like NOTES, APPENDIX, GLOSSARY (multi-language: EN, ES, FR, DE, PT). Index sections should contain alphabetized entries with page numbers. Front matter should contain copyright notices, ISBNs, or publisher information. Critically, Phase B rejects boundaries where chapter headings appear in what was identified as back matter.

**Phase C: Heuristic Boundary Detection (HeuristicBoundaryDetector)**
AI-independent fallback using weighted pattern matching. Scans for structural markers (Markdown headers, known section titles) with confidence weights (0.7–1.0). Applies the same position constraints as Phase A. Activated only when Phase A or B rejects the AI-detected boundary.

**Conservative Default:** If all three phases fail to validate a boundary, no removal occurs — content is preserved rather than risked. This "when in doubt, keep it" philosophy is central to Horus's reliability.

---

# Part V: Technology Stack

## Core Technologies

**Language & Concurrency**
- Swift 6.0 with strict concurrency checking enabled
- async/await for asynchronous operations
- @MainActor for UI thread coordination
- Actor model for isolated state management

**User Interface**
- SwiftUI as primary UI framework
- Selective AppKit integration for advanced features (toolbar customization, services)
- Dynamic Type support for accessibility
- VoiceOver testing for vision accessibility

**Networking & API Integration**
- URLSession for native HTTP client
- Mistral AI OCR API for text extraction
- Claude API for intelligent content cleaning
- Custom error handling for resilient API operations

**Data Storage**
- Keychain for sensitive data (API keys, tokens)
- UserDefaults for application preferences and settings
- FileManager for document storage
- Core Data optional for future feature expansion

**Testing**
- Swift Testing framework (native to Swift 6)
- Unit tests for services and models
- UI tests for critical workflows
- Corpus-based testing for cleaning pipeline validation

**Logging & Diagnostics**
- OSLog for system-level logging
- Structured logging with subsystems and categories
- Performance metrics via PipelineTelemetryService

**PDF & Document Handling**
- PDFKit for PDF rendering and information extraction
- Vision framework for image processing
- Custom document format handlers

---

# Part VI: Code Organization

## Project Structure

```
Horus/
├── App/
│   ├── HorusApp.swift              # App entry point, scene setup
│   ├── AppState.swift              # Global @Observable state
│   └── Horus.entitlements          # Sandbox entitlements
│
├── Core/
│   ├── Errors/
│   │   ├── HorusError.swift        # Top-level error types
│   │   └── CleaningError.swift     # Cleaning-specific errors
│   │
│   ├── Models/
│   │   ├── APIModels/
│   │   │   ├── ClaudeAPIModels.swift
│   │   │   └── OCRAPIModels.swift
│   │   ├── CleaningModels/         # 17+ model files
│   │   │   ├── ContentType.swift
│   │   │   ├── CleaningConfiguration.swift
│   │   │   ├── CleaningStep.swift
│   │   │   ├── CleaningProgress.swift
│   │   │   ├── PipelinePhase.swift
│   │   │   ├── DocumentMetadata.swift
│   │   │   ├── AccumulatedContext.swift
│   │   │   ├── StructureHints.swift
│   │   │   ├── DetectedPatterns.swift
│   │   │   ├── CitationTypes.swift
│   │   │   ├── FootnoteTypes.swift
│   │   │   ├── AuxiliaryListTypes.swift
│   │   │   ├── ChapterMarkerStyle.swift
│   │   │   ├── EndMarkerStyle.swift
│   │   │   ├── ContentTypeFlags.swift
│   │   │   ├── PresetType.swift
│   │   │   └── CleanedContent.swift
│   │   └── Core Models/
│   │       ├── Document.swift
│   │       ├── DocumentStatus.swift
│   │       ├── DocumentWorkflowStage.swift
│   │       ├── OCRResult.swift
│   │       ├── ProcessingSession.swift
│   │       ├── ExportFormat.swift
│   │       ├── TokenEstimator.swift
│   │       └── UserPreferences.swift
│   │
│   ├── Services/
│   │   ├── Core Services/          # 13 service files
│   │   │   ├── OCRService.swift
│   │   │   ├── ClaudeService.swift
│   │   │   ├── CleaningService.swift
│   │   │   ├── DocumentService.swift
│   │   │   ├── ExportService.swift
│   │   │   ├── KeychainService.swift
│   │   │   ├── APIKeyValidator.swift
│   │   │   ├── NetworkClient.swift
│   │   │   ├── PatternDetectionService.swift
│   │   │   ├── TextProcessingService.swift
│   │   │   ├── CostCalculator.swift
│   │   │   ├── ThumbnailCache.swift
│   │   │   └── MockClaudeService.swift
│   │   │
│   │   └── EvolvedCleaning/        # 12 specialized pipeline services
│   │       ├── EvolvedCleaningPipeline.swift    # Orchestrator
│   │       ├── ReconnaissanceService.swift      # Phase 0
│   │       ├── BoundaryDetectionService.swift   # Boundary detection
│   │       ├── EnhancedReflowService.swift      # Phase 6
│   │       ├── ParagraphOptimizationService.swift
│   │       ├── FinalReviewService.swift         # Phase 8
│   │       ├── PatternExtractor.swift
│   │       ├── ConfidenceTracker.swift
│   │       ├── PipelineTelemetryService.swift
│   │       ├── PromptManager.swift
│   │       ├── PromptTemplate.swift
│   │       ├── ReconnaissanceResponseParser.swift
│   │       └── [Additional phase services]
│   │
│   └── Utilities/
│       ├── DesignConstants.swift   # Single source of design truth
│       ├── BoundaryValidation.swift
│       ├── ContentVerification.swift
│       ├── HeuristicBoundaryDetection.swift
│       └── Extensions/
│           ├── Accessibility.swift
│           └── Notifications.swift
│
├── Features/                        # Feature modules (MVVM)
│   ├── Cleaning/
│   │   ├── ViewModels/             # CleaningViewModel.swift
│   │   └── Views/                  # CleaningView.swift + subviews
│   ├── DocumentQueue/
│   │   └── ViewModels/
│   ├── Export/
│   │   ├── ViewModels/
│   │   └── Views/
│   ├── Library/
│   │   └── Views/
│   ├── MainWindow/
│   │   └── Views/                  # Window chrome, tab bar
│   ├── OCR/
│   │   └── Views/
│   ├── Onboarding/
│   │   └── Views/
│   ├── Processing/
│   │   └── ViewModels/
│   ├── Queue/
│   │   └── Views/
│   └── Settings/
│       └── Views/
│
├── Shared/
│   └── Components/                 # 6 reusable UI components
│       ├── InspectorCard.swift
│       ├── InspectorRow.swift
│       ├── InspectorSectionHeader.swift
│       ├── TabHeaderView.swift
│       ├── TabFooterView.swift
│       ├── ContentHeaderView.swift
│       ├── DocumentListRow.swift
│       └── PipelineStatusIcons.swift
│
├── UI/
│   └── Components/Cleaning/        # 7 cleaning-specific UI components
│       ├── CleaningProgressView.swift
│       ├── BoundaryVisualization.swift
│       ├── DiffPreview.swift
│       └── [Additional specialized components]
│
└── Resources/
    ├── Assets.xcassets
    └── Documentation guides
```

## Organization Principles

1. **Core** contains all business logic, models, and services
2. **Features** contains UI layer (Views + ViewModels) organized by feature
3. **Shared** contains reusable components used across features
4. **EvolvedCleaning** contains the specialized pipeline services
5. **Services** use protocol-driven interfaces enabling testing

---

# Part VII: Design System

## 4-Point Base Grid

All spacing follows a 4-point base grid for visual harmony:

| Token | Value | Usage |
|:------|:------|:------|
| `xs` | 4pt | Tight spacing between closely related elements |
| `xsm` | 6pt | Compact spacing for nested content |
| `sm` | 8pt | Small spacing between related elements |
| `md` | 12pt | Medium spacing, standard padding |
| `lg` | 16pt | Large spacing between sections |
| `xl` | 20pt | Extra large for major separations |
| `xxl` | 24pt | Maximum spacing for distinct sections |

## Layout Dimensions

| Element | Specification |
|:--------|:--------------|
| Header height | 96pt (all tab file list and content panes) |
| Footer height | 36pt |
| File list width | 220-320pt |
| Content pane minimum | 400pt |
| Inspector width | 300-580pt (470pt ideal) |
| Sidebar width | 180-250pt (200pt ideal) |

## Corner Radii

| Token | Value | Usage |
|:------|:------|:------|
| `xs` | 3pt | Small badges, inline elements |
| `sm` | 4pt | Buttons, text fields |
| `md` | 6pt | Cards, list rows |
| `lg` | 8pt | Panels, containers |
| `xl` | 12pt | Modal sheets, popovers |
| `xxl` | 16pt | Onboarding cards, hero elements |

## Animation Durations

| Token | Value | Usage |
|:------|:------|:------|
| `fast` | 0.15s | Hover states, button press feedback |
| `standard` | 0.2s | View transitions, state changes |
| `slow` | 0.3s | Sheet presentations, major transitions |

## Shadow System

| Token | Parameters | Usage |
|:------|:-----------|:------|
| `subtle` | (color: 0.08 opacity, radius: 2, x: 0, y: 1) | List rows, cards |
| `medium` | (color: 0.12 opacity, radius: 4, x: 0, y: 2) | Elevated panels, popovers |
| `strong` | (color: 0.16 opacity, radius: 8, x: 0, y: 4) | Modal sheets, floating elements |

## Typography

- **Font Family** — System San Francisco exclusively
- **Weight Hierarchy** — Semibold for headers, regular for body, light for secondary
- **Size Range** — 10-15pt for UI text (10pt secondary, 13pt standard, 15pt headers)
- **Named Styles** — headerTitle, documentName, searchField, badge, emptyState (all defined in DesignConstants.Typography)
- **Line Heights** — 1.4x for body text, 1.2x for headers
- **Letter Spacing** — No custom spacing; rely on font metrics

## Semantic Color System

- **Primary Text** — `.primary` for main content
- **Secondary Text** — `.secondary` for supporting information
- **Accent Color** — System accent, tab-specific overrides available
- **Backgrounds** — System backgrounds with appropriate contrast
- **WCAG Compliance** — All color combinations maintain WCAG 2.1 AA contrast

**Tab-Specific Accent Colors:**
- Input Tab: Blue (document import and queue management)
- OCR Tab: Blue (OCR processing, shares input color family)
- Clean Tab: Purple (cleaning pipeline operations)
- Library Tab: Green (completed documents, success state)
- Settings Tab: Gray (system configuration)

## Component Architecture

Reusable components live in `Shared/Components/`:

| Component | Purpose |
|:----------|:--------|
| `InspectorComponents` | Inspector building blocks: `InspectorCard` (container with consistent styling), `InspectorRow` (label-value pairs), `InspectorSectionHeader` (section dividers with optional disclosure) |
| `TabHeaderView` | Consistent headers across all tab views with title, icon, and optional actions |
| `TabFooterView` | Consistent footers with document counts, cost stats, and action buttons |
| `ContentHeaderView` | Headers for main content areas with document info and tab-specific context |
| `DocumentListRow` | Document entries with filename, status badge, page count, cost, and pipeline progress icons |
| `PipelineStatusIcons` | Visual status indicators for the three processing stages (OCR → Clean → Library) with color-coded states |

**Component Principles:**
- Extract patterns used in 2+ places
- Parameterize for flexibility without over-engineering
- Maintain consistency through shared design constants
- Include comprehensive SwiftUI Previews
- Document component props and behavior

## Design Constants

All design values centralize in `DesignConstants.swift`:

```swift
// Access like:
Text("Something")
    .padding(DesignConstants.Spacing.md)
    .font(.system(size: DesignConstants.Typography.bodySize))
    .foregroundColor(DesignConstants.Colors.primary)
```

This single source of truth enables:
- Instant theme updates across the entire application
- Consistent spacing and typography
- Easy refactoring of visual language
- Clear design intent documentation

---

# Part VIII: Quality Standards

## Performance Targets

| Metric | Target |
|:-------|:-------|
| Launch time | < 2 seconds |
| View transitions | < 300ms animations |
| List scrolling | 60fps (no stuttering) |
| API operations | Show progress for > 500ms |
| Memory usage (idle) | < 100MB |
| Memory usage (processing) | < 500MB for typical documents |

## Test Coverage

- **Core Services** — 80%+ coverage (OCR, Claude, Cleaning)
- **Models** — 70%+ coverage
- **Critical Paths** — 100% coverage (authentication, data loss prevention)
- **UI Logic** — Key view models tested via snapshot testing

## Build Quality

- **Zero Compiler Warnings** — All warnings treated as errors
- **Swift Concurrency** — Strict checking enabled, no race conditions
- **Memory Leaks** — Regular profiling with Instruments
- **Code Analysis** — Xcode static analyzer passing

## Accessibility Standards

- **VoiceOver Support** — All interactive elements properly labeled
- **Keyboard Navigation** — Tab order logical, all actions keyboard-accessible
- **Dynamic Type** — All text respects system text size preferences
- **Color Contrast** — WCAG 2.1 AA standard minimum
- **Motion** — Respect `UIAccessibility.isReduceMotionEnabled`

---

# Part IX: Session Continuity Protocol

## Documentation as Continuity

Rather than relying solely on memory, continuity comes through systematic documentation:

### Session Summaries

At the end of each development session:

1. **What was accomplished** — Specific files changed, features implemented
2. **What remains** — Tasks not completed, blockers encountered
3. **Architecture decisions** — Any patterns established or changed
4. **Test results** — Coverage gained, any failures discovered
5. **Next steps** — Clear continuation point for next session

### Progress Tracking

Maintain a session log capturing:
- Date and scope of work
- Files modified
- Architecture decisions made
- Integration points verified
- Quality gates passed/failed

### Decision Log (ADRs)

Record architectural decisions with:
- **Decision** — What was chosen and why
- **Alternatives** — What other options existed
- **Tradeoffs** — What was gained and lost
- **Date** — When the decision was made
- **Status** — Active, superseded, or deprecated

### Documentation Regeneration

After each major iteration:
1. Update relevant specifications
2. Refresh code organization section with actual file list
3. Update architecture diagrams if structure changed
4. Verify all code samples match current implementation
5. Add any new patterns or lessons learned

---

# Part X: Development Methodology

## 9-Phase Development Lifecycle

All non-trivial features follow this lifecycle:

### Phase 1: Ideation
- Define the problem or opportunity
- Explore the user need
- Identify success metrics
- **Output:** Clear problem statement

### Phase 2: Framing
- Define scope and constraints
- Outline the solution approach
- Identify dependencies
- **Output:** Solution frame, impact analysis

### Phase 3: Documentation
- Write complete specifications
- Design data models
- Plan implementation sequence
- **Output:** Technical specification

### Phase 4: Implementation
- Code the solution
- Build one component at a time
- Verify each integration point
- **Output:** Working code with verification

### Phase 5: Verification
- Unit test the functionality
- Integration test with related systems
- Verify against specification
- **Output:** Passing tests, verified integration

### Phase 6: Testing
- UI/UX testing
- Edge case testing
- Performance testing
- **Output:** Validated user experience

### Phase 7: Iteration
- Address findings from testing
- Refine based on feedback
- Polish edge cases
- **Output:** Production-ready implementation

### Phase 8: Publishing
- Merge to main branch
- Update documentation
- Release or deploy
- **Output:** Shipped feature

### Phase 9: Regeneration
- Update foundational documentation
- Record decisions and patterns
- Plan future improvements
- **Output:** Updated documentation for next cycle

## Phased Implementation Strategy

For large tasks, proactively segment into phases:

**Phase Planning:**
1. Analyze total scope
2. Identify natural stopping points
3. Define verification criteria for each phase
4. Estimate time for each phase
5. Plan integration verification

**Phase Execution:**
1. Implement specific scope
2. Verify completion of phase tasks
3. Verify integration with previous phases
4. Move to next phase or pause

**Timeout Risk Management:**
- Estimate buffer for contingencies
- Identify which phases are most critical
- Plan for lower-risk phases if running low on time
- Document what to prioritize if interrupted

---

# Part XI: Communication Guidelines

## Change Communication

When implementing changes:

1. **State what is being changed** — Clear description of modifications
2. **Explain why** — Rationale for the approach
3. **Note deviations** — Any departures from requested approach with reasoning
4. **Highlight decisions** — Anything requiring attention or approval
5. **Summarize impact** — What was accomplished, what remains

## Technical Opinion Sharing

### Immediate Relevance
When an issue directly affects current work, raise it immediately and address it.

### Future Consideration
When an improvement isn't urgent, note it briefly in a comment or follow-up without derailing current focus.

### Backlog Tracking
For architectural improvements requiring dedicated effort, suggest adding to a tracked improvement backlog.

## Constructive Challenge

When better approaches exist:
1. Propose the alternative with rationale
2. Highlight advantages and any drawbacks
3. Leave the final decision to the developer
4. Support whichever direction is chosen

---

# Part XII: Quick Reference Guide

## Key Development Principles

1. **Align before implementing** — Confirm understanding of objectives before coding
2. **Segment proactively** — Break large tasks into completable phases
3. **Verify at gates** — Check phase completion AND cross-file integration
4. **Analyze holistically** — Consider primary, secondary, tertiary impacts
5. **Reference DesignConstants** — Use centralized design values, never hardcode
6. **Document changes** — Update headers, specs, session logs
7. **Test edge cases** — Empty, boundary, error, interruption scenarios
8. **Never block main thread** — All heavy work goes to background async
9. **Preserve patterns** — Maintain consistency unless explicitly improving
10. **Flag early** — Raise concerns before they become problems

## File Organization Quick Ref

| Purpose | Location |
|:--------|:---------|
| New service | `Core/Services/` |
| New model | `Core/Models/` |
| New view | `Features/[Feature]/Views/` |
| New view model | `Features/[Feature]/ViewModels/` |
| Shared component | `Shared/Components/` |
| Design constant | `Core/Utilities/DesignConstants.swift` |
| Error type | `Core/Errors/` |
| Utility function | `Core/Utilities/Extensions/` or `Core/Utilities/` |

## Common Tasks

**Add a new feature:**
1. Create `Features/FeatureName/` directory
2. Add `Views/` and `ViewModels/` subdirectories
3. Create view and view model files
4. Create associated models in `Core/Models/`
5. Create services in `Core/Services/` if needed
6. Wire into AppState and navigation

**Add a new service:**
1. Define protocol in `Core/Services/`
2. Implement service class
3. Add to AppState injection
4. Create mock for testing
5. Add unit tests

**Add a design constant:**
1. Add to appropriate section in `DesignConstants.swift`
2. Update any hardcoded values to use the constant
3. Document the purpose of the constant

---

# Part XIII: Current Project State (V2/V3)

## Implemented Features

### Core Application
- Five-tab navigation system (Input, OCR, Clean, Library, Settings)
- Three-column layout with sidebar, content, inspector
- Document import via drag-and-drop and file selection
- Document library with filtering and search

### OCR Processing
- Mistral AI OCR integration
- Per-page progress tracking
- Batch processing with queue management
- Raw OCR result preview
- OCR result validation and review

### Cleaning Pipeline
- **16-step process** organized into **8 logical phases**
- Reconnaissance (structure analysis)
- Metadata extraction
- Semantic cleaning (page numbers, headers, footers)
- Structural cleaning (front/back matter, TOC, index)
- Reference cleaning (citations, footnotes, auxiliary lists)
- Finishing (special characters, encoding)
- Optimization (reflow, paragraph optimization)
- Assembly (structural markup)
- Final review (quality assessment)

### Multi-Layer Validation
- Heuristic boundary detection (statistical, pattern-based)
- AI-powered validation (Claude service confirmation)
- Content verification (retention ratio calculation)
- Defensive fallbacks (heuristic→AI→fallback chain)

### Export System
- Multiple format support (Markdown, JSON, plain text)
- Individual and batch export
- Custom naming conventions
- Configurable export options

### API Integration
- Mistral OCR authentication and request handling
- Claude API for cleaning and validation
- API key management via Keychain
- Rate limiting and retry strategies
- Cost estimation for API operations

### Settings & Preferences
- API key configuration
- Processing preferences
- Export format defaults
- Display preferences (theme, text size)

## Known Limitations & Future Work

1. **Large document handling** — Memory optimization for 500MB+ documents
2. **Batch operations** — Enhanced queue management for 100+ documents
3. **Custom cleaning profiles** — User-defined cleaning presets
4. **Integration extensions** — Services menu integration
5. **Cloud sync** — Optional iCloud sync for library
6. **Performance profiling** — Further optimization of cleaning pipeline

---

# Part XIV: Architecture Evolution

## What Makes Horus Unique

The evolved V3 cleaning pipeline represents years of document processing research condensed into 16 strategic operations:

- **Reconnaissance** establishes ground truth about document structure
- **Multi-layer defense** prevents content loss through validation chains
- **Heuristic + AI hybrid** combines statistical analysis with language understanding
- **Confidence tracking** quantifies reliability of each operation
- **Content verification** ensures output quality against input
- **Graceful degradation** falls back to heuristics when AI is uncertain

## Design Patterns in Use

**MVVM with @Observable** — State management via Swift's native observable macro

**Protocol-Driven Services** — All services define protocols enabling testing

**Dependency Injection** — Services injected through environment, not singletons

**Async/Await** — Modern concurrency throughout, no callbacks

**Custom Error Types** — Domain-specific errors enabling rich error handling

**Builder Pattern** — Complex objects (CleaningConfiguration) built step-by-step

**Strategy Pattern** — Different cleaning strategies per document type

**Decorator Pattern** — Enhancement of content through pipeline phases

---

# Part XV: Getting Started

## For New Developers

1. Read Part I (Project Identity) to understand what Horus does
2. Read Part II (Development Philosophy) to understand how we work
3. Review the Code Organization (Part VI) to understand where things live
4. Read the relevant feature specification document
5. Start with small, isolated tasks to build familiarity
6. Always verify understanding before implementing

## For Maintenance Work

1. Review the session logs to understand recent changes
2. Check the decision log for related architectural choices
3. Read relevant code comments and specs before modifying
4. Verify integration points after making changes
5. Update documentation to reflect any changes
6. Document your changes in session summary

## For Adding Features

1. Start with the 9-phase lifecycle (Part X)
2. Complete documentation phase before implementation
3. Segment implementation into manageable phases
4. Verify each phase completion
5. Test thoroughly before considering done
6. Update foundational documentation after completion

---

# Part XVI: Bibliography & References

**Related Documentation:**
- `01-PRD-Horus.md` — Product requirements and feature specifications
- `02-Technical-Architecture-Horus.md` — System architecture and design
- `03-OCR-Processing-Architecture-Horus.md` — Mistral OCR subsystem deep-dive
- `04-CLEAN-Processing-Architecture-Horus.md` — Cleaning pipeline architecture deep-dive
- `05-CLEAN-Processing-Workflow-Horus.md` — Step-by-step pipeline workflow walkthrough
- `06-Cleaning-Feature-Specification.md` — Feature specification for the cleaning system
- `07-API-Integration-Guide-Horus.md` — Mistral and Claude API integration details
- `08-UI-UX-Specification-Horus.md` — Interface design and interaction patterns
- `09-Implementation-Guide-Horus.md` — Complete rebuild guide from zero

**Apple Frameworks & Guidelines:**
- Swift 6 Language Guide
- SwiftUI Documentation
- Human Interface Guidelines (macOS)
- Accessibility Guidelines

**External Resources:**
- Mistral AI Documentation (OCR API)
- Claude API Documentation (Messaging API)
- Keychain Services Programming Guide

---

# Appendix A: Glossary

**Boundary Detection** — AI-powered identification of where main content begins/ends within document structure

**Scaffolding Content** — Front matter, back matter, TOC, indexes—supportive but not core narrative

**Content Verification** — Comparing cleaned output against original to calculate retention ratios and detect anomalies

**Confidence Score** — Numerical assessment (0-1) of reliability for a specific cleaning operation

**Heuristic** — Statistical pattern matching approach that doesn't require AI

**Multi-Layer Defense** — Validation chains (heuristic→AI→fallback) preventing catastrophic content loss

**Reconnaissance** — Initial document analysis phase establishing structure and patterns

**Token Estimation** — Calculating API costs based on document length

---

# Appendix B: Development Environment Setup

**Required Tools:**
- Xcode 16+ (latest stable release)
- Swift 6.0
- Git and GitHub CLI
- Claude (via Claude.ai or Claude Code)

**Optional Tools:**
- Instruments (profiling)
- Accessibility Inspector
- SF Symbols
- Color UI

**Configuration:**
1. Clone the Horus repository
2. Install dependencies (if any Swift Package dependencies)
3. Configure API keys in Settings (Mistral and Claude)
4. Run tests to verify environment
5. Review DesignConstants.swift for design values

---

*Blueprint Version 5.0*
*Updated February 2026 to document V2/V3 evolved pipeline architecture*
*Reflects current project state with 16-step cleaning pipeline, three-column layout, and dual-API integration*
*Designed for AI-assisted macOS application development with Claude*
