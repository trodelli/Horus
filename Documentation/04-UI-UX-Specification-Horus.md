# UI/UX Specification
## Horus — Document Processing & Cleaning for macOS

> **Document Version:** 2.0  
> **Last Updated:** January 2026  
> **Status:** Active Development  
> **Prerequisites:** PRD v2.0, Technical Architecture v2.0

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Application Structure](#2-application-structure)
3. [Design System](#3-design-system)
4. [Tab Specifications](#4-tab-specifications)
5. [Component Library](#5-component-library)
6. [Interaction Patterns](#6-interaction-patterns)
7. [State Transitions](#7-state-transitions)
8. [Error & Empty States](#8-error--empty-states)
9. [Accessibility](#9-accessibility)
10. [Animation & Motion](#10-animation--motion)

---

## 1. Design Philosophy

### 1.1 Core Principles

Horus embodies five design principles that guide every interface decision:

**Transparency**
Users always know what's happening. Processing shows meaningful progress with step-by-step detail. Costs are visible before, during, and after operations. Errors explain themselves clearly with recovery options.

**Flow**
The document processing pipeline (Import → OCR → Clean → Library → Export) should feel natural and progressive. Each tab represents a clear stage, with documents flowing through the system toward their final refined state.

**Native**
Horus should feel like it belongs on macOS—as if Apple designed it. Standard shortcuts work. System conventions are respected. The app adapts to user preferences (Dark Mode, accessibility settings) automatically.

**Confidence**
Users trust the tool. They can preview before exporting. They can cancel at any time. They always know what operations cost. Multi-layer validation prevents catastrophic errors. Mistakes are recoverable.

**Focus**
Every element earns its place. No decorative clutter. Information appears when relevant. Complexity lives in the processing engine, not the interface.

### 1.2 Design Language

Horus follows Apple's Human Interface Guidelines while establishing its own identity:

| Aspect | Approach |
|:-------|:---------|
| **Typography** | San Francisco system font exclusively |
| **Colors** | System semantic colors + tab-specific accents |
| **Icons** | SF Symbols throughout |
| **Layout** | 5-tab architecture with consistent 3-column views |
| **Spacing** | 4-point base grid system |
| **Depth** | Subtle shadows for elevation; system vibrancy |

### 1.3 The Horus Identity

**Name Origin:** Horus, the Egyptian god of the sky, whose eye symbolized vision, perception, and transformation. Appropriate for an app that transforms documents into clean, usable text.

**Visual Identity:**
- Clean, professional aesthetic
- Tab-specific accent colors (Blue for OCR, Purple for Cleaning, Green for Library)
- Pipeline badges showing document processing state

### 1.4 Tab Color Semantics

Each tab has an associated accent color that appears in icons, badges, and action buttons:

| Tab | Color | Meaning |
|:----|:------|:--------|
| Input | System Blue | Import and preparation |
| OCR | Blue | Text extraction processing |
| Clean | Purple | AI-powered refinement |
| Library | Green | Finished, curated output |
| Settings | Gray | Configuration |

---

## 2. Application Structure

### 2.1 Window Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ ○ ○ ○                              Horus                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ ┌─────────────────┐                                                                 │
│ │  📥 Input       │ ← Vertical tab navigation sidebar                              │
│ │  📄 OCR         │                                                                 │
│ │  ✨ Clean       │                                                                 │
│ │  📚 Library     │                                                                 │
│ │                 │                                                                 │
│ │                 │                                                                 │
│ │                 │                                                                 │
│ │  ⚙️ Settings    │                                                                 │
│ └─────────────────┘                                                                 │
├───────────────────┬─────────────────────────────────────────┬───────────────────────┤
│   File List       │           Content Area                  │      Inspector        │
│   (220-320pt)     │           (min 400pt)                   │      (300-580pt)      │
│                   │                                         │                       │
│ ┌───────────────┐ │  ┌─────────────────────────────────────┐│  ┌─────────────────┐ │
│ │ Header (96pt) │ │  │ Content Header (96pt)              ││  │ Document Info   │ │
│ │ Title         │ │  │ Title | Actions | Metrics          ││  │ ─────────────── │ │
│ │ Subtitle      │ │  │ ─────────────────────────────────  ││  │ File details    │ │
│ │ [Search]      │ │  └─────────────────────────────────────┘│  │                 │ │
│ └───────────────┘ │                                         │  │ OCR Results     │ │
│                   │  ┌─────────────────────────────────────┐│  │ ─────────────── │ │
│ ┌───────────────┐ │  │                                     ││  │ Pages, words... │ │
│ │ 📄 Doc 1      │ │  │                                     ││  │                 │ │
│ │   OCR ✓       │ │  │       Content Preview               ││  │ Cleaning        │ │
│ ├───────────────┤ │  │       (VirtualizedTextView)         ││  │ ─────────────── │ │
│ │ 📄 Doc 2      │ │  │                                     ││  │ Status, cost... │ │
│ │   OCR Cleaned │ │  │                                     ││  │                 │ │
│ ├───────────────┤ │  │                                     ││  │ Total Cost      │ │
│ │ 📄 Doc 3      │ │  │                                     ││  │ ─────────────── │ │
│ │   Processing  │ │  └─────────────────────────────────────┘│  │ $0.03           │ │
│ └───────────────┘ │                                         │  └─────────────────┘ │
│                   │                                         │                       │
│ ┌───────────────┐ │                                         │                       │
│ │ Footer (36pt) │ │                                         │                       │
│ │ Count | Status│ │                                         │                       │
│ └───────────────┘ │                                         │                       │
└───────────────────┴─────────────────────────────────────────┴───────────────────────┘
```

### 2.2 Navigation Model

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           TAB-BASED NAVIGATION                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  First Launch ──────────────────────────────────────────────────┐               │
│       │                                                         │               │
│       ▼                                                         │               │
│  ┌─────────────┐                                               │               │
│  │ Onboarding  │──── Skip ─────────────────────────────────────│               │
│  │   (Sheet)   │                                               │               │
│  └──────┬──────┘                                               │               │
│         │                                                      │               │
│         │ API Key Valid                                        │               │
│         ▼                                                      ▼               │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         Main Window                                      │   │
│  │  ┌───────────┬───────────────────────────────────────────────────────┐  │   │
│  │  │           │                                                       │  │   │
│  │  │   Tab     │                   Tab Content                         │  │   │
│  │  │  Sidebar  │    (File List + Content + Inspector per tab)          │  │   │
│  │  │           │                                                       │  │   │
│  │  └───────────┴───────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  Document Flow Through Tabs:                                                    │
│  ──────────────────────────                                                     │
│                                                                                 │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐                      │
│  │  Input  │───▶│   OCR   │───▶│  Clean  │───▶│ Library │                      │
│  │ Import  │    │ Extract │    │ Refine  │    │ Export  │                      │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘                      │
│       │              │              │              │                            │
│       │              │              │              │                            │
│       ▼              ▼              ▼              ▼                            │
│  Add files     Run Mistral    Run Claude AI   Save/Export                       │
│  Drag & drop   OCR on docs    cleaning steps  final output                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 View Hierarchy

```
HorusApp
├── MainWindowView (WindowGroup)
│   ├── NavigationSplitView (2-column: sidebar + detail)
│   │   ├── Sidebar (Tab Navigation)
│   │   │   ├── TabButton: Input (⌘1)
│   │   │   ├── TabButton: OCR (⌘2)
│   │   │   ├── TabButton: Clean (⌘3)
│   │   │   ├── TabButton: Library (⌘4)
│   │   │   └── TabButton: Settings (⌘,)
│   │   │
│   │   └── Detail (Tab Content)
│   │       ├── InputTabView
│   │       │   ├── HSplitView
│   │       │   │   ├── DocumentTablePane (File List)
│   │       │   │   │   ├── TabHeaderView
│   │       │   │   │   ├── DocumentList
│   │       │   │   │   └── TabFooterView
│   │       │   │   └── ContentPreviewPane
│   │       │   │       ├── ContentHeaderView
│   │       │   │       └── VirtualizedTextView / EmptyState
│   │       │   └── InspectorView (trailing)
│   │       │
│   │       ├── OCRTabView (similar structure)
│   │       ├── CleanTabView
│   │       │   ├── HSplitView
│   │       │   │   ├── DocumentTablePane
│   │       │   │   └── ContentPreviewPane
│   │       │   │       ├── ContentHeaderView (with Original/Cleaned toggle)
│   │       │   │       ├── VirtualizedTextView
│   │       │   │       └── ProcessingOverlay (when cleaning)
│   │       │   └── CleaningInspectorView
│   │       │
│   │       ├── LibraryTabView (similar structure)
│   │       └── SettingsTabView
│   │
│   └── Sheets
│       ├── OnboardingSheet
│       ├── ExportSheet
│       ├── CleanedExportSheet
│       └── CleaningExplainerSheet
│
└── Commands (HorusCommands)
    ├── File Menu
    ├── Edit Menu
    ├── Process Menu
    ├── Clean Menu
    ├── Library Menu
    └── View Menu
```

### 2.4 Three-Column Layout Pattern

Each tab (except Settings) follows a consistent three-column layout:

```
┌─────────────────┬─────────────────────────────────┬─────────────────────┐
│   FILE LIST     │        CONTENT AREA             │     INSPECTOR       │
│   (220-320pt)   │        (min 400pt)              │     (300-580pt)     │
├─────────────────┼─────────────────────────────────┼─────────────────────┤
│                 │                                 │                     │
│  • Header       │  • Content Header (3 levels)    │  • Document Info    │
│    - Title      │    - Level 1: Title + File Type │  • OCR Results      │
│    - Subtitle   │    - Level 2: Actions           │  • Cleaning Results │
│    - Search     │    - Level 3: Metrics           │  • Cost Summary     │
│                 │                                 │                     │
│  • Document     │  • Preview Content              │  (Scrollable)       │
│    List         │    - VirtualizedTextView        │                     │
│    (Scrollable) │    - EmptyStateView             │                     │
│                 │    - ProcessingOverlay          │                     │
│  • Footer       │                                 │                     │
│    - Count      │                                 │                     │
│    - Status     │                                 │                     │
│                 │                                 │                     │
└─────────────────┴─────────────────────────────────┴─────────────────────┘
```

---

## 3. Design System

### 3.1 Design Constants (Single Source of Truth)

All design values are centralized in `DesignConstants.swift`. Reference these values rather than hardcoding:

### 3.2 Spacing System (4-Point Base Grid)

```swift
enum Spacing {
    static let xs: CGFloat = 4    // Tight spacing between closely related elements
    static let xsm: CGFloat = 6   // Compact spacing for header content levels
    static let sm: CGFloat = 8    // Small spacing between related elements
    static let md: CGFloat = 12   // Medium spacing, standard padding
    static let lg: CGFloat = 16   // Large spacing between sections
    static let xl: CGFloat = 20   // Extra large spacing for major separations
    static let xxl: CGFloat = 24  // Maximum spacing for distinct sections
}
```

### 3.3 Layout Dimensions

```swift
enum Layout {
    // Header/Footer
    static let headerHeight: CGFloat = 96     // All tab headers
    static let footerHeight: CGFloat = 36     // All tab footers
    
    // File List Pane
    static let fileListMinWidth: CGFloat = 220
    static let fileListMaxWidth: CGFloat = 320
    
    // Content Pane
    static let contentPaneMinWidth: CGFloat = 400
    
    // Inspector Panel
    static let inspectorMinWidth: CGFloat = 300
    static let inspectorIdealWidth: CGFloat = 470
    static let inspectorMaxWidth: CGFloat = 580
    
    // Navigation Sidebar
    static let sidebarMinWidth: CGFloat = 180
    static let sidebarIdealWidth: CGFloat = 200
    static let sidebarMaxWidth: CGFloat = 250
    
    // Other
    static let searchFieldHeight: CGFloat = 26
    static let documentRowPadding: CGFloat = 4
}
```

### 3.4 Typography Hierarchy

```swift
enum Typography {
    // Headers
    static let headerTitle: Font = .system(size: 13, weight: .semibold)
    static let headerSubtitle: Font = .system(size: 11)
    
    // Document Lists
    static let documentName: Font = .system(size: 13)
    static let documentMeta: Font = .system(size: 11)
    
    // Inspector
    static let inspectorHeader: Font = .subheadline.weight(.semibold)
    static let inspectorLabel: Font = .callout
    static let inspectorValue: Font = .callout
    
    // Toolbar
    static let toolbarButton: Font = .system(size: 12, weight: .medium)
    static let toolbarButtonRegular: Font = .system(size: 12)
    
    // Empty States
    static let emptyStateIcon: Font = .system(size: 48)
    static let emptyStateTitle: Font = .title3.weight(.medium)
    static let emptyStateDescription: Font = .callout
    
    // Footer/Stats
    static let footer: Font = .system(size: 11)
    static let footerSecondary: Font = .system(size: 10)
    static let statsBar: Font = .system(size: 10)
    static let badge: Font = .system(size: 10, weight: .medium)
}
```

### 3.5 Color Palette

```swift
enum Colors {
    // Pane Backgrounds
    static let fileListBackground = Color(nsColor: .underPageBackgroundColor)
    static let contentBackground = Color(nsColor: .textBackgroundColor)
    static let inspectorBackground = Color(nsColor: .underPageBackgroundColor)
    
    // Controls
    static let statsBarBackground = Color(nsColor: .controlBackgroundColor)
    static let searchFieldBackground = Color(nsColor: .quaternaryLabelColor).opacity(0.5)
    
    // Structural
    static let separator = Color(nsColor: .separatorColor)
}
```

**Tab Accent Colors:**

| Tab | Primary Color | Usage |
|:----|:--------------|:------|
| Input | `.blue` | Icons, badges, action buttons |
| OCR | `.blue` | Processing indicators, results |
| Clean | `.purple` | Cleaning status, AI indicators |
| Library | `.green` | Completion indicators, save actions |
| Settings | `.gray` | Neutral configuration |

**Status Colors:**

| Status | Color | Usage |
|:-------|:------|:------|
| Success | `.green` | Completed, saved, in library |
| Warning | `.orange` | Cancelled, pending attention |
| Error | `.red` | Failed operations |
| Processing | `.purple` (Clean), `.blue` (OCR) | Active operations |

### 3.6 Icon Dimensions

```swift
enum Icons {
    // Document Row Icons
    static let documentRowWidth: CGFloat = 32
    static let documentRowHeight: CGFloat = 40
    static let documentRowCornerRadius: CGFloat = 4
    static let documentRowIconFont: Font = .system(size: 12)
    
    // Input Tab (slightly smaller)
    static let inputRowWidth: CGFloat = 28
    static let inputRowHeight: CGFloat = 34
    static let inputRowCornerRadius: CGFloat = 3
    static let inputRowIconFont: Font = .system(size: 10)
    
    // Inspector
    static let inspectorIconSize: CGFloat = 40
    static let inspectorIconCornerRadius: CGFloat = 8
    static let inspectorIconFont: Font = .system(size: 20)
    
    // Empty State
    static let emptyStateSize: CGFloat = 48
}
```

### 3.7 Corner Radii

```swift
enum CornerRadius {
    static let xs: CGFloat = 3    // Badges, small elements
    static let sm: CGFloat = 4    // Buttons, tags
    static let md: CGFloat = 6    // Cards, containers
    static let lg: CGFloat = 8    // Panels, sheets
    static let xl: CGFloat = 12   // Modals
    static let xxl: CGFloat = 16  // Prominent containers
}
```

### 3.8 Shadows

```swift
enum Shadow {
    static let subtle = (color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    static let medium = (color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
    static let strong = (color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
}
```

---

## 4. Tab Specifications

### 4.1 Input Tab

**Purpose:** Import documents for processing. Drag-and-drop or file picker.

**Layout:** 3-column (File List + Content + Inspector)

**File List Header:**
```
┌────────────────────────┐
│ Input                  │  ← Title (13pt semibold)
│ Add documents for OCR  │  ← Subtitle (11pt)
│ ┌────────────────────┐ │
│ │ 🔍 Search...       │ │  ← Search field
│ └────────────────────┘ │
└────────────────────────┘
```

**Document Row (Input):**
```
┌────────────────────────────────────────┐
│ ┌────┐                                 │
│ │ 📄 │  document-name.pdf              │  ← Filename (13pt)
│ │    │  PDF • 2.4 MB • 24 pages        │  ← Metadata (11pt secondary)
│ └────┘                        [OCR] ✓  │  ← Pipeline badges (trailing)
└────────────────────────────────────────┘
```

**Content Header (3 Levels):**
```
┌─────────────────────────────────────────────────────────────────────┐
│ Level 1: document-name.pdf                           PDF Document   │
├─────────────────────────────────────────────────────────────────────┤
│ Level 2: [Process] [▾ Export] [📋] [🗑]  │  [Original ▼]           │
├─────────────────────────────────────────────────────────────────────┤
│ Level 3: 📄 24 pages  •  📊 12,450 words  •  🔤 ~15K tokens        │
└─────────────────────────────────────────────────────────────────────┘
```

**Footer:**
```
┌────────────────────────┐
│ 12 documents    │ ● Mistral Ready │
└────────────────────────┘
```

### 4.2 OCR Tab

**Purpose:** Monitor OCR processing. View results. Manage processing queue.

**Layout:** 3-column (File List + Content + Inspector)

**Primary Actions:**
- Process All (⌘R)
- Pause/Resume (⇧⌘P)
- Cancel (⌘.)

**Document Row (OCR):**
```
┌────────────────────────────────────────┐
│ ┌────┐                                 │
│ │ 📄 │  document-name.pdf              │
│ │blue│  Processing page 3/24...        │  ← Status (processing)
│ └────┘                        ◐ 12%    │  ← Progress indicator
└────────────────────────────────────────┘
```

**Processing Overlay:**
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                     Processing Documents                    │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ ━━━━━━━━━━━━━━━━░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  │
│  │                        35%                             │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Document 4 of 12: quarterly-report.pdf                     │
│  Page 8 of 24                                               │
│                                                             │
│  Elapsed: 1m 23s    •    Est. remaining: ~2m 30s            │
│                                                             │
│                 [Pause]    [Cancel]                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 Clean Tab

**Purpose:** AI-powered document cleaning with Claude. Configure steps, monitor progress, preview results.

**Layout:** 3-column (File List + Content + Inspector)

**Accent Color:** Purple

**Document Row (Clean):**
```
┌────────────────────────────────────────┐
│ ┌────┐                                 │
│ │ 📄 │  document-name.pdf              │
│ │purp│  [OCR] [Cleaned]                │  ← Pipeline badges
│ └────┘                     📚 ✓ 🧹 ✓   │  ← Status icons
└────────────────────────────────────────┘
```

**Pipeline Badges:**
- `[OCR]` — Blue background, indicates OCR was performed
- `[Cleaned]` — Purple background, indicates cleaning was applied

**Status Icons (Trailing):**
- 📚 — In Library (green check if yes)
- 🧹 — Cleaned (purple check if yes)

**Content Header (Clean-Specific):**
```
┌─────────────────────────────────────────────────────────────────────┐
│ Level 1: document-name.pdf                           PDF Document   │
├─────────────────────────────────────────────────────────────────────┤
│ Level 2: [Original | Cleaned]  │  [Start Cleaning ✨]  [⟳] [↗] [📋]│
├─────────────────────────────────────────────────────────────────────┤
│ Level 3: 📝 12,450  •  🔤 ~15K  •  ↓ 8.2%  •  ✓ Complete           │
└─────────────────────────────────────────────────────────────────────┘
```

**Preview Mode Toggle:**
- `[Original | Cleaned]` — Segmented control to switch between original OCR and cleaned output
- Disabled until cleaning completes

**Primary Actions:**
- Start Cleaning (⌘K) — Purple button when ready
- Cancel — During processing
- Save to Library — Green button when complete
- Re-clean (⟳) — After completion

**Processing Overlay (Cleaning):**
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                 ✨ Cleaning Document...                     │
│                                                             │
│                    document-name.pdf                        │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ ━━━━━━━━━━━━━━━━━━━━░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  │
│  │                        42%                             │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Step 5 of 12: Remove Table of Contents                     │
│  Detecting TOC boundaries...                                │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 📦 Processing chunk 2 of 4                          │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Estimated time remaining: ~45 seconds                      │
│                                                             │
│                        [Cancel]                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Cleaning Inspector:**
```
┌───────────────────────────────────┐
│ Document                          │
│ ───────────────────────────────── │
│ 📄 document-name.pdf              │
│ Status: Cleaning ◐                │
│                                   │
│ Cleaning Progress                 │
│ ───────────────────────────────── │
│ Step         5 of 12              │
│ Current      Remove TOC           │
│ Chunks       2 of 4               │
│                                   │
│ Cleaning Results                  │
│ ───────────────────────────────── │
│ ┌─────────────────────────────┐   │
│ │ 12,100   10,850   -8.2%  3s │   │
│ │ Words    Chars  Reduction   │   │
│ └─────────────────────────────┘   │
│ ┌─────────────────────────────┐   │
│ │   2,450        $0.0153      │   │
│ │ Tokens Used   Total Cost    │   │
│ └─────────────────────────────┘   │
│                                   │
│ Estimated Cost                    │
│ ───────────────────────────────── │
│ Est. Cost        ~$0.02           │
│ Based on document size            │
│                                   │
└───────────────────────────────────┘
```

### 4.4 Library Tab

**Purpose:** View completed documents. Export in various formats. Final output curation.

**Layout:** 3-column (File List + Content + Inspector)

**Accent Color:** Green

**Document Row (Library):**
```
┌────────────────────────────────────────┐
│ ┌────┐                                 │
│ │ 📄 │  document-name.pdf              │
│ │grn │  [OCR] [Cleaned]                │  ← Full pipeline badges
│ └────┘                           ✓     │  ← Completion indicator
└────────────────────────────────────────┘
```

**Export Actions:**
- Export Selected (⌘E)
- Export All (⇧⌘E)
- Copy to Clipboard (⇧⌘C)

**Export Formats:**
- Markdown (.md) — Default, best for LLM training
- JSON (.json) — Full metadata, page-level access
- Plain Text (.txt) — Clean text without markup

### 4.5 Settings Tab

**Purpose:** Configure API keys, preferences, and processing options.

**Layout:** Single-column form layout (no file list or inspector)

**Sections:**

```
┌─────────────────────────────────────────────────────────────────────┐
│ API Configuration                                                   │
│ ─────────────────────────────────────────────────────────────────── │
│                                                                     │
│ Mistral API Key                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ ••••••••••••••••••••sk-abc123            [👁] [Test] [Change]  │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│ Status: Connected ✓                                                 │
│ Pricing: $0.001 per page                                           │
│                                                                     │
│ Claude API Key                                                      │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ ••••••••••••••••sk-ant-api03-xxx         [👁] [Test] [Change]  │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│ Status: Connected ✓                                                 │
│ Pricing: $3/$15 per million tokens (input/output)                  │
│                                                                     │
│ ─────────────────────────────────────────────────────────────────── │
│                                                                     │
│ Processing Options                                                  │
│ ─────────────────────────────────────────────────────────────────── │
│                                                                     │
│ [✓] Show cost estimates before processing                           │
│ [✓] Auto-switch to cleaned preview when cleaning completes          │
│                                                                     │
│ Default cleaning configuration:                                     │
│ [Aggressive ▼]  (removes more scaffolding)                         │
│                                                                     │
│ ─────────────────────────────────────────────────────────────────── │
│                                                                     │
│ Export Defaults                                                     │
│ ─────────────────────────────────────────────────────────────────── │
│                                                                     │
│ Default format: [Markdown ▼]                                        │
│ Default location: [~/Documents/Horus-Export] [Choose...]            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. Component Library

### 5.1 Shared Tab Components

**TabHeaderView:**
```swift
TabHeaderView(
    title: "Clean",
    subtitle: "Refine with Claude AI, then save to Library",
    searchText: $searchText
)
```

- Height: 96pt
- Title: 13pt semibold
- Subtitle: 11pt secondary
- Includes search field (26pt height)

**TabFooterView:**
```swift
TabFooterView {
    Text("\(count) documents")
} trailing: {
    StatusIndicator(
        isActive: appState.hasClaudeAPIKey,
        activeText: "Claude Ready",
        inactiveText: "No API Key"
    )
}
```

- Height: 36pt
- Leading: Count/summary text
- Trailing: Status indicator

**ContentHeaderView:**
```swift
ContentHeaderView(
    title: document.displayName,
    fileType: FileTypeHelper.description(for: document)
) {
    // Level 2 Actions
    HStack { ... }
} metrics: {
    // Level 3 Metrics
    MetricsRow(items: [...])
}
```

- Height: 96pt (matching file list header)
- Level 1: Title + File Type badge
- Level 2: Action buttons
- Level 3: Metrics row

### 5.2 Inspector Components

**InspectorCard:**
```swift
InspectorCard {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        InspectorSectionHeader(title: "Document", icon: "doc.fill")
        InspectorRow(label: "Pages", value: "24")
        InspectorRow(label: "Words", value: "12,450")
    }
}
```

- Subtle background (`controlBackgroundColor.opacity(0.5)`)
- Corner radius: 8pt
- Padding: 12pt

**InspectorRow:**
```swift
InspectorRow(label: "Cost", value: "$0.012", valueColor: .green)
```

- Label: `.callout`, secondary color, left-aligned
- Value: `.callout`, primary color (or custom), right-aligned

**InspectorSectionHeader:**
```swift
InspectorSectionHeader(title: "OCR Results", icon: "doc.text.viewfinder")
```

- Font: `.subheadline.weight(.semibold)`
- Color: secondary
- Optional SF Symbol icon

**OCRResultsSection:**
```swift
OCRResultsSection(result: document.result)
```

Displays: Pages, Words, Characters, Tokens, Duration, Cost
Plus optional content badges (Contains Tables, Contains Images)

**CleaningResultsSection:**
```swift
CleaningResultsSection(content: cleanedContent)
```

Displays:
- Output metrics: Words, Chars, Reduction %, Time
- API metrics: Tokens Used, Total Cost

**TotalCostSection:**
```swift
TotalCostSection(
    ocrCost: document.result?.cost,
    cleaningCost: cleanedContent?.totalCost,
    showItemizedBreakdown: true
)
```

- Shows OCR Cost, Cleaning Cost, and Total
- Compact mode available for single-cost scenarios

### 5.3 Document Row Components

**PipelineBadge:**
```swift
PipelineBadge(text: "OCR", color: .blue)
PipelineBadge(text: "Cleaned", color: .purple)
```

- Font: 10pt medium
- Horizontal padding: 6pt
- Corner radius: 3pt
- Background: color.opacity(0.15)
- Text: color

**PipelineStatusIcons:**
```swift
PipelineStatusIcons(document: document)
```

Displays trailing status icons:
- 📚 Library status (green check if in library)
- 🧹 Cleaned status (purple check if cleaned)

### 5.4 Empty State Component

```swift
EmptyStateView(
    icon: "sparkles",
    title: "No Documents to Clean",
    description: "Process documents through OCR first.",
    buttonTitle: "Go to Input",
    buttonAction: { appState.selectedTab = .input },
    accentColor: .purple
) {
    // Optional additional content
    Label("Claude API key required", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
}
```

### 5.5 VirtualizedTextView

High-performance text rendering for large documents:

```swift
VirtualizedTextView(content: markdownString)
    .id("content-\(document.id)")
```

- Wraps `NSScrollView` with `NSTextView` for AppKit performance
- Handles documents with 10,000+ lines smoothly
- Uses `.id()` modifier to force recreation on content change

### 5.6 Metric Components

**MetricsRow:**
```swift
MetricsRow(items: [
    MetricItem(icon: "textformat", value: "12,450"),
    MetricItem(icon: nil, value: "Tokens ~15K"),
    MetricItem(icon: "arrow.down.right", value: "-8.2%", color: .green),
    MetricItem(icon: "checkmark.circle.fill", value: "Complete", color: .green)
])
```

**MetricItem:**
```swift
struct MetricItem {
    let icon: String?      // SF Symbol name
    let value: String      // Display value
    var color: Color? = nil // Optional accent color
}
```

### 5.7 Status Indicators

**StatusIndicator:**
```swift
StatusIndicator(
    isActive: true,
    activeText: "Claude Ready",
    inactiveText: "No API Key"
)
```

- Dot indicator: green (active) or gray (inactive)
- Text: 10pt, secondary color

**Document Status Badge:**

| Status | Symbol | Color |
|:-------|:-------|:------|
| Pending | `circle` | `.secondary` |
| Processing | `circle.lefthalf.filled` | `.blue` or `.purple` |
| Completed | `checkmark.circle.fill` | `.green` |
| Failed | `xmark.circle.fill` | `.red` |
| Cancelled | `slash.circle` | `.orange` |

---

## 6. Interaction Patterns

### 6.1 Document Pipeline Flow

Documents flow through the application via a clear pipeline:

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  Input  │────▶│   OCR   │────▶│  Clean  │────▶│ Library │
└─────────┘     └─────────┘     └─────────┘     └─────────┘
                     │               │
                     │               │
              [Process All]   [Start Cleaning]
                  (⌘R)            (⌘K)
```

**Input → OCR:**
- User adds documents via drag-and-drop or file picker
- Documents appear in Input tab
- User initiates OCR processing (⌘R)
- Documents move to OCR tab for processing

**OCR → Clean:**
- After OCR completes, documents appear in Clean tab
- User selects document and initiates cleaning (⌘K)
- Claude AI processes through 14-step cleaning pipeline

**Clean → Library:**
- After cleaning completes, user saves to Library
- "Save to Library" button (green) adds cleaned content
- Document appears in Library tab for export

### 6.2 Keyboard Navigation

**Global Shortcuts:**

| Shortcut | Action |
|:---------|:-------|
| ⌘O | Add documents |
| ⌘R | Process all (OCR) |
| ⌘K | Clean selected document |
| ⌘E | Export selected |
| ⇧⌘E | Export all |
| ⇧⌘C | Copy to clipboard |
| ⌘N | New session |
| ⌘, | Settings |

**Tab Navigation:**

| Shortcut | Action |
|:---------|:-------|
| ⌘1 | Input tab |
| ⌘2 | OCR tab |
| ⌘3 | Clean tab |
| ⌘4 | Library tab |

**Document Navigation:**

| Shortcut | Action |
|:---------|:-------|
| ↑ / ↓ | Select previous/next document |
| ⌫ | Delete selected document |
| ⌘L | Add to Library |

**Processing Controls:**

| Shortcut | Action |
|:---------|:-------|
| ⇧⌘P | Pause/Resume processing |
| ⌘. | Cancel processing |

### 6.3 Drag and Drop

**Drop Targets:**
1. Input tab file list
2. Input tab content area
3. Application dock icon

**Accepted Types:**
- PDF documents
- Images: PNG, JPEG, TIFF, GIF, WebP
- Text files: TXT, MD, RTF, DOCX

**Drop Feedback:**
```
┌───────────────────────────────────────────────────────────┐
│                                                           │
│              ╔═══════════════════════════╗                │
│              ║     + 5 documents         ║                │
│              ╚═══════════════════════════╝                │
│                                                           │
│         Drop PDF, PNG, JPEG, or text files                │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 6.4 Context Menus

**Input/OCR Document Context Menu:**
```
┌─────────────────────────────┐
│ Process                ⌘R   │
├─────────────────────────────┤
│ Show in Finder              │
├─────────────────────────────┤
│ Delete                 ⌫    │
└─────────────────────────────┘
```

**Clean Document Context Menu:**
```
┌─────────────────────────────┐
│ Save to Library        ⌘L   │  ← If not in library
│ Show in Library             │  ← If in library
├─────────────────────────────┤
│ Start Cleaning         ⌘K   │
│ Re-clean                    │  ← If already cleaned
├─────────────────────────────┤
│ Show in Finder              │
├─────────────────────────────┤
│ Delete                 ⌫    │
└─────────────────────────────┘
```

**Library Document Context Menu:**
```
┌─────────────────────────────┐
│ Export...              ⌘E   │
│ Copy to Clipboard      ⇧⌘C  │
├─────────────────────────────┤
│ Show in Finder              │
├─────────────────────────────┤
│ Remove from Library    ⌫    │
└─────────────────────────────┘
```

### 6.5 Selection Model

**Single Selection:**
- Click to select
- Selection persists until changed
- Selected document shows in content preview and inspector

**Tab-Specific Selection:**
- Each tab maintains its own selection state
- Switching tabs preserves selection in each tab
- `selectedInputDocumentId`, `selectedCleanDocumentId`, `selectedLibraryDocumentId`

---

## 7. State Transitions

### 7.1 Application States

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         APPLICATION STATE MACHINE                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────────┐                                                               │
│  │    Launch    │                                                               │
│  └──────┬───────┘                                                               │
│         │                                                                       │
│         ├─── No API Keys ───▶ ┌─────────────┐                                   │
│         │                     │ Onboarding  │                                   │
│         │                     │   (Sheet)   │                                   │
│         │                     └──────┬──────┘                                   │
│         │                            │                                          │
│         │ Has API Key(s)             │ Configure                                │
│         │                            ▼                                          │
│         └───────────────────▶ ┌─────────────────────────────────────────────┐   │
│                               │              Main Window                     │   │
│                               │  ┌─────────────────────────────────────────┐ │   │
│                               │  │ Input → OCR → Clean → Library          │ │   │
│                               │  └─────────────────────────────────────────┘ │   │
│                               └─────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Document Pipeline State

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         DOCUMENT PIPELINE STATE                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  [Import]                                                                       │
│      │                                                                          │
│      ▼                                                                          │
│  ┌─────────┐                                                                    │
│  │ Pending │ ◀───────────────────────────────────────────────┐                  │
│  └────┬────┘                                                 │                  │
│       │                                                      │                  │
│       │ Start OCR                                            │ Retry            │
│       ▼                                                      │                  │
│  ┌────────────┐                                              │                  │
│  │ Processing │ ─── Error ───▶ ┌────────┐                    │                  │
│  │   (OCR)    │                │ Failed │────────────────────┘                  │
│  └──────┬─────┘                └────────┘                                       │
│         │                                                                       │
│         │ Success                                                               │
│         ▼                                                                       │
│  ┌───────────┐                                                                  │
│  │ Completed │ ────────────────────────────────────────┐                        │
│  │   (OCR)   │                                         │                        │
│  └─────┬─────┘                                         │                        │
│        │                                               │                        │
│        │ Start Cleaning (⌘K)                           │                        │
│        ▼                                               │                        │
│  ┌────────────┐                                        │                        │
│  │ Processing │ ─── Error ───▶ ┌────────┐              │                        │
│  │ (Cleaning) │                │ Failed │              │                        │
│  └──────┬─────┘                └───┬────┘              │                        │
│         │                          │                   │                        │
│         │ Success                  │ Retry             │                        │
│         ▼                          ▼                   │                        │
│  ┌───────────┐                                         │                        │
│  │  Cleaned  │ ◀───────────────────────────────────────┘                        │
│  └─────┬─────┘                                                                  │
│        │                                                                        │
│        │ Save to Library (⌘L)                                                   │
│        ▼                                                                        │
│  ┌───────────┐                                                                  │
│  │ In Library│                                                                  │
│  └───────────┘                                                                  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 7.3 Cleaning State Machine

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         CLEANING VIEW MODEL STATE                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────┐                                                                   │
│  │  Ready   │ ◀───────────────────────────────────────────┐                     │
│  │ (idle)   │                                             │                     │
│  └────┬─────┘                                             │                     │
│       │                                                   │                     │
│       │ startCleaning()                                   │ reset()             │
│       ▼                                                   │                     │
│  ┌────────────────────────────────────────────────────────┴──────────────┐      │
│  │                         Processing                                     │      │
│  │  ┌────────────────────────────────────────────────────────────────┐   │      │
│  │  │ For each enabled step (1-14):                                  │   │      │
│  │  │   1. Update currentStep                                        │   │      │
│  │  │   2. For each chunk:                                           │   │      │
│  │  │      - Send to Claude API                                      │   │      │
│  │  │      - Validate response (Phase A/B)                           │   │      │
│  │  │      - Apply changes or use heuristic fallback                 │   │      │
│  │  │      - Update progress                                         │   │      │
│  │  │   3. Record step result                                        │   │      │
│  │  │   4. completedStepCount += 1                                   │   │      │
│  │  └────────────────────────────────────────────────────────────────┘   │      │
│  └───────────────────────────────────────────────────────────────────────┘      │
│       │                    │                                                    │
│       │ Success            │ Error / Cancel                                     │
│       ▼                    ▼                                                    │
│  ┌───────────┐        ┌───────────┐                                             │
│  │ Completed │        │  Failed   │                                             │
│  │ isComplete│        │ isFailed  │                                             │
│  │   = true  │        │   = true  │                                             │
│  └───────────┘        └───────────┘                                             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Error & Empty States

### 8.1 Empty States by Tab

**Input Tab (No Documents):**
```
Icon: arrow.down.doc.fill
Title: Drop Documents Here
Description: Add PDF, image, or text files to begin processing.
             Drag and drop or click Add in the toolbar.
Accent: Blue
```

**OCR Tab (No Documents):**
```
Icon: doc.text.viewfinder
Title: No Documents to Process
Description: Add documents in the Input tab, then return here to run OCR.
Action: [Go to Input]
Accent: Blue
```

**Clean Tab (No Documents):**
```
Icon: sparkles
Title: No Documents to Clean
Description: Process documents through OCR first, then they'll appear here.
Action: [Go to Input]
Accent: Purple
```

**Clean Tab (No Claude API Key):**
```
Icon: doc.text
Title: Select a Document
Description: Choose a document from the list to configure and start cleaning.
Warning: ⚠️ Claude API key required for cleaning
Action: [Configure API Key]
Accent: Orange
```

**Library Tab (Empty):**
```
Icon: books.vertical
Title: Library is Empty
Description: Save cleaned documents here for export.
             Clean a document and click "Save to Library".
Accent: Green
```

### 8.2 Error States

**Processing Error (OCR):**
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│            [exclamationmark.triangle.fill]                  │
│                                                             │
│                   OCR Processing Failed                     │
│                                                             │
│  The Mistral API returned an error:                         │
│  "Invalid API key or rate limit exceeded"                   │
│                                                             │
│                [Open Settings]    [Retry]                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Cleaning Error:**
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│            [exclamationmark.triangle.fill]                  │
│                                                             │
│                   Cleaning Failed                           │
│                                                             │
│  Step "Remove Back Matter" failed:                          │
│  "Claude API request timed out after 3 retries"             │
│                                                             │
│  Partial progress has been saved.                           │
│                                                             │
│                   [Try Again]    [Dismiss]                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Validation Rejection (Logged, not shown to user):**
When Claude's boundary detection fails validation, the system:
1. Logs the rejection reason
2. Falls back to heuristic detection
3. Continues processing silently

User only sees a failure if both AI and heuristic methods fail.

### 8.3 Confirmation Dialogs

**Delete Document:**
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Delete Document?                                           │
│                                                             │
│  Are you sure you want to delete "document-name.pdf"?       │
│  This cannot be undone.                                     │
│                                                             │
│                         [Cancel]    [Delete]                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Clear Input Queue:**
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Clear Input Queue?                                         │
│                                                             │
│  This will remove all 12 documents from the input queue.    │
│  Documents already processed will remain in the Library.    │
│                                                             │
│                         [Cancel]    [Clear All]             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Cancel Cleaning:**
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Cancel Cleaning?                                           │
│                                                             │
│  Cleaning is 65% complete (Step 9 of 14).                   │
│  Partial results will not be saved.                         │
│                                                             │
│                         [Continue]    [Cancel]              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Accessibility

### 9.1 VoiceOver Support

**Document Row Accessibility:**
```swift
DocumentRow(document: document)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(document.displayName)")
    .accessibilityValue(document.accessibilityStatusDescription)
    .accessibilityHint("Double-tap to select. Use context menu for more options.")
```

**Status Descriptions:**
```swift
extension Document {
    var accessibilityStatusDescription: String {
        var parts: [String] = []
        
        if let result = result {
            parts.append("\(result.pageCount) pages")
            parts.append("\(result.wordCount) words")
        }
        
        if isCleaned {
            parts.append("Cleaned")
        }
        
        if isInLibrary {
            parts.append("In Library")
        }
        
        return parts.joined(separator: ", ")
    }
}
```

### 9.2 Keyboard Accessibility

All interactive elements are:
- Focusable via Tab key
- Activatable via Space/Enter
- Have visible focus rings

**Focus Order:**
1. Tab navigation sidebar
2. File list header (search)
3. File list documents
4. Content header actions
5. Content preview
6. Inspector sections

### 9.3 Dynamic Type

All text scales with system text size:

```swift
Text(document.displayName)
    .font(DesignConstants.Typography.documentName)  // Uses system font
```

### 9.4 Reduced Motion

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
    // State change
}
```

### 9.5 Color Accessibility

- Status is conveyed via icon + text, not color alone
- All text meets WCAG 2.1 AA contrast (4.5:1)
- Supports system Increased Contrast mode
- Pipeline badges use both color and text labels

---

## 10. Animation & Motion

### 10.1 Timing

```swift
enum Animation {
    static let fast: Double = 0.15      // Quick transitions
    static let standard: Double = 0.2   // Standard transitions
    static let slow: Double = 0.3       // Deliberate transitions
}
```

### 10.2 Transitions

**Tab Switch:**
- Content crossfade: 200ms ease-in-out
- Selection state preserved per tab

**Document Selection:**
- Immediate highlight
- Preview content crossfade: 150ms

**Processing Overlay:**
- Fade in: 200ms ease-out
- Fade out: 150ms ease-in

**Progress Updates:**
- Linear animation for progress bars
- 100ms duration for smooth updates

### 10.3 Processing Indicators

**Cleaning Progress:**
- Overall progress bar: Determinate (0-100%)
- Step indicator: Updates per step completion
- Chunk indicator: Shows chunk progress for large documents

**Time Estimates:**
- Updates every 5 seconds during processing
- Format: "~45 seconds" or "~2 minutes"

### 10.4 Micro-interactions

**Button Press:**
- System default highlight
- Haptic feedback on completion actions (where supported)

**Pipeline Badge Appearance:**
- Fade in when pipeline stage completes
- No animation on initial load

**Save to Library:**
- Brief green flash on success
- Document row badge updates immediately

---

## Document History

| Version | Date | Author | Changes |
|:--------|:-----|:-------|:--------|
| 1.0 | January 2025 | Claude | Initial draft |
| 2.0 | January 2026 | Claude | Major update: 5-tab architecture, 4-point grid system, Clean tab with processing overlay, shared component library, dual API key management, cleaning workflow documentation |

---

*This document is part of the Horus documentation suite.*
*Previous: API Integration Guide*
*Next: Implementation Guide*
