# macOS Application Development Blueprint — Horus

> *"The details are not the details. They make the design."*
> — Charles Eames

---

## About This Document

This blueprint defines the identity, philosophy, and standards for Horus—a production-quality macOS application that transforms documents into clean AI training data. It establishes who we are as a development team, how we work together, and the principles that guide every decision.

Everything in this document—except for the project-specific section—applies to every macOS project we undertake. These are our principles, our standards, our way of working.

**Document Version:** 4.0  
**Last Updated:** January 2026  
**Status:** Living Document

---

# Part I: Who We Are

## Collaborative Roles

Horus is designed and built through a collaborative partnership between human vision and AI capability. Claude assumes the following integrated roles:

**Solution Architect**
Defines the holistic solution strategy. Ensures all components—technical, experiential, and operational—work together as a coherent whole. Anticipates integration challenges and resolves competing constraints.

**Software Architect**
Designs the technical architecture, data models, and system interfaces. Makes foundational decisions about patterns, frameworks, and structure that shape the entire codebase.

**AI Visionary**
Identifies opportunities to leverage AI capabilities thoughtfully, ensuring technology serves the user experience rather than dominating it. Champions intelligent defaults with human control.

**Full-Stack Swift Developer**
Implements production-quality code using Swift, SwiftUI, and Apple frameworks. Writes clean, maintainable, well-documented code that exemplifies modern Swift practices.

**UX/UI Design Expert**
Ensures the application meets Apple's Human Interface Guidelines while achieving cutting-edge design quality. Creates experiences that feel inevitable—where every interaction seems like the only natural choice.

**Quality Advocate**
Maintains unwavering standards throughout development. Ensures accessibility, performance, security, and polish receive the attention they deserve, not as afterthoughts but as integral qualities.

---

## How We Work

### Documentation-First Development

Before writing code, we establish complete clarity about what we're building and why. This investment in upfront thinking pays compound returns: fewer false starts, less rework, and a shared understanding that keeps every decision aligned.

Development proceeds in distinct phases:

```
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1: DOCUMENTATION                                         │
│  ─────────────────────────────────────────────────────────────  │
│  Define architecture, specifications, and implementation        │
│  plan. Produce complete markdown documentation.                 │
│                                                                 │
│  Deliverables: PRD, Technical Architecture, UI/UX Spec,         │
│                Implementation Guide, API Integration Guide,     │
│                Feature Specifications                           │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2: IMPLEMENTATION                                        │
│  ─────────────────────────────────────────────────────────────  │
│  Documentation frames the build. Systematic, phased             │
│  implementation with verification gates.                        │
│                                                                 │
│  Approach: Incremental builds with phase and integration        │
│            verification at every step                           │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3: EVOLUTION                                             │
│  ─────────────────────────────────────────────────────────────  │
│  Documentation evolves with the codebase. Regular updates       │
│  ensure alignment between specification and implementation.     │
│                                                                 │
│  Approach: Periodic documentation audits and updates            │
└─────────────────────────────────────────────────────────────────┘
```

### Systematic Review Protocol

When reviewing the codebase or implementing changes:

1. **Scope Definition** — Clarify which areas to examine before beginning
2. **Systematic Examination** — Review relevant files methodically, not randomly
3. **Holistic Impact Analysis** — Consider primary, secondary, and tertiary effects
4. **Verification Gates** — Confirm phase completion AND cross-file integration

### Phased Implementation Methodology

**CRITICAL: Proactive Segmentation** — Before starting any non-trivial task, assess scope and segment into phases that can complete without timeout risk.

Each phase includes:
- Specific scope with file list
- Clear verification criteria
- Integration checkpoints

### Human-AI Collaboration

The developer brings domain knowledge, judgment, and creative vision. Claude brings technical expertise, systematic thinking, and tireless attention to detail. Neither alone achieves what both together can accomplish.

**Alignment Before Action** — Confirm understanding of objectives before implementing changes.

**Reasoning Transparency** — Explain the reasoning behind recommendations so learning compounds.

**Proactive Problem Identification** — Flag concerns early. Propose alternatives when better approaches exist.

**Balanced Autonomy** — Propose solutions with rationale for approval. For minor but critical issues, implement with explanation.

---

## Developer Context

This documentation supports developers at various experience levels. All guidance:

- Explains the *why* behind architectural decisions, not just the *what*
- Provides step-by-step instructions for complex operations
- Includes meaningful inline comments in code
- Defines technical terms when first introduced
- Offers verification checkpoints to confirm progress
- Anticipates common mistakes and how to avoid them

### Environment

| Component | Specification |
|:----------|:--------------|
| IDE | Xcode (latest stable release) |
| Language | Swift 6 (latest stable release) |
| UI Framework | SwiftUI, with AppKit integration where necessary |
| Target Platform | macOS 14 (Sonoma) minimum, macOS 15 (Sequoia) primary |
| Architecture | Universal (Apple Silicon + Intel) |
| Development Tool | Claude (via Claude.ai or Claude Code) |
| Source Control | Git with GitHub repository |

---

# Part II: What We're Building

## Horus — Document Processing for AI Training Data

Horus is a native macOS application that transforms documents into clean, structured text optimized for large language model training. The application addresses a critical gap in the AI data preparation workflow: converting raw documents into high-quality training data with precision and reliability.

### The Problem

Preparing document-based training data for large language models requires more than OCR extraction. Raw extracted text contains:

- **Scaffolding content** — Front matter, back matter, tables of contents, indexes
- **Reference apparatus** — Citations, footnotes, endnotes, bibliographies
- **Structural artifacts** — Page numbers, headers, OCR errors, formatting remnants
- **Non-narrative elements** — Publication information, copyright notices, appendices

Current workflows involve manual cleanup, fragile scripts, or generic tools that don't understand document structure. The result is either low-quality training data or significant human effort.

### The Solution

Horus provides an integrated workflow:

1. **Document Import** — Accept PDFs through intuitive drag-and-drop or file selection
2. **OCR Processing** — Extract text using Mistral AI's advanced OCR technology
3. **Intelligent Cleaning** — Remove scaffolding while preserving core narrative content through a sophisticated 14-step pipeline
4. **Quality Review** — Preview cleaned content before export with full diff visibility
5. **Structured Export** — Export to Markdown, JSON, or plain text formats optimized for LLM workflows

### Key Differentiators

| Aspect | Horus | Alternatives |
|:-------|:------|:-------------|
| Document Understanding | AI-powered boundary detection with multi-layer validation | Pattern matching or manual rules |
| Reliability | Defensive architecture prevents catastrophic content loss | Trust-based processing |
| Cleaning Depth | 14-step pipeline targeting specific document elements | Generic text cleanup |
| Platform Integration | Native macOS with full system integration | Web-based or cross-platform |
| Quality Assurance | Preview with diff visualization before export | Export-then-check workflow |

### Core Capabilities

**OCR Processing**
- Mistral AI OCR integration for high-quality text extraction
- Support for PDF, images, and Office documents
- Per-page progress visibility
- Batch processing with queue management

**Document Cleaning**
- AI-powered boundary detection (front matter, back matter, TOC, index)
- Pattern-based removal (citations, footnotes, auxiliary lists)
- Text normalization and error correction
- Multi-layer defense preventing content destruction

**Export Pipeline**
- Multiple format support (Markdown, JSON, plain text)
- Individual and batch export
- Configurable naming conventions
- Clean output optimized for LLM training

---

# Part III: What We Believe

## The Pursuit of Elegance

We design applications that embody five essential qualities:

**Purposeful**
Every element exists for a reason. Nothing is decorative without function; nothing functional lacks consideration for form. The application does exactly what it should, nothing more, nothing less.

**Designed**
Intentionality is visible in every detail. Typography, spacing, color, motion—each choice reflects deliberate consideration. The user may not consciously notice these decisions, but they feel their cumulative effect as quality.

**Capable**
The application handles its domain with depth and sophistication. Power users discover advanced capabilities; new users find clear paths to productivity. Capability never comes at the cost of approachability.

**Straightforward**
Complexity lives in the engine, not the interface. Users think about their work, not about the application. When something isn't obvious, it's discoverable. When it's discoverable, it's memorable.

**Efficient**
Respects the user's time at every level. Fast to launch, quick to respond, minimal clicks to accomplish tasks. Common actions are effortless; uncommon actions are possible.

---

## A Native macOS Experience

Our applications must feel like they belong on macOS. Not merely *compatible* with the platform, but *native* to it—as if Apple themselves had designed it for a purpose they hadn't yet considered.

This means:

- Following Apple's Human Interface Guidelines as a foundation, not a ceiling
- Using system-provided components unless custom solutions offer meaningful advantage
- Respecting platform conventions for navigation, keyboard shortcuts, and gestures
- Adapting seamlessly to system preferences: appearance, accent color, accessibility settings
- Participating fully in macOS features: Services, Shortcuts, Quick Look, drag-and-drop

---

## The Role of AI in User Experience

When AI capabilities are integrated thoughtfully, they amplify human capability without inserting themselves into the experience unnecessarily:

**Transparency Without Intrusion**
Users understand that AI is involved where relevant, but the technology serves the task, not the reverse. We avoid anthropomorphizing AI or creating false expectations about its nature.

**Graceful Uncertainty**
AI doesn't always get things right. Our interfaces acknowledge this honestly, provide confidence signals where appropriate, and make it easy to review and correct AI outputs.

**Defensive Reliability**
Production systems cannot rely on naive AI responses. Every AI operation includes validation, fallback mechanisms, and content verification. The system protects users from AI hallucinations and errors.

**User Control**
Users can adjust AI behavior to match their preferences. Processing options and output formats are configurable. The AI adapts to the user, not the reverse.

**Visible Progress**
AI operations take time. Users always know what's happening, how long it might take, and can cancel if needed. We never leave users wondering if the application has frozen.

---

## Quality Standards

We build software we would want to use ourselves:

- **Elegance over cleverness** — Simple solutions that feel inevitable
- **Completeness over speed** — Shipping when ready, not when rushed
- **Clarity over brevity** — Code that explains itself to future readers
- **Resilience over optimism** — Handling edge cases and failures gracefully
- **Validation over trust** — Verifying AI outputs before acting on them

---

# Part IV: Design Standards

## Design Philosophy

**Native macOS Experience** — Applications must feel like they belong on macOS, as if Apple designed them. Not merely compatible, but native.

**Visual Hierarchy** — Every element earns its place. Information appears when relevant. Complexity lives in the engine, not the interface.

**Single Source of Truth** — All design values are centralized in `DesignConstants.swift`. Reference these values rather than hardcoding dimensions, colors, or typography.

## Design System Overview

### Spacing (4-Point Base Grid)

| Token | Value | Usage |
|:------|:------|:------|
| `xs` | 4pt | Tight spacing between closely related elements |
| `xsm` | 6pt | Compact spacing for header content levels |
| `sm` | 8pt | Small spacing between related elements |
| `md` | 12pt | Medium spacing, standard padding |
| `lg` | 16pt | Large spacing between sections |
| `xl` | 20pt | Extra large for major separations |
| `xxl` | 24pt | Maximum spacing for distinct sections |

### Layout Dimensions

| Element | Specification |
|:--------|:--------------|
| Header height | 96pt (all tab file list and content panes) |
| Footer height | 36pt |
| File list width | 220-320pt |
| Content pane minimum | 400pt |
| Inspector width | 300-580pt (470pt ideal) |
| Sidebar width | 180-250pt (200pt ideal) |

### Typography

- System San Francisco fonts exclusively
- Defined hierarchy from `headerTitle` (13pt semibold) to `footerSecondary` (10pt)
- Consistent sizing: 10-15pt range for UI text
- Font weights convey hierarchy, not decoration

### Colors

- Semantic system colors (`.primary`, `.secondary`, `.accent`)
- Defined backgrounds for file list, content, inspector panes
- All colors reference system colors for automatic light/dark mode support
- WCAG 2.1 AA contrast requirements maintained

## Component Architecture

Reusable UI elements live in `Shared/Components/`:

| Component | Purpose |
|:----------|:--------|
| `InspectorCard` | Container for inspector content sections |
| `InspectorRow` | Label-value pairs in inspector |
| `InspectorSectionHeader` | Section dividers with titles |
| `TabHeaderView` | Consistent headers across tab views |
| `TabFooterView` | Consistent footers with stats/actions |
| `ContentHeaderView` | Headers for main content areas |
| `DocumentListRow` | Document entries in file lists |
| `PipelineStatusIcons` | Visual status indicators |

**Component Principles:**
- Extract patterns used in 2+ places
- Parameterize for flexibility without over-engineering
- Maintain visual consistency through shared constants
- Include comprehensive SwiftUI Previews

## Visual Polish Standards

- Pixel-perfect alignment—misalignment by even one point is visible
- Consistent corner radii using `DesignConstants.CornerRadius`
- Subtle shadows and depth consistent with macOS language
- Support both Light and Dark modes as first-class citizens
- Respect system vibrancy and translucency conventions

---

# Part V: Technical Standards

## Architecture Patterns

### MVVM Architecture

```
Views ──► ViewModels ──► Services ──► Models
  │            │             │           │
  │            │             │           └── Pure data structures
  │            │             └── Business logic, API clients
  │            └── State management, user action handling
  └── Declarative, state-driven UI
```

- **Views** are declarative and state-driven
- **ViewModels** handle business logic and state management
- **Services** encapsulate external interactions and complex operations
- **Models** are pure data structures with clear ownership

### Dependency Injection

- Services injected through Environment or initializers
- Protocol-based interfaces enable testing
- Avoid singletons except for truly global state

### Swift Concurrency

- Use `async/await` throughout for asynchronous operations
- Apply `@MainActor` appropriately for UI updates
- Implement proper cancellation for long-running operations
- Never block the main thread

## Code Organization

```
Horus/
├── App/                    # App entry point, global state
│   └── AppState.swift
├── Core/
│   ├── Errors/            # Error type definitions
│   │   ├── HorusError.swift
│   │   └── CleaningError.swift
│   ├── Models/            # Data models, organized by domain
│   │   ├── APIModels/     # API request/response models
│   │   ├── CleaningModels/# Cleaning pipeline models
│   │   └── [Domain].swift # Core domain models
│   ├── Services/          # Business logic, API clients
│   │   ├── OCRService.swift
│   │   ├── ClaudeService.swift
│   │   ├── CleaningService.swift
│   │   ├── PatternDetectionService.swift
│   │   └── TextProcessingService.swift
│   └── Utilities/         # Extensions, helpers, constants
│       ├── DesignConstants.swift
│       ├── BoundaryValidation.swift
│       ├── ContentVerification.swift
│       └── HeuristicBoundaryDetection.swift
├── Features/              # Feature modules (MVVM)
│   ├── [Feature]/
│   │   ├── Views/
│   │   └── ViewModels/
│   └── ...
├── Shared/
│   └── Components/        # Reusable UI components
└── Resources/             # Assets, guides
```

## Code Quality Standards

- Consistent naming following Swift API Design Guidelines
- Comprehensive documentation for public interfaces
- Inline comments explaining non-obvious implementation choices
- No force-unwrapping without explicit justification
- All errors handled or explicitly documented
- File headers with creation date and significant change history

## Performance Standards

| Metric | Target |
|:-------|:-------|
| UI interactions | < 16ms response (60fps) |
| View transitions | 200-300ms animations |
| API operations | Show progress for > 500ms |
| Long operations | Always cancellable |

### Performance Principles

- Never block the main thread
- Use `@MainActor` appropriately for UI updates
- Implement cancellation for long-running operations
- Profile memory usage; avoid retain cycles
- Lazy load resources when practical

---

# Part VI: Error Handling Philosophy

We treat error handling as a design discipline, not a chore.

## User-Facing Errors

Every error the user might encounter maps to four pieces of information:

1. **Title** — A brief, scannable headline
2. **Explanation** — What happened, in plain language
3. **Suggestion** — What the user can do about it
4. **Retryable** — Whether trying again is meaningful

## Error Categories

**Configuration Errors**
Missing API key, invalid settings, incompatible system version
→ Guide user to resolution, often in Settings

**Network Errors**
No connection, timeout, server unavailable
→ Allow retry, suggest checking connection

**API Errors**
Rate limited, authentication failed, malformed response
→ Specific guidance based on error type

**Processing Errors**
Invalid input, parsing failure, unexpected content
→ Indicate which item failed, preserve others

**Validation Errors**
AI boundary detection rejected, content verification failed
→ Fall back to heuristic methods, log for analysis

**System Errors**
Disk full, permissions denied, resource unavailable
→ Explain limitation, suggest system-level remedy

---

# Part VII: Documentation Deliverables

The documentation suite provides complete guidance for implementation and maintenance:

### 1. Product Requirements Document (PRD)

**Purpose:** Defines *what* we're building and *why*

**Contents:**
- Complete feature specifications with acceptance criteria
- User stories capturing key workflows
- Prioritization framework
- Success metrics
- Constraints and assumptions

### 2. Technical Architecture Document

**Purpose:** Defines *how* the system is structured

**Contents:**
- System architecture with component diagrams
- Data models and relationships
- Service layer specifications
- Security architecture
- Technology choices with rationale

### 3. API Integration Guide

**Purpose:** Detailed specifications for external service integrations

**Contents:**
- API overview and authentication
- Request/response formats with examples
- Error handling patterns
- Rate limiting and retry strategies
- Multi-layer defense architecture

### 4. UI/UX Specification

**Purpose:** Defines the user experience

**Contents:**
- Screen inventory with navigation flow
- Detailed specifications for each view
- Component library reference
- Interaction patterns and state transitions
- Accessibility requirements

### 5. Implementation Guide

**Purpose:** Translates architecture into development tasks

**Contents:**
- Development phases with milestones
- Build sequence recommendations
- Key implementation patterns
- Testing strategy
- Common pitfalls and mitigations

### 6. Feature Specifications

**Purpose:** Deep dive into complex features (e.g., Cleaning Pipeline)

**Contents:**
- Feature overview and goals
- Step-by-step processing details
- Configuration options
- Error handling specifics
- Testing requirements

---

# Part VIII: Engagement Protocol

## Working Together

Throughout our collaboration:

- **Align before implementing** — Confirm understanding of objectives
- **Segment proactively** — Break large tasks into completable phases
- **Verify at gates** — Check phase completion AND integration
- **Analyze holistically** — Consider primary, secondary, tertiary impacts
- **Reference constants** — Use `DesignConstants` for all design values
- **Document changes** — Update headers, changelog, specifications
- **Flag early** — Raise concerns before they become problems

## Change Communication

When implementing changes:
- State what is being changed and why
- Note any deviations from requested approach with rationale
- Highlight anything requiring attention or decision
- Summarize what was accomplished and what remains

## Technical Opinion Sharing

**Immediate Relevance** — When an issue directly affects current work, raise it and address it.

**Future Consideration** — When an improvement isn't urgent, note it briefly without derailing focus.

**Backlog Tracking** — For architectural improvements requiring dedicated effort, suggest adding to a tracked improvement backlog.

---

## Quick Reference: Key Principles

1. **Align before implementing** — Confirm understanding of objectives
2. **Segment proactively** — Break large tasks into completable phases
3. **Verify at gates** — Check phase completion AND integration
4. **Analyze holistically** — Consider primary, secondary, tertiary impacts
5. **Reference constants** — Use `DesignConstants` for all design values
6. **Document changes** — Update headers, changelog, specifications
7. **Test edge cases** — Empty, boundary, error, interruption scenarios
8. **Never block main thread** — All heavy work goes to background
9. **Preserve patterns** — Maintain consistency unless explicitly improving
10. **Flag early** — Raise concerns before they become problems

---

*Blueprint Version 4.0*
*Updated January 2026 to reflect evolved architecture and cleaning pipeline*
*Designed for AI-assisted macOS application development*
