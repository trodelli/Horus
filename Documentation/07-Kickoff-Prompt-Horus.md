# Horus V2 Implementation Kickoff Prompt

> **Version:** 2.0  
> **Last Updated:** January 2026  
> **Purpose:** Initialize a Claude session with complete project context

Use this prompt to begin implementation work with Claude. Copy everything below the line.

---

## Project: Horus V2 — Intelligent Document Processing for macOS

I'm building **Horus**, a production-grade native macOS application that transforms documents into clean, AI-ready content. The app provides a complete pipeline from PDF/image input through OCR extraction to intelligent cleaning, optimized for LLM training data preparation and RAG systems.

### Core Architecture

Horus implements a **dual-API architecture**:

| Component | Technology | Purpose |
|:----------|:-----------|:--------|
| **OCR Engine** | Mistral AI (pixtral-large-2501) | Extract text from PDFs and images |
| **Cleaning Engine** | Anthropic Claude (claude-sonnet-4-20250514) | Intelligent content processing |

### Application Structure

The app follows a **5-tab workflow** reflecting the document lifecycle:

```
┌───────────────────────────────────────────────────────────────────────┐
│  [Input]  →  [OCR]  →  [Clean]  →  [Library]  →  [Settings]          │
└───────────────────────────────────────────────────────────────────────┘
     │           │          │            │              │
     │           │          │            │              └─ API keys,
     │           │          │            │                 defaults
     │           │          │            │
     │           │          │            └─ Browse processed
     │           │          │               documents, export
     │           │          │
     │           │          └─ 14-step Claude-powered
     │           │             cleaning pipeline
     │           │
     │           └─ Mistral OCR processing
     │              with progress tracking
     │
     └─ Import PDFs/images,
        manage queue
```

### Documentation Suite

I have a complete V2.0 documentation suite defining the full application:

| Doc | Title | Contents |
|:----|:------|:---------|
| **01** | PRD | Product requirements, user stories, acceptance criteria |
| **02** | Technical Architecture | System design, data models, service layer, code organization |
| **03** | API Integration Guide | Mistral OCR + Claude APIs, request/response formats, error handling |
| **04** | UI/UX Specification | Screen designs, component library, 5-tab navigation |
| **05** | Implementation Guide | Phase-by-phase build sequence with verification checkpoints |
| **06** | Cleaning Feature Spec | 14-step pipeline, presets, content-type detection |
| **07** | Cleaning Implementation Plan | Detailed build sequence for cleaning feature |
| **08** | macOS Blueprint | Swift/SwiftUI patterns, architecture decisions |

**Please read all documentation before we begin.** They contain the complete specification.

### Key V2 Features

**14-Step Cleaning Pipeline** organized into 5 phases:
- Phase 1: Extraction & Analysis (metadata, content-type detection)
- Phase 2: Structural Removal (front matter, TOC, auxiliary lists, page numbers, headers/footers)
- Phase 3: Content Cleaning (citations, footnotes, reflow, character cleaning)
- Phase 4: Back Matter Removal (index, appendices)
- Phase 5: Optimization & Assembly (paragraph optimization, structure addition)

**4 Presets** for common use cases:
- **Default**: Balanced cleaning for most documents
- **Training**: Aggressive cleaning for LLM training data
- **Minimal**: Light touch, preserve original structure
- **Scholarly**: Academic documents optimized for training

**Content-Type Awareness**: Pipeline adapts behavior based on detected content (poetry, code, academic, legal, children's, etc.)

**Library-Centric Workflow**: Documents persist and are browsable; cleaning results coexist with raw OCR.

### Design Standards

The codebase follows strict standards defined in `DesignConstants.swift`:

- **4-point spacing grid**: xs(4), xsm(6), sm(8), md(12), lg(16), xl(20), xxl(24)
- **Layout dimensions**: Header 96pt, Footer 36pt, defined pane widths
- **Typography hierarchy**: System SF fonts, 10-15pt UI text range
- **Component architecture**: Shared components in `Shared/Components/`

### Development Approach

We build incrementally with verification at each phase:

| Phase | Focus | Deliverable |
|:------|:------|:------------|
| **Foundation** | Project setup, models, app shell | Launching app with navigation |
| **Core Services** | Keychain, network, cost calculation | Settings with API key storage |
| **Document Management** | Import, queue, validation | Import and display documents |
| **OCR Processing** | Mistral integration, progress | Process documents with OCR |
| **Cleaning Pipeline** | Claude integration, 14 steps | Full cleaning with presets |
| **Library & Export** | Persistence, search, export | Browse and export results |
| **Polish** | Edge cases, accessibility, tests | Production-ready application |

Each phase produces working software. We verify before proceeding.

### My Environment

- **macOS:** [YOUR VERSION, e.g., Sequoia 15.2]
- **Xcode:** [YOUR VERSION, e.g., 16.2]
- **Swift:** [YOUR VERSION, e.g., 6.0]
- **Experience Level:** [YOUR LEVEL] — please calibrate explanations accordingly

### How We Work Together

1. **Documentation first** — Reference the spec before writing code
2. **Phase by phase** — Complete and verify each phase
3. **Explain decisions** — Help me understand the *why*
4. **Verify at checkpoints** — Confirm functionality before proceeding
5. **Follow standards** — Use `DesignConstants`, follow established patterns
6. **Commit incrementally** — Meaningful git commits at milestones

### Project Instructions

Our collaboration follows established methodology documented in `PROJECT_INSTRUCTIONS.md`:

**Key Principles:**
- Alignment before action — confirm understanding before implementing
- Holistic impact analysis — consider primary, secondary, tertiary effects
- Phased implementation — segment large tasks proactively
- Verification gates — phase verification AND integration verification
- Documentation updates — keep specs aligned with implementation

**Technical Standards:**
- MVVM architecture with clear separation
- Swift concurrency (async/await, @MainActor)
- Protocol-oriented design for testability
- File headers with creation/update history

### Getting Started

Let's begin with the current implementation state:

1. **Confirm** you've reviewed the documentation suite
2. **Summarize** your understanding of the architecture
3. **Identify** where we are in the implementation phases
4. **Propose** the next logical work to tackle

If starting fresh, begin with **Phase 1: Foundation**:
- Create Xcode project with correct settings
- Set up folder structure per Technical Architecture
- Implement core data models
- Create app entry point and 5-tab navigation shell

---

## Quick Reference

### File Locations

```
Horus/
├── Documentation/           # All spec documents
├── Horus/
│   ├── App/                # Entry point, global state
│   ├── Core/
│   │   ├── Models/         # Data models by domain
│   │   ├── Services/       # Business logic, API clients
│   │   └── Utilities/      # Extensions, constants
│   ├── Features/           # Feature modules (Input, OCR, Clean, Library, Settings)
│   └── Shared/Components/  # Reusable UI components
└── PROJECT_INSTRUCTIONS.md # Collaboration methodology
```

### Key Models

- `Document` — Imported file with metadata
- `OCRResult` — Mistral extraction output
- `CleanedContent` — Cleaning pipeline output
- `CleaningConfiguration` — 14-step pipeline settings
- `CleaningStep` — Pipeline step enum (1-14)
- `PresetType` — Cleaning presets (default, training, minimal, scholarly)
- `ContentTypeFlags` — Detected content characteristics
- `DetectedPatterns` — Claude-identified document patterns

### Key Services

- `MistralService` — OCR API integration
- `ClaudeService` — Cleaning API integration
- `CleaningService` — Pipeline orchestration
- `DocumentService` — Document lifecycle management
- `KeychainService` — Secure API key storage

---

I'm ready to build. Let's create something excellent.
