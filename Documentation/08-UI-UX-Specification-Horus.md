# Horus — UI/UX Specification

**Version:** 3.0
**Last Updated:** February 2026
**Status:** Current Implementation Reference

---

## Executive Overview

Horus is a macOS document processing platform that guides users through a transparent, confidence-building pipeline: Import → OCR → Clean → Library → Export. This specification documents the current UI/UX implementation that prioritizes user clarity, trust, and natural interaction patterns consistent with Apple's design philosophy.

The application is built on a modular component architecture with SwiftUI, employing a three-column layout (sidebar navigation, content area, inspector panel) that adapts contextually to each processing stage. The design system emphasizes semantic meaning, visual hierarchy, and performance optimization through virtualization and asynchronous processing patterns.

---

## 1. Design Philosophy

### 1.1 Core Principles

Horus operates on five foundational design principles that inform every UI/UX decision:

**Transparency** — Users maintain constant visibility into application state, processing progress, and financial costs. Every action provides immediate feedback. Progress indicators are phase-aware, showing not just percentage completion but current step context. Cost calculations appear before processing begins, with real-time updates during API operations.

**Flow** — The interface naturally guides users through the document pipeline in logical sequence. Each tab builds on the previous stage's output. Visual design reinforces this progression through directional cues, status badges, and navigation affordances that make the next step intuitively obvious.

**Native** — The application feels like it was designed by Apple, not retrofitted to macOS. This means exclusive use of system fonts (San Francisco), semantic color tokens (Blue for Input/OCR, Purple for Clean, Green for Library, Gray for Settings), platform-standard controls, and adherence to Human Interface Guidelines. No custom chrome, no design system friction.

**Confidence** — Users trust Horus because the interface removes uncertainty. Preview systems show cleaned content before export. Cancel operations are always available. Content type auto-detection surfaces confidence scores. Cleaning presets indicate their suitability. Error states provide recovery paths. The system never surprises the user with unexpected modifications or hidden costs.

**Focus** — Every interface element earns its place. Toolbar buttons appear contextually based on document state. Inspector sections collapse and expand based on relevance. Empty states guide users toward productive actions. Settings are organized into logical domains. Visual clutter is eliminated through lazy loading and dynamic content revelation.

---

## 2. Application Structure

### 2.1 Overall Architecture

Horus employs a sophisticated three-panel layout pattern implemented through NavigationSplitView and HSplitView, creating a flexible, resizable interface that adapts to workflow needs:

```
┌─────────────────────────────────────────────────────────┐
│                      Toolbar (context-aware)             │
├──────────┬──────────────────────────────────┬────────────┤
│          │                                  │            │
│  Sidebar │         Content Area             │ Inspector  │
│  (Fixed) │      (Tab-specific)              │ (Conditional)
│          │                                  │            │
│ • Input  │ [Dynamic content per tab]        │ • Metadata │
│ • OCR    │                                  │ • Stats    │
│ • Clean  │                                  │ • Actions  │
│ • Library│                                  │ • Controls │
│ • Settin │                                  │            │
│          │                                  │            │
└──────────┴──────────────────────────────────┴────────────┘
```

### 2.2 Main Window Structure

**MainWindowView** (372 lines) serves as the master container, coordinating:
- NavigationSidebarView (sidebar with five primary navigation items)
- ContentAreaView (swaps dynamically based on selectedTab)
- InspectorView (appears/disappears based on tab requirements)
- Toolbar with context-aware actions
- Sheet presentations for modals (export, cost confirmation, onboarding)

Layout:
```swift
NavigationSplitView {
    NavigationSidebarView()  // Left column (fixed width)
} detail: {
    HSplitView {
        ContentAreaView()     // Center (flexible)
        InspectorView()       // Right (conditional)
    }
}
```

Window constraints:
- **minWidth:** 1110
- **idealWidth:** 1400
- **minHeight:** 600
- **idealHeight:** 800

The sidebar uses NavigationSplitViewStyle with fixed width and maintains selection state through AppState.selectedTab. The center content area is wrapped in a ScrollView where appropriate, with LazyVStack for large document lists. The right inspector panel uses conditional rendering, hidden entirely on Settings tab.

**MainWindowView** also manages:
- Sheet state for export dialogs
- Confirmation dialogs for destructive actions
- Onboarding presentation on first launch
- Alert handling and error recovery notifications

### 2.3 Navigation Pattern

Five-tab navigation represents the application's core workflow. The `NavigationTab` enum defines:

```swift
enum NavigationTab: String, CaseIterable {
    case input, ocr, clean, library, settings

    var label: String { "Input", "OCR", "Clean", "Library", "Settings" }
    var icon: String { /* system image names */ }
}
```

**Tab Specifications:**

1. **INPUT** (Blue, arrow.down.doc) — Document ingestion, queue management, workflow stage tracking
   - Drag-and-drop import zone
   - Document queue organized by workflow stage
   - Inspector: File details, status, action buttons (Remove, Clear, Start OCR)

2. **OCR** (Blue, text.viewfinder) — OCR processing orchestration, progress monitoring, results preview
   - Document table with processing status
   - Page preview with navigation
   - Inspector: Metadata, statistics, cost, actions (Retry, Cancel, Export)

3. **CLEAN** (Purple, sparkles) — Content refinement, quality review, multi-phase processing
   - Document selector dropdown
   - Original/Cleaned content preview (VirtualizedTextView)
   - Inspector: Content type selector, preset, pipeline steps, statistics, export

4. **LIBRARY** (Green, books.vertical) — Document browsing, preview rendering, export staging
   - Finder-style three-column: filters, document list, preview
   - Search and filtering
   - Context menu: Clean, Export, Copy, Show in Finder, Delete, Duplicate

5. **SETTINGS** (Gray, gear) — Configuration, API keys, application preferences
   - Subtabs: API Keys, Cleaning, Export, About
   - No inspector panel (full width content)

**State Management:**

Tab selection persists across sessions via `AppState.selectedTab`. The current tab determines:
- ContentAreaView which view to display
- InspectorView which sections to show
- NavigationSidebarView which tab is highlighted

Badge counts appear per tab:
- Input: pending + processing + failed
- OCR: documents awaiting library addition
- Library: total documents in library
- Clean: documents ready for cleaning

Keyboard shortcuts enable rapid tab switching:
- ⌘1: Input (⌘O pattern for import)
- ⌘2: OCR (⌘R pattern for resume)
- ⌘3: Clean (⌘K pattern for keyboard)
- ⌘4: Library
- ⌘5: Settings (⌘, convention)

---

## 3. Design System (DesignConstants.swift)

### 3.1 Spacing Grid

Horus employs a 4-point base spacing system, creating a mathematical foundation for consistent layouts:

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4pt | Tight spacing between closely related elements (e.g., icon and label) |
| xsm | 6pt | Compact spacing for dense information displays |
| sm | 8pt | Small spacing between related sections (e.g., between form fields) |
| md | 12pt | Standard padding for views, margins between elements |
| lg | 16pt | Spacing between distinct content sections |
| xl | 20pt | Major separations (e.g., between cards, panels) |
| xxl | 24pt | Distinct section boundaries |

Spacing is applied consistently across all components through `.padding()` modifiers using these named constants, creating visual rhythm and scanability.

### 3.2 Typography

**Font Family:** San Francisco exclusively (system-provided)
**UI Range:** 10–15pt, respecting Dynamic Type through `.font(.system(.headline))` patterns
**Hierarchy:**
- Titles: 16–18pt, semibold
- Body: 12–14pt, regular
- Captions: 10–12pt, medium/regular

Typography always respects system Dynamic Type settings. Users with vision accessibility needs can scale text up to 200%, and the interface must remain functional and legible at all scales. Use SwiftUI's semantic font styles (.title, .headline, .body, .caption) rather than fixed point sizes where possible.

### 3.3 Color System

Colors follow Apple's semantic color model with tab-specific accent colors:

**Semantic Base Colors:**
- Background: `.background` (system-managed, light/dark adaptive)
- Secondary Background: `.secondarySystemBackground`
- Tertiary Background: `.tertiarySystemBackground`
- Label: `.label` (primary text), `.secondaryLabel` (secondary text), `.tertiaryLabel` (tertiary)
- Separator: `.separator` (dividing lines), `.opaqueSeparator` (stronger division)

**Tab Accent Colors:**
- Input/OCR: `.blue` (confidence, activity, primary actions)
- Clean: `.purple` (transformation, processing, refinement)
- Library: `.green` (completion, success, availability)
- Settings: `.gray` (neutrality, configuration)

**Semantic Intent Colors:**
- Success: `.green` (processing complete, valid state)
- Warning: `.orange` (caution, potential issues)
- Error: `.red` (failure, blocked action)
- Info: `.blue` (informational, context)

All colors respect light/dark appearance through semantic tokens. Never use hardcoded RGB values; always derive from `Color` semantic system. This ensures accessibility (sufficient contrast), consistency, and automatic adaptation to system theme changes.

### 3.4 Corner Radius

Consistent corner radius creates visual cohesion:

- **Small (4pt):** Subtle rounding for minor elements (small buttons, compact controls)
- **Medium (6pt):** Standard rounding for buttons, chips, small cards
- **Large (8pt):** Primary controls, modal cards, content containers
- **Card (10pt):** Major content cards, panels, inspector sections

Radius is applied through `.cornerRadius()` modifier, with `.clipShape(RoundedRectangle(cornerRadius: 8))` for precise clipping when needed.

### 3.5 Motion & Animation

Horus uses three animation durations, creating a responsive feel without distraction:

- **Fast (150ms):** Micro-interactions (button press feedback, checkbox toggle, brief hover effects)
- **Standard (200ms):** State transitions (tab switching, view appearance, toolbar actions)
- **Slow (300ms):** Major transitions (modal presentation, inspector panel appearance, processing phase changes)

All animations respect the system Reduce Motion preference through `accessibilityReduceMotion` check. When reduced motion is enabled, animations are either disabled or reduced to 50% of normal duration.

---

## 4. Component Library (Shared/Components)

The component library provides reusable, tested building blocks across all tabs. Each component is self-contained, accepting bindings for state management and closures for user actions.

### 4.1 Tab Infrastructure Components

**TabHeaderView** (basic structure ~30 lines)
- Consistent header across all tab content areas
- Contains: title (16pt, semibold), optional subtitle, search bar (if applicable), action buttons
- Action buttons are context-aware per tab:
  - Input: Add Documents, Import
  - OCR: Start Processing, Pause, Resume, Cancel
  - Clean: Start Cleaning
  - Library: Export, Batch Export
  - Settings: None
- Returns combined height of ~60pt, accounting for subtitle if present

**TabFooterView** (basic structure ~30 lines)
- Status display at bottom of content area
- Shows document counts, processing statistics, cost metrics
- Right-aligned metrics (total files, cleaned count, cumulative cost)
- Updates in real-time as documents are processed
- Optional progress bar for batch operations
- Formatting: "3 of 10 documents | OCR 85% | Clean 40% | Total: $1.23"

**ContentHeaderView** (~50 lines)
- Three-level hierarchical header for detailed content views
- Level 1: File icon + filename (primary, bold)
- Level 2: File type indicator (PDF, DOCX, image) with size
- Level 3: Action buttons, metrics row (page count, word count, confidence)
- Used extensively in OCR and Clean tabs for per-document views

**SessionStatsView** (~40 lines)
- Displays session-level metrics in inspector footer
- Shows: Total Documents, Completed, Failed, Total Cost
- Updates reactively as processing completes
- Shown in Input/OCR tabs, above settings

### 4.2 List Components

**DocumentListRow** (~60 lines)
- Reusable row for document presentation across tabs
- Displays: document icon, filename, file size, processing status badges
- Status badges show pipeline progression:
  - "Ready for OCR", "Processing OCR", "OCR Complete"
  - "Ready to Clean", "Processing", "Cleaned"
  - "In Library"
- Optional trailing metrics (page count, word count, cost, confidence)
- Full row is tappable, triggering document selection for preview
- Implements lazy loading for image thumbnails through onAppear closure
- Used in: Input sidebar, OCR document table, Library document list

**PipelineStatusIcons** (~30 lines)
- Compact visual indicators for document processing state via symbols
- OCR: "○" (pending), "⏳" (processing), "✓" (complete), "!" (failed)
- Clean: "○" (pending), "⏳" (processing), "✓" (complete), "!" (failed), "—" (skipped)
- Badges use system colors: gray (pending), blue (processing), green (complete), red (failed), gray (skipped)
- Used in: Document rows, sidebar, inspector headers

### 4.3 Inspector Components

**InspectorView** (1112 lines total)
- Context-aware right panel with document metadata, statistics, and actions
- Hidden entirely on Settings tab (full width content)
- **InspectorCard** (~40 lines)
  - Container for grouped related inspector content
  - Title bar with optional collapsible toggle
  - Padding and corner radius consistent with design system
  - Shadow for visual separation (light: 0.1 opacity, dark: 0.3 opacity)

- **InspectorRow** (~30 lines)
  - Label-value pair display within inspector cards
  - Left: label (11pt, semibold, .secondaryLabel)
  - Right: value (12pt, regular, .label), clickable for some rows
  - Divider line between rows except last
  - Used for metadata display (words, characters, cost, processing time, confidence)

- **InspectorSectionHeader** (~20 lines)
  - Section divider with optional action button
  - Left: section title (12pt, semibold, .label)
  - Right: optional secondary text or action button
  - Spacing: md above/below

**Tab-Specific Inspector Layouts:**

- **Input Tab Inspector:**
  - Document Info card: filename, pages, size, import date
  - Status card: current stage, ready/processing status
  - Actions: Remove from queue, Clear queue, Start OCR
  - SessionStatsView footer

- **OCR Tab Inspector:**
  - Document Metadata: filename, format, page count, creation date
  - OCR Results: total words, estimated tokens, per-page cost, elapsed time
  - Actions: Retry failed pages, Cancel processing, View all pages, Export to Library
  - Processing progress indicator

- **Clean Tab Inspector:**
  - Identity: document title, content type badge, file size, page count
  - Status: current phase, confidence score, estimated/actual time
  - Content Type Selector: auto-detect or manual override with confidence
  - Preset Selector: dropdown with icon, name, description, "Modified" indicator
  - Pipeline Steps: collapsible by phase, shows all 16 steps with toggles
  - Text Statistics: original/cleaned word count, character count, chunk count
  - Cost: pre-processing estimate, real-time accumulation, post-completion total
  - Actions: Export, Show in Finder, Send Feedback, Report Issue, Results display

- **Library Tab Inspector:**
  - Document Preview Options: Rendered/Raw/Cleaned mode selector
  - Metadata: title, type, size, processing date, confidence
  - Actions: Clean/Re-clean, Export, Copy to Clipboard, Show in Finder, Delete, Duplicate
  - Document Stats: word count, reduction %, processing time

### 4.4 Specialized Clean Tab Components

The Clean tab implements an evolved component architecture supporting phase-aware processing, multi-step pipeline visualization, and real-time progress tracking:

**PresetSelectorView** (~60 lines)
- Dropdown control for cleaning preset selection
- Shows icon, name, brief description
- "Modified" indicator appears when user customizes pipeline steps
- Auto-detection mode shows detected type with confidence percentage
- Selection triggers immediate preset application and pipeline recompilation
- Available presets: Conservative, Balanced, Aggressive, Custom

**ContentTypeSelectorView** (~80 lines)
- Dual-mode control: auto-detect or manual override
- Auto-detect mode displays identified type with confidence score (0–100%)
- Manual override shows picker with 11 content types:
  1. Academic (papers, research, citations)
  2. News (articles, journalism)
  3. Technical (docs, API references)
  4. Business (reports, proposals)
  5. Fiction (novels, narrative)
  6. Legal (contracts, ToS)
  7. Marketing (copy, sales, promotional)
  8. Medical (clinical, research)
  9. Email (messages, correspondence)
  10. Code (source files, scripts)
  11. Generic (fallback, mixed content)
- Type selection recompiles pipeline steps with type-specific configurations

**ContentTypeBadgeView** (~30 lines)
- Small visual badge indicating document content classification
- Displays type name + confidence percentage (e.g., "News 87%")
- Colors align with semantic intent: blue (>85% confidence), orange (50-85%), gray (<50%)
- Used in document list rows and content headers

**PipelinePhaseStepsGroup** (~80 lines)
- Collapsible container for grouped pipeline steps by phase
- 3 phases in V3 pipeline: Normalization, Enhancement, Validation
- Header: phase name, step count, phase status (pending, processing, completed)
- Toggle state persists in AppState.cleaningPhaseStates dictionary
- Body: vertical stack of PipelineStepRow components for each step

**PipelineStepRow** (~100 lines)
- Individual pipeline step visualization
- Left: toggleable checkbox (only for optional steps, locked for required)
- Middle: step name (12pt, .label), brief description (11pt, .secondaryLabel), method badge (AI, Hybrid, Code)
- Right: status indicator with colors (○ gray pending, ⏳ blue processing, ✓ green completed, — gray skipped, ! red failed)
- Tapping expands step details if available
- Status updates in real-time during processing
- All 16 cleaning steps included with proper phase organization

**PhaseAwareProgressView** (~60 lines)
- Enhanced progress bar with phase-specific messaging
- Top: progress bar (0–100%, smooth animation with Reduce Motion respect)
- Bottom: current phase label and step count (e.g., "Enhancement: Step 8 of 16")
- Color follows processing phase: blue (Normalization), purple (Enhancement), green (Validation)
- Updates every 0.5 seconds from ProcessingViewModel
- Shows estimated time remaining if available
- Cancel button overlay for user control

**VirtualizedTextView** (~150 lines)
- Memory-efficient large text display using LazyVStack
- Splits content into 2000-character chunks for rendering
- Each chunk renders as Text view inside HStack with optional line numbers
- Lazy loading ensures only visible chunks are rendered
- Supports two modes: Original (read-only OCR output) vs. Cleaned (with diff highlighting)
- Diff highlighting: additions in green, removals in red strikethrough
- Used in OCR and Clean tabs for document preview
- Handles large documents (100+ pages) efficiently

**CleaningExplainerSheet**
- Educational modal explaining all 16 pipeline steps
- Size: 600×800 (fixed for consistency)
- Content: scrollable list of step cards, each with icon, name, description, example output
- Navigation: Previous/Next buttons or tab selector for quick navigation
- Presentation: sheet modal with large title style
- Dismissal: standard X button (top-right), also dismissible by background tap

**CleanedExportSheetView**
- Export configuration specialized for cleaned documents
- Sections: document selection, format selection, cleaning report toggle
- Cleaning report appears as HTML comment block in markdown export
- Report contents: steps executed, confidence score, reduction percentage, cost
- Preview: small markdown preview of export format
- Actions: Cancel, Export (primary button)

**BetaFeedbackView**
- User feedback submission interface
- Fields: feedback type (bug, feature, general), message (multiline), optional email
- Validation: message must be 10+ characters, email must be valid if provided
- Action: Submit button sends feedback to Horus backend
- Success state: "Thank you! Your feedback helps us improve." message
- Opens in sheet modal

**IssueReporterView**
- Bug/issue reporting interface
- Fields: title, description, reproduction steps, expected vs. actual behavior
- Attachments: optional log export, screenshot
- Validation: title + description required
- Severity selector: Low, Medium, High, Critical
- Action: Submit creates GitHub issue or sends to support email
- Success state: issue tracking number or support ticket

**RecoveryNotificationView**
- Error recovery and notification display
- Styles: info (blue), warning (orange), error (red), success (green)
- Structure: icon + title + description + optional action button
- Position: floating at bottom of view or inline within content
- Dismissal: auto-dismiss after 5 seconds (error states persist until action taken)

**DetailedResultsView**
- Post-cleaning comprehensive statistics display
- Sections: reduction metrics (% reduction, original vs. cleaned word count), token count, cost breakdown, confidence rating
- Visual: compact cards with icon + metric + value
- Timeline: processing duration, per-step timing
- Confidence breakdown: score with visual bar, phrase description ("High Confidence", "Medium Confidence", etc.)
- Share button: exports results as text/JSON

---

## 5. Tab Specifications

### 5.1 INPUT Tab (Blue)

**Purpose:** Document ingestion, queue management, and workflow stage tracking.

**Layout:**
- TabHeaderView: "Input" title, drag-and-drop affordance
- Drag-and-drop zone: prominent visual feedback, accepts PDF, DOCX, DOCM, images, text files
- Document queue organized by workflow stage:
  - "Ready for OCR" section (newly imported)
  - "Waiting for OCR" section (queued)
  - "Processing OCR" section (currently processing, with progress bars)
- Each document shown as DocumentListRow with file size, import date, status

**Inspector Panel:**
- Document details: filename, file type, size, import date, page count
- Current processing status: "Ready to process" or "Processing: Page 3 of 12"
- Actions section: Remove from queue, Clear entire queue, Start OCR processing

**Interaction:**
- Drag files into central zone or click to open file picker
- Click document row to select (optional document-specific view)
- Start OCR button processes entire queue sequentially
- Remove button deletes from queue but not from disk
- Clear button empties queue with confirmation dialog

**Keyboard Shortcuts:**
- ⌘O: Open import file picker
- Delete: Remove selected document from queue

### 5.2 OCR Tab (Blue)

**Purpose:** OCR processing orchestration, progress monitoring, and results preview.

**Layout:**
- Two-column composition: document table (left) + content preview (right)
- Left column: DocumentListRow for each document with processing status
- Right column: Per-document view with page navigation and content preview
- TabFooterView: document count, processing statistics (words, tokens), cumulative cost

**Document-Level Components:**
- Processing progress bar: per-page progression with page count (Page 1 of 12)
- Page navigation: arrows or thumbnail grid to select page
- Content preview: raw OCR output for selected page (VirtualizedTextView in read-only mode)
- Page thumbnails: small preview images enabling quick page selection

**Inspector Panel:**
- Document metadata: filename, format, page count, creation date
- Processing statistics: total words, estimated tokens, processing cost (per page), elapsed time
- Actions: Retry failed pages, Cancel processing, View all pages, Export to Library

**Processing States:**
- Pending: document in queue, not yet started
- Processing: real-time progress per page, animated progress bar
- Completed: all pages processed, content preview available
- Failed: specific page failure with error message, retry option
- Partial: some pages completed, some failed (user can retry failed or proceed)

**Interaction:**
- Start/Pause buttons for processing queue
- Page navigation updates preview in real-time
- Thumbnail selection shows specific page content
- Retry button processes failed pages again
- Export pushes successfully OCR'd documents to Library

**Keyboard Shortcuts:**
- ⌘R: Start/resume OCR processing
- Arrow keys: Navigate between pages
- ⌘E: Export completed documents to Library

### 5.3 CLEAN Tab (Purple) — V3 Evolved Pipeline

**Purpose:** Content refinement through 16-step multi-phase pipeline with comprehensive control and visualization.

**Layout:**
- Three-panel composition: document selector (top-left), content preview (center/main), inspector (right)
- Content preview shows Original vs. Cleaned mode toggle
- Inspector contains all cleaning controls and settings

**Document Selector:**
- Dropdown/picker showing only cleanable documents (OCR-completed or direct-to-clean)
- Selected document shows in header with type badge
- Quick-select adjacent document arrows

**Content Preview Area:**
- Mode toggle: "Original" (read-only OCR output) vs. "Cleaned" (with changes highlighted)
- VirtualizedTextView: large document handling through chunked rendering
- Cleaned mode shows diff highlighting: additions in green, removals in strikethrough red
- Progress overlay: semi-transparent centered progress indicator during processing
  - Phase-aware messaging: "Normalization: Step 3 of 5" or "Enhancement: Step 8 of 16"
  - Estimated time remaining (if available)
  - Cancel button overlay

**Inspector Panel (CleaningInspectorView / UnifiedCleaningInspector):**

The inspector serves as the control center for cleaning, organized into logical sections:

**Identity Card Section:**
- Document title (filename)
- Content type badge: icon + type name + confidence %
- File metadata: size, page count, language

**Status Section:**
- Processing status: "Ready to Clean", "Processing", "Complete"
- Pipeline confidence score: 0–100% with visual bar, description
- Estimated processing time and cost

**Content Type Selector:**
- Auto-detect mode (default): shows identified type with confidence
- Manual override mode: picker with 11 content types
- Type selection immediately recompiles pipeline for optimal step configuration
- Visual feedback: green checkmark for high confidence, orange warning for uncertain

**Preset Selector:**
- Dropdown showing available presets (Academic, News, Technical, Business, etc.)
- Selected preset shows icon, name, and brief description
- "Modified" indicator if user has customized step toggles
- Preset selection applies step configuration, overridable by user step customization

**Pipeline Steps Section:**
- Organized by phase (Normalization, Enhancement, Validation — not user-editable at phase level)
- Each phase shows as collapsible group:
  - Phase header: name, total steps in phase, phase status
  - Collapsed state: shows checkmark if all steps complete
  - Expanded state: lists all steps in phase
- Each step displays:
  - Toggleable checkbox (locked for always-on steps, enabled for optional)
  - Step name (12pt, .label)
  - Brief description (11pt, .secondaryLabel)
  - Method badge: "AI", "Hybrid", or "Code" (11pt, gray background)
  - Status indicator: ○ pending, ⏳ processing, ✓ completed, — skipped, ! failed
- Step toggle state persists per document and preset combination
- Status indicators update in real-time during processing

**Text Statistics Section:**
- Word count: original vs. cleaned
- Character count: original vs. cleaned
- Page count: original document pages
- Chunk count: for processing statistics
- API calls estimated (before processing) or total (after completion)

**Cost Section:**
- Cost estimation before processing (based on selected steps and content size)
- Real-time cost accumulation during processing
- Total cost display post-completion
- Optional: cost breakdown by step type (AI steps vs. others)
- Confidence rating post-completion: score 0–100% with semantic label

**Actions Section:**
- Export button: triggers CleanedExportSheetView
- Show in Finder: opens document in file explorer
- Send Feedback button: opens BetaFeedbackView
- Report Issue button: opens IssueReporterView
- Completion results: reduction %, token count, cost, confidence rating (shown after processing)

**Processing Workflow:**
1. User selects document from dropdown
2. Inspector loads with auto-detected content type (or shows previously-set manual type)
3. Preset auto-selects based on content type (e.g., "News" preset for News content)
4. User reviews preset and may customize by toggling specific steps
5. User clicks Start Cleaning button
6. PhaseAwareProgressView appears, replacing content preview
7. Each phase completes sequentially with real-time step status updates
8. Post-completion: content preview shows Cleaned mode with diff highlighting
9. Inspector shows completion results: reduction metrics, cost, confidence

**Error Handling:**
- Individual step failure shown in status indicator (! icon)
- Failed step shows brief error message tooltip
- User can skip failed step or retry
- Partial completion allowed: user can export with some steps skipped
- RecoveryNotificationView provides error context and action suggestions

**Keyboard Shortcuts:**
- ⌘⇧R or ⌘K: Start cleaning
- Tab: switch between Original/Cleaned preview mode
- ⌘E: Export cleaned document

### 5.4 LIBRARY Tab (Green)

**Purpose:** Document browsing, preview rendering, and export staging.

**Layout:**
- Finder-style three-column view: sidebar (filters/sources), document list (center), preview panel (right)
- Sidebar: All Documents, Cleaned Only, By Type (category filters)
- Document list: DocumentListRow items with search filtering
- Preview panel: Rendered markdown, raw, or cleaned content based on mode

**Preview Modes:**
- Rendered (default): MarkdownPreview component with semantic block rendering
  - Headers: hierarchical sizing (H1: 18pt, H2: 16pt, etc.)
  - Lists: bullet points (unordered) and numbered (ordered)
  - Code blocks: monospace font, light background, syntax highlighting if detectable
  - Tables: grid rendering with borders, header row styling
  - Blockquotes: left border (4pt, .blue), indented text, italic
  - Horizontal rules: separator line
  - Links: blue color with underline
- Raw: Plain text, monospace, read-only
- Cleaned: Shows cleaned version (if document has been cleaned)

**Search & Filtering:**
- Search bar filters documents by filename and content (full-text search)
- Category filters: All, Cleaned Only, By Type
- Search results update in real-time as user types
- Clear button resets search/filters

**Document Stats Footer:**
- Total document count
- Count of cleaned documents
- Total cumulative cost (all documents processed)
- Optional: date range selector for filtering by processed date

**Context Menu (right-click on document):**
- Clean / Re-clean: initiate cleaning for selected document
- Export: trigger ExportSheetView for single document
- Copy to Clipboard: copy rendered content to clipboard
- Show in Finder: open document location in Finder
- Delete: remove document from library with confirmation
- Duplicate: create copy of document (for archival or testing)

**Batch Export:**
- Checkbox selection for multiple documents
- Toolbar button: "Export Selected" or "Batch Export"
- Triggers BatchExportSheetView with progress indicator
- Export all selected documents with chosen format/options

**Paged Preview:**
- For multi-page documents, PagedPreviewComponents enable page navigation
- Page selector: arrows or page number input
- Current page indicator: "Page 2 of 5"
- Thumbnail strip showing adjacent pages (optional)

### 5.5 SETTINGS Tab (Gray)

**Purpose:** Application configuration, API management, and user preferences.

**Layout:**
- Sidebar with subtabs: API Keys, Cleaning, Export, About
- Main content area: tab-specific settings

**API Keys Tab:**
- OpenAI API key management
- Input field with masked display (•••••••••• with last 4 chars visible: •••key)
- Validate button: tests key connectivity, shows success/error status
- Clear button: removes stored key with confirmation
- Status indicator: green checkmark if valid, red X if invalid/missing
- Help text: link to OpenAI documentation for obtaining API key

**Cleaning Tab (CleaningSettingsView):**
- Default preset selector: dropdown with preset options
- Content type behavior flags:
  - Auto-detect content type (toggle)
  - Save type per document (toggle)
  - Show confidence scores (toggle)
- Paragraph settings:
  - Minimum paragraph length: slider or numeric input
  - Merge short paragraphs (toggle)
  - Preserve original formatting (toggle)

**Export Tab:**
- Default format selector: Markdown (default), Plain Text, JSON
- Export options:
  - Include metadata (toggle) — filename, processing date, content type
  - Include cost (toggle) — processing cost in metadata
  - Include time (toggle) — processing duration
  - Front matter (toggle) — YAML front matter for markdown
  - Pretty-print JSON (toggle) — formatted vs. minified
- Remember location (toggle): auto-save to previous export directory
- Default save location: chooser button to set preference

**About Tab (AboutView):**
- Application version: "Horus v3.0 (Build 2026.02)"
- Copyright and credits
- Links:
  - Website: https://horus.ai
  - Documentation: in-app docs link
  - Support: support@horus.ai
  - GitHub: source repository link
- Release notes: button to view current version release notes
- Check for updates: button to manually check for new versions
- Privacy Policy and Terms of Service links

**No Inspector Panel:**
- Settings tab hides the right inspector panel entirely
- Full content width available for settings interface

---

## 6. Export Workflow

### 6.1 Export Sheet Views

**ExportSheetView** (Single Document Export)
- Header: document icon, filename, file info
- Format selection: radio buttons for Markdown, Plain Text, JSON
- Format descriptions: brief explanatory text for each format
- Options section: checkboxes for metadata, cost, time, front matter, pretty-print
- Preview pane: small preview of export format (first 500 chars)
- Footer: Cancel button (left), Export button (right, primary)
- Size: 600×700 (modal presentation)

**BatchExportSheetView** (Multiple Document Export)
- Header: count of selected documents
- Format selection: same as ExportSheetView
- Progress indicator: horizontal progress bar, document count (3 of 8 exported)
- Current export status: filename of document being exported
- Options: same as ExportSheetView
- Cancel button: stops export process with confirmation
- Footer: Cancel, Export (primary)
- Real-time progress updates as documents export

### 6.2 Format-Specific Details

**Markdown Export:**
- File extension: .md
- Content: full rendered markdown from cleaned document
- Optional front matter (YAML block at top if enabled):
  ```yaml
  ---
  title: "Document Title"
  processing_date: "2026-02-08"
  content_type: "News"
  confidence: 87%
  reduction: 12%
  cost: $0.03
  ---
  ```
- Cleaning report (if document cleaned): HTML comment block at end:
  ```html
  <!-- Cleaning Report
       Confidence: 87%
       Reduction: 12% (2,340 → 2,058 words)
       Cost: $0.03
       Steps Applied: ...
  -->
  ```

**Plain Text Export:**
- File extension: .txt
- Content: cleaned text without markdown formatting
- Optional header with metadata (if enabled)
- UTF-8 encoding

**JSON Export:**
- File extension: .json
- Structure: object with content, metadata, statistics keys
- Pretty-printed by default (2-space indentation if toggle enabled)
- Example structure:
  ```json
  {
    "metadata": {
      "title": "Document Title",
      "original_filename": "report.pdf",
      "content_type": "News",
      "processing_date": "2026-02-08"
    },
    "content": "...",
    "statistics": {
      "words": 2058,
      "characters": 12500,
      "reduction_percent": 12,
      "cost": 0.03,
      "confidence": 87
    }
  }
  ```

---

## 7. Onboarding Flow

### 7.1 Onboarding Wizard

**OnboardingWizardView** (First Launch Experience)
- Presentation: fullscreen modal or window
- Step navigation: Previous/Next buttons, step indicator (1/4, 2/4, etc.)
- Size: 700×500 minimum

**Step 1: Welcome**
- Large icon or illustration
- Title: "Welcome to Horus"
- Description: "Horus transforms messy documents into clean, readable content with AI-powered precision."
- Features list: bullet points highlighting core benefits
- Next button to proceed

**Step 2: API Keys**
- Title: "Connect Your OpenAI Account"
- Description: Explain API key requirement and setup process
- Input field: paste OpenAI API key (masked)
- Validate button: tests key validity
- Status: shows success or error message
- Help link: opens OpenAI documentation
- Next button (enabled only if key validated)

**Step 3: Configuration**
- Title: "Customize Your Setup"
- Default preset selector
- Content type behavior options
- Export preferences
- Next button

**Step 4: Quick Start**
- Title: "You're All Set!"
- Brief overview of workflow
- Demo: animated walkthrough of Import → OCR → Clean → Library pipeline
- Buttons: "Start Using Horus" (primary), "View Documentation" (secondary)

**OnboardingStepView** (Container)
- Full-height centered content area
- Title (18pt, semibold)
- Description (14pt, regular, .secondaryLabel)
- Custom step content
- Navigation buttons at bottom

---

## 8. State Management Architecture

### 8.1 AppState

**@Observable class AppState** serves as single source of truth for all application state:

**Navigation State:**
- `selectedTab`: Current active tab (Input, OCR, Clean, Library, Settings)
- `selectedDocumentID`: Currently selected document in detail views
- `selectedPageIndex`: Current page in multi-page documents
- `showInspector`: Boolean toggle for inspector panel visibility

**Document Management:**
- `documents`: Dictionary of all documents, keyed by ID
- `documentQueue`: Ordered array of documents in input queue
- `cleaningQueue`: Documents pending cleaning
- `exportQueue`: Documents staged for export

**Processing State:**
- `isOCRProcessing`: Boolean indicating active OCR operation
- `isCleaningProcessing`: Boolean indicating active cleaning operation
- `processingProgress`: CurrentValue<Double> (0–100) for progress tracking
- `currentProcessingStep`: String describing current operation ("Page 3 of 12", "Normalization: Step 2 of 5")

**Service Instances:**
- `ocrService`: OCRService for document recognition
- `cleaningService`: CleaningService for content refinement
- `exportService`: ExportService for document export

**ViewModel Composition:**
- `cleaningViewModel`: CleaningViewModel managing cleaning state
- `processingViewModel`: ProcessingViewModel tracking operation progress
- `documentQueueViewModel`: DocumentQueueViewModel managing queue operations
- `exportViewModel`: ExportViewModel managing export configuration

**Settings State:**
- `apiKey`: Stored OpenAI API key (persisted to Keychain)
- `defaultPreset`: Default cleaning preset selection
- `autoDetectContentType`: Boolean flag
- `defaultExportFormat`: Markdown, PlainText, or JSON
- `rememberExportLocation`: Last export directory path

### 8.2 View State Patterns

**Local State (@State):**
- Tab-specific UI state (search queries, filter selections)
- Form input state (text fields, toggles)
- Sheet presentation state (showExportSheet, showSettingsSheet)

**Bindings (@Binding):**
- Parent-to-child state propagation
- Two-way binding for form inputs
- Document selection bindings between list and detail views

**Observable ViewModels:**
- Tab-specific ViewModels (@Observable)
- Services instantiated through dependency injection
- State synchronized with AppState through computed properties

---

## 9. Keyboard Shortcuts

Horus provides comprehensive keyboard accessibility, allowing power users to navigate and operate entirely via keyboard:

**Tab Navigation:**
- ⌘1: Input tab (implicit through ⌘O pattern)
- ⌘2: OCR tab (implicit through ⌘R pattern)
- ⌘3: Clean tab (implicit through ⌘K pattern)
- ⌘4: Library tab
- ⌘5: Settings tab

**Document Operations:**
- ⌘O: Import files (open file picker)
- ⌘R: Start/resume OCR processing
- ⌘⇧R or ⌘K: Start cleaning
- ⌘E: Export selected document
- ⇧⌘E: Batch export selected documents
- Delete: Remove selected document from queue/library (with confirmation)
- ↑↓: Navigate document list
- Enter: Select document

**Interface Controls:**
- ⌘,: Open Settings tab
- ⌘⌥S: Toggle sidebar visibility
- ⌘⌥I: Toggle inspector panel visibility
- Tab: Navigate between sections
- Space: Toggle selected item
- Escape: Close sheet, deselect item

**Clean Tab Specific:**
- Tab: Switch between Original/Cleaned preview modes
- ↑↓: Navigate pipeline steps (when inspector focused)
- Space: Toggle selected step

All shortcuts are customizable through Settings (future enhancement). Menu commands are defined in HorusApp.swift with @CommandMenu modifiers.

---

## 10. Accessibility

Horus is designed for universal accessibility, supporting users with diverse needs and abilities.

### 10.1 VoiceOver Support

Every interactive element includes meaningful accessibility labels:
- Buttons: Clear action description ("Export Document", "Start OCR Processing")
- Form fields: Labels and placeholder text clearly identify purpose
- Status indicators: Describe current state ("Processing: Page 3 of 12")
- Images: Alt text or decorative-only marking (accessibility hidden)

Navigation order is logical and predictable:
- Left-to-right, top-to-bottom within content
- Grouped related controls (form sections, step controls)
- Skip links enable jumping to main content

### 10.2 Keyboard Navigation

Full keyboard navigation without mouse required:
- Tab/Shift-Tab: forward/backward navigation
- Arrow keys: list navigation, step selection
- Enter/Space: activate buttons/toggles
- Escape: dismiss modals, cancel operations
- Focus indicators: clear visual indication of currently focused element

### 10.3 Dynamic Type

Text automatically scales with system Dynamic Type setting:
- Use semantic font styles (.title, .headline, .body, .caption)
- Test at 100%, 150%, 200% scaling
- Ensure layouts remain usable and legible at largest size
- No fixed-size text containers

### 10.4 Reduced Motion

Animations respect system Reduce Motion preference:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// In animation:
withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
    // state change
}
```

### 10.5 Color Contrast

All text meets WCAG 2.1 AA contrast minimum (4.5:1 for normal, 3:1 for large):
- Use semantic color labels (.label, .secondaryLabel)
- Never rely on color alone to convey meaning
- Status badges include symbols/icons in addition to color

### 10.6 Accessibility Extensions

Helper extensions in Accessibility.swift provide consistent application:
```swift
extension View {
    func accessibilityLabel(_ label: String) -> some View { ... }
    func accessibilityHint(_ hint: String) -> some View { ... }
    func accessibilityRespondsToUserInteraction() -> some View { ... }
}
```

---

## 11. Animation & Motion

Motion in Horus enhances perception of responsiveness and state changes without creating distraction.

**Fast (150ms) Animations:**
- Button press feedback (scale: 0.95–1.0)
- Checkbox toggle
- Hover effects
- Micro-interactions

**Standard (200ms) Animations:**
- Tab transitions (fade in/out)
- Panel appearance (slide from edge)
- List item insertion/removal
- Inspector section expansion

**Slow (300ms) Animations:**
- Modal presentation
- Sheet slide-in
- Major panel transitions
- Progress bar completion animations

All animations automatically disable or reduce to 50% duration when Reduce Motion system preference is enabled.

---

## 12. Error States & Recovery

### 12.1 Empty States

EmptyStateView components appear when no content is available:
- Icon: contextual image (document, folder, etc.)
- Title: clear description of empty state
- Message: explanation of why state is empty
- Action button: next step to populate content

Examples:
- Input tab, no documents: "No documents imported. Click 'Import' or drag files here to begin."
- Library tab, no cleaned documents: "No cleaned documents yet. Go to Clean tab to process documents."

### 12.2 Loading States

ProgressView with contextual messaging during long operations:
- Processing indicator: animated circle or progress bar
- Status text: "Processing page 3 of 12" or "Normalizing content..."
- Cancel button: option to stop operation
- Estimated time: if available, show time remaining

### 12.3 Error States

Errors provide clear explanation and recovery path:
- RecoveryNotificationView: icon + title + description + action
- Types:
  - API failure: "OpenAI API Error" with retry button
  - Network error: "Connection lost" with retry option
  - Processing failure: specific step failure with skip/retry options
  - Invalid input: "API key is invalid" with settings navigation button

### 12.4 Partial States

Graceful handling when data is incomplete:
- Document partially OCR'd: show completed pages, skip failed ones option
- Cleaning partially completed: allow export with selected steps, notification of incomplete state
- Failed steps: skip and continue, don't block entire operation

---

## Conclusion

The Horus UI/UX specification represents a comprehensive, coherent design system built on Apple's philosophy of simplicity, clarity, and confidence. Every element from spacing to animation to error handling has been carefully considered to create an interface that feels natural, performs responsively, and builds user trust through transparency and control.

The three-panel layout, five-tab navigation, and contextual inspector provide an intuitive workflow that guides users through document processing naturally. The component library ensures consistency across all screens, while specialized views for complex operations (cleaning pipeline, export configuration) provide powerful, understandable controls.

By adhering to this specification, Horus maintains visual and behavioral consistency, supports universal accessibility, and provides a premium application experience worthy of professional document processing workflows.

---

**Document Metadata:**
- Version: 3.0
- Updated: February 2026
- Status: Active Implementation Reference
- Audience: Design, Engineering, QA, Product
