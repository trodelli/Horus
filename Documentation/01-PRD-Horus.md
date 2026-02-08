# Product Requirements Document
## Horus — Document Processing for AI Training Data

> **Document Version:** 2.0  
> **Last Updated:** January 2026  
> **Status:** Active Development

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Vision](#2-product-vision)
3. [Target Users](#3-target-users)
4. [Core Concepts](#4-core-concepts)
5. [Feature Specifications](#5-feature-specifications)
6. [User Stories](#6-user-stories)
7. [Prioritization](#7-prioritization)
8. [Success Metrics](#8-success-metrics)
9. [Constraints & Assumptions](#9-constraints--assumptions)
10. [Glossary](#10-glossary)

---

## 1. Executive Summary

### Product Name

**Horus** — Named for the Egyptian god of the sky, whose eye sees all. Horus transforms documents into clean, structured text—revealing the essential content within.

### One-Sentence Description

Horus is a native macOS application that extracts text from documents using advanced OCR, then intelligently cleans and structures that content for AI training data preparation.

### The Problem

Preparing document-based training data for large language models requires more than text extraction. Raw OCR output contains:

- **Scaffolding content** — Front matter, back matter, tables of contents, indexes
- **Reference apparatus** — Citations, footnotes, endnotes, bibliographies
- **Structural artifacts** — Page numbers, running headers, footers
- **OCR noise** — Broken words, misrecognized characters, formatting remnants

Current workflows involve:
- Manual cleanup that doesn't scale
- Fragile scripts that break on document variations
- Generic tools that don't understand document structure
- Separate tools for extraction and cleaning that don't integrate

### The Solution

Horus provides an integrated document processing pipeline:

1. **Import** — Accept documents through intuitive drag-and-drop
2. **Extract** — Process through Mistral AI's advanced OCR technology
3. **Clean** — Remove scaffolding through a 14-step AI-powered pipeline
4. **Review** — Preview results with full diff visualization
5. **Export** — Output structured formats optimized for LLM workflows

The cleaning pipeline uses Claude AI for intelligent boundary detection—identifying where front matter ends and content begins, where back matter starts, where citations appear—combined with multi-layer validation to prevent content destruction.

### Key Differentiators

| Aspect | Horus | Alternatives |
|:-------|:------|:-------------|
| Document Understanding | AI-powered boundary detection with validation | Pattern matching or manual rules |
| Reliability | Multi-layer defense prevents content loss | Trust-based processing |
| Cleaning Depth | 14-step pipeline targeting specific elements | Generic text cleanup |
| Configuration | Four presets + granular step control | One-size-fits-all |
| Platform Integration | Native macOS with full system integration | Web-based or cross-platform |

---

## 2. Product Vision

### Vision Statement

Horus transforms document processing from a technical chore into a reliable, transparent workflow—giving users confidence that their extracted content is clean, complete, and ready for AI training.

### Design Principles

**1. Transparency Over Magic**
Users always understand what's happening. The 14-step pipeline shows each operation. Diff views reveal exactly what changed. Errors explain themselves with actionable guidance.

**2. Defense in Depth**
AI is powerful but imperfect. Every AI operation includes validation layers, heuristic fallbacks, and content verification. The system protects users from AI hallucinations that could destroy content.

**3. Intelligent Defaults, Full Control**
Presets make the application immediately useful for common scenarios. But every step is configurable for users who need precise control over their cleaning operations.

**4. Quality Over Quantity**
The goal is clean, accurate training data—not maximum throughput. The pipeline optimizes for content integrity, not processing speed.

**5. Native Over Novel**
When macOS provides a pattern, we use it. Drag-and-drop, keyboard shortcuts, system dialogs, appearance adaptation—users shouldn't learn new conventions.

### What Horus Is

- A document processing tool for preparing AI training data
- An OCR client using Mistral's advanced extraction technology
- An intelligent cleaning pipeline using Claude for boundary detection
- A native macOS application following platform conventions
- A session-based workflow tool (not a document manager)

### What Horus Is Not

- A document library or archive system
- An editor for OCR results (preview only)
- A general-purpose text cleaner
- An offline tool (requires API connectivity)
- A cross-platform application

---

## 3. Target Users

### Primary Persona: The ML Data Engineer

**Name:** Alex  
**Role:** ML Data Engineer at an AI research company  
**Technical Level:** Expert with APIs and tooling; values automation and reliability

**Goals:**
- Convert document archives into high-quality LLM training datasets
- Ensure consistent, reproducible cleaning across thousands of documents
- Verify extraction and cleaning quality before committing to pipelines
- Maintain full control over what gets removed

**Frustrations:**
- Manual cleanup doesn't scale to corpus sizes needed for training
- Scripts break when document formats vary
- Generic tools don't understand document structure (removing content, keeping noise)
- No visibility into what cleaning actually does

**How Horus Helps:**
- The Training preset provides aggressive cleaning optimized for LLM data
- Step-by-step pipeline visibility shows exactly what's happening
- Multi-layer validation prevents catastrophic content loss
- Diff views reveal every change before export

### Secondary Persona: The Research Data Curator

**Name:** Jordan  
**Role:** Research Data Curator at a digital humanities lab  
**Technical Level:** Capable with tools; not a developer

**Goals:**
- Digitize historical documents and academic papers
- Prepare clean text corpora for computational analysis
- Preserve scholarly apparatus when needed, remove it when not
- Build training datasets for domain-specific models

**Frustrations:**
- Academic documents have complex structure (citations, footnotes, bibliographies)
- Generic OCR tools don't handle scholarly apparatus well
- Quality varies unpredictably across document types
- Need different treatment for different research purposes

**How Horus Helps:**
- The Scholarly preset understands academic document structure
- Toggleable steps for citations, footnotes, auxiliary lists
- Content type detection adjusts processing for academic content
- Preview with diff shows exactly what will be removed

### Tertiary Persona: The Content Operations Lead

**Name:** Sam  
**Role:** Content Operations Lead at a publishing company  
**Technical Level:** Non-technical; needs tools that "just work"

**Goals:**
- Convert legacy PDF archives to clean text
- Prepare content for modern CMS and search systems
- Process batches efficiently without IT involvement
- Maintain quality standards across team members

**Frustrations:**
- Enterprise tools are complex and expensive
- Free tools produce inconsistent results
- No way to verify quality before committing
- Different team members get different results

**How Horus Helps:**
- Simple interface requires no training beyond basic onboarding
- Presets ensure consistent results across team
- Preview reveals quality before export
- Native macOS feel makes adoption easy

---

## 4. Core Concepts

Understanding these concepts is essential for navigating Horus:

### Session

A session represents a single working period. Users import documents, process them through OCR, clean them, review results, and export. Sessions are not persisted between app launches. This model:
- Keeps the application focused
- Avoids complex state management
- Encourages users to complete and export their work
- Eliminates storage concerns for processed documents

### Document

A document is a single file submitted for processing. Supported types:
- **PDF files** — The primary use case (can be multi-page)
- **Images** — PNG, JPEG, and other common formats
- **Office documents** — PPTX, DOCX (converted via OCR API)

Each document progresses through stages: Queued → OCR Processing → OCR Complete → Cleaning → Cleaned → Exported.

### Workflow Stages

Documents move through a defined workflow:

| Stage | Description |
|:------|:------------|
| **Queued** | Imported, awaiting OCR processing |
| **OCR Processing** | Currently being processed by Mistral OCR |
| **OCR Complete** | Text extracted, ready for cleaning |
| **Cleaning** | Currently being processed by cleaning pipeline |
| **Cleaned** | Cleaning complete, ready for export |
| **Exported** | Successfully exported to file system |

### Cleaning Pipeline

The 14-step cleaning pipeline removes scaffolding while preserving core content:

**Phase 1: Extraction & Analysis** (Step 1)
- Extract document metadata (title, author, date)
- Detect content type (poetry, code, academic, etc.)

**Phase 2: Structural Removal** (Steps 2-6)
- Remove front matter (copyright, publisher info)
- Remove table of contents
- Remove auxiliary lists (figures, tables, abbreviations)
- Remove page numbers
- Remove running headers and footers

**Phase 3: Content Cleaning** (Steps 7-10)
- Remove inline citations (APA, MLA, IEEE, etc.)
- Remove footnote markers and footnote sections
- Reflow paragraphs broken by page breaks
- Clean OCR artifacts and special characters

**Phase 4: Back Matter Removal** (Steps 11-12)
- Remove alphabetical index
- Remove appendices and about author sections

**Phase 5: Optimization & Assembly** (Steps 13-14)
- Split long paragraphs at semantic boundaries
- Add document structure (title header, metadata, chapter markers)

### Preset

A preset is a pre-configured combination of enabled steps and parameters optimized for a specific use case:

| Preset | Purpose | Key Characteristics |
|:-------|:--------|:--------------------|
| **Default** | General document cleaning | Balanced removal, preserves citations/footnotes |
| **Training** | AI training data preparation | Aggressive removal of all scholarly apparatus |
| **Minimal** | Light-touch cleaning | Preserves structure, removes only OCR artifacts |
| **Scholarly** | Academic documents | Removes citations/footnotes, preserves content structure |

### Multi-Layer Defense

Every AI boundary detection operation is protected by three validation layers:

1. **Phase A: Response Validation** — Rejects detections that would remove too much content, occur too early in the document, or have too large a span
2. **Phase B: Content Verification** — Confirms detected sections contain expected patterns (e.g., back matter should contain "NOTES", "APPENDIX", "BIBLIOGRAPHY")
3. **Phase C: Heuristic Fallback** — When AI detection fails or is rejected, pattern-based detection provides conservative boundaries

This architecture prevents catastrophic content loss from AI hallucinations.

### Export

Export converts cleaned content to files on disk:
- **Markdown** — Structured text with metadata header
- **JSON** — Structured data with full metadata
- **Plain Text** — Clean text without formatting

---

## 5. Feature Specifications

### 5.1 Application Foundation

#### 5.1.1 First Launch Experience

**Requirement:** Guide new users through essential setup with minimal friction.

**Acceptance Criteria:**
- Onboarding wizard appears on first launch
- User can configure Mistral API key with validation
- User can configure Claude API key with validation
- Clear guidance on obtaining API keys from both providers
- Setup can be completed in under 3 minutes
- User can skip and complete setup later

#### 5.1.2 API Key Management

**Requirement:** Securely store and validate API credentials.

**Acceptance Criteria:**
- API keys stored in macOS Keychain
- Validation confirms key validity before saving
- Clear error messages for invalid or expired keys
- Easy update path when keys need rotation
- Separate management for Mistral and Claude keys

#### 5.1.3 Settings & Preferences

**Requirement:** Centralized configuration for application behavior.

**Acceptance Criteria:**
- API key management (view, update, validate)
- Default preset selection for new cleaning operations
- Default export format selection
- About information with version number
- Links to documentation and support

---

### 5.2 Document Import

#### 5.2.1 Drag-and-Drop Import

**Requirement:** Accept documents through intuitive drag-and-drop.

**Acceptance Criteria:**
- Drag zone provides clear visual feedback
- Accepts PDF, PNG, JPEG, TIFF, WEBP, DOCX, PPTX
- Rejects unsupported file types with clear message
- Shows file count and estimated processing information
- Supports dragging multiple files or folders

#### 5.2.2 File Picker Import

**Requirement:** Alternative import via system file picker.

**Acceptance Criteria:**
- Standard macOS open dialog
- File type filter shows supported formats
- Allows multiple selection
- Remembers last-used directory

#### 5.2.3 Import Validation

**Requirement:** Validate documents before accepting.

**Acceptance Criteria:**
- File size validation (50MB limit for OCR API)
- Page count estimation for PDFs
- Clear rejection messages with reasons
- Graceful handling of corrupted files

---

### 5.3 OCR Processing

#### 5.3.1 OCR Queue Management

**Requirement:** Process documents through OCR sequentially with visibility.

**Acceptance Criteria:**
- Documents queue for OCR processing
- Current document shows processing progress
- Per-page progress for multi-page documents
- Queue position visible for waiting documents
- Cancel available for pending items

#### 5.3.2 OCR Processing

**Requirement:** Extract text using Mistral OCR API.

**Acceptance Criteria:**
- Submit documents to Mistral pixtral-large-latest endpoint
- Handle multi-page documents with page-level progress
- Extract text content in markdown format
- Capture document metadata (dimensions, page count)
- Handle API errors with appropriate retry logic

#### 5.3.3 OCR Results

**Requirement:** Store and display OCR results.

**Acceptance Criteria:**
- Extracted text available immediately after processing
- Page-by-page text breakdown available
- Raw markdown preserves extraction structure
- Metadata captured (processing time, token usage)

---

### 5.4 Document Cleaning

#### 5.4.1 Cleaning Pipeline Execution

**Requirement:** Process documents through 14-step cleaning pipeline.

**Acceptance Criteria:**
- Steps execute in defined order
- Each step shows progress and status
- Steps can complete, skip, or fail independently
- Full pipeline can be cancelled mid-execution
- Word count and change count tracked per step

#### 5.4.2 Preset Selection

**Requirement:** Allow users to select cleaning presets.

**Acceptance Criteria:**
- Four presets available: Default, Training, Minimal, Scholarly
- Preset descriptions explain intended use case
- Selecting preset configures all step toggles
- "Modified" indicator when user changes from preset defaults

#### 5.4.3 Step Configuration

**Requirement:** Allow granular control over cleaning steps.

**Acceptance Criteria:**
- All 14 steps visible in configuration UI
- Each step can be toggled on/off
- Toggleable steps (4, 7, 8) have preset-controlled defaults
- Step descriptions explain what each step does
- Phase grouping shows pipeline organization

#### 5.4.4 Cleaning Parameters

**Requirement:** Configure cleaning behavior parameters.

**Acceptance Criteria:**
- Maximum paragraph words (for optimization step)
- Metadata format selection (YAML, JSON, Markdown)
- Chapter marker style selection
- End marker style selection
- Confidence thresholds for detection operations

#### 5.4.5 Multi-Layer Defense

**Requirement:** Protect against catastrophic content loss.

**Acceptance Criteria:**
- Phase A validates boundary positions and sizes
- Phase B verifies detected sections contain expected content
- Phase C provides heuristic fallback when AI fails
- Rejected detections logged for analysis
- Fallback activations visible in step results

---

### 5.5 Content Review

#### 5.5.1 Cleaned Content Preview

**Requirement:** Display cleaned content for review.

**Acceptance Criteria:**
- Rendered markdown view of cleaned content
- Page navigation for long documents
- Search within cleaned content
- Word count and character count display
- Raw markdown toggle

#### 5.5.2 Diff Visualization

**Requirement:** Show differences between original and cleaned content.

**Acceptance Criteria:**
- Side-by-side or unified diff view
- Additions highlighted in green
- Deletions highlighted in red
- Jump to next/previous change
- Summary of total changes

#### 5.5.3 Step Results Inspection

**Requirement:** Inspect results of individual cleaning steps.

**Acceptance Criteria:**
- Step status (completed, skipped, failed)
- Word count after step
- Change count for step
- API calls and tokens used
- View content at any step checkpoint

---

### 5.6 Export

#### 5.6.1 Individual Export

**Requirement:** Export single document to selected format.

**Acceptance Criteria:**
- Format selection: Markdown, JSON, Plain Text
- Standard macOS save dialog
- Filename defaults to source document name
- Export completes in < 500ms for typical documents

#### 5.6.2 Batch Export

**Requirement:** Export multiple documents at once.

**Acceptance Criteria:**
- Export all cleaned documents to folder
- Format selection applies to all documents
- Naming convention configurable (original name, sequential, etc.)
- Progress indication for batch operation
- Summary of export results

#### 5.6.3 Export Formats

**Markdown Export:**
- YAML front matter with metadata
- Chapter markers (if enabled)
- Clean body text
- End marker (if enabled)

**JSON Export:**
- Structured object with metadata fields
- Content field with clean text
- Processing statistics
- Original document reference

**Plain Text Export:**
- Clean text only
- No metadata or markers
- Maximum compatibility

---

### 5.7 User Interface

#### 5.7.1 Main Window Structure

**Requirement:** Three-column layout following macOS conventions.

**Acceptance Criteria:**
- Navigation sidebar (collapsible)
- Document list with status indicators
- Content area with tab-based navigation
- Inspector panel (collapsible)
- Proper resize behavior and minimum widths

#### 5.7.2 Tab Navigation

**Requirement:** Tab-based access to workflow stages.

**Acceptance Criteria:**
- Input tab for document import
- OCR tab for processing and results
- Clean tab for cleaning pipeline and results
- Library tab for document management
- Settings tab for configuration

#### 5.7.3 Status Visualization

**Requirement:** Clear visual status for documents and operations.

**Acceptance Criteria:**
- Document status badges (stage, processing state)
- Pipeline status icons (per-step status)
- Progress indicators (determinate where possible)
- Error states with actionable messages

---

### 5.8 Accessibility

**Requirement:** Support macOS accessibility features.

**Acceptance Criteria:**
- Full VoiceOver support with meaningful labels
- Dynamic Type support for text sizing
- Keyboard navigation for all operations
- Sufficient color contrast (WCAG 2.1 AA)
- Reduce Motion support for animations

---

### 5.9 Keyboard Shortcuts

| Action | Shortcut |
|:-------|:---------|
| Import files | ⌘O |
| Start OCR processing | ⌘R |
| Start cleaning | ⌘⇧R |
| Export selected | ⌘E |
| Export all | ⇧⌘E |
| Settings | ⌘, |
| Toggle sidebar | ⌘⌥S |
| Toggle inspector | ⌘⌥I |
| Next document | ↓ or ⌘] |
| Previous document | ↑ or ⌘[ |
| Delete selected | ⌫ |
| Find in preview | ⌘F |

---

## 6. User Stories

### Epic 1: Getting Started

**US-1.1** As a new user, I want to configure my API keys quickly so I can start processing documents.

**US-1.2** As a user without API keys, I want clear guidance on obtaining them from Mistral and Anthropic.

**US-1.3** As a returning user, I want my API keys remembered securely so I don't reconfigure each session.

**US-1.4** As a user, I want to validate my API keys before saving to ensure they work.

### Epic 2: Document Import

**US-2.1** As a user, I want to drag documents into the app so importing feels natural.

**US-2.2** As a user with many documents, I want to drag a folder so all supported files are added.

**US-2.3** As a user, I want to see why a file was rejected so I can fix or skip it.

**US-2.4** As a user, I want to see estimated processing time before starting.

### Epic 3: OCR Processing

**US-3.1** As a user, I want to start OCR processing with one click.

**US-3.2** As a user processing a long document, I want to see per-page progress.

**US-3.3** As a user, I want to cancel processing if I made a mistake.

**US-3.4** As a user, I want to retry failed documents without re-importing.

**US-3.5** As a user, I want to see OCR results before cleaning to verify extraction quality.

### Epic 4: Document Cleaning

**US-4.1** As a user preparing training data, I want to select the Training preset for aggressive cleaning.

**US-4.2** As a researcher, I want to select the Scholarly preset for academic documents.

**US-4.3** As a user, I want to see which steps are enabled before starting cleaning.

**US-4.4** As a user, I want to toggle individual steps to customize my cleaning.

**US-4.5** As a user, I want to see step-by-step progress during cleaning.

**US-4.6** As a user, I want to cancel cleaning mid-pipeline if something looks wrong.

**US-4.7** As a user, I want confidence that the cleaning won't destroy my content accidentally.

### Epic 5: Content Review

**US-5.1** As a user, I want to preview cleaned content before exporting.

**US-5.2** As a user, I want to see what changed between original and cleaned versions.

**US-5.3** As a user, I want to inspect individual step results to understand what each step did.

**US-5.4** As a user, I want to search within cleaned content to find specific sections.

**US-5.5** As a user, I want to see word counts to understand content reduction.

### Epic 6: Export

**US-6.1** As a user, I want to export to Markdown for documentation workflows.

**US-6.2** As a data engineer, I want to export to JSON for structured data pipelines.

**US-6.3** As a user, I want to export to plain text for maximum compatibility.

**US-6.4** As a user with many documents, I want to export all at once to a folder.

**US-6.5** As a user, I want consistent filenames based on source documents.

### Epic 7: Error Handling

**US-7.1** As a user, I want to understand why a step failed so I can decide how to proceed.

**US-7.2** As a user, I want the app to recover gracefully from API errors.

**US-7.3** As a user, I want to know when fallback detection was used instead of AI.

---

## 7. Prioritization

### Implemented (Current Release)

| Area | Features |
|:-----|:---------|
| Setup | Dual API key configuration, Keychain storage, validation |
| Import | Drag-and-drop, file picker, folder support, validation |
| OCR | Mistral integration, per-page progress, queue management |
| Cleaning | 14-step pipeline, 4 presets, step configuration |
| Defense | Boundary validation, content verification, heuristic fallback |
| Preview | Cleaned content view, diff visualization, step inspection |
| Export | Markdown, JSON, plain text; individual and batch |
| UI | Three-column layout, tab navigation, inspector panel |

### Should Have (Near-term)

| Area | Features |
|:-----|:---------|
| Cleaning | Save custom presets, import/export configurations |
| Preview | Synchronized scrolling between original and cleaned |
| Export | Custom naming templates, compression options |
| Performance | Parallel cleaning for multiple documents |
| Analytics | Processing statistics dashboard |

### Could Have (Future)

| Area | Features |
|:-----|:---------|
| Integration | Shortcuts automation support |
| Cleaning | Machine learning for boundary detection improvement |
| Export | Direct upload to cloud storage |
| Collaboration | Shared preset library |

### Won't Have (Out of Scope)

- Offline OCR capability
- Document editing or annotation
- Permanent document storage
- Cross-platform versions
- Real-time collaboration

---

## 8. Success Metrics

### Quality Metrics

| Metric | Target | Measurement |
|:-------|:-------|:------------|
| Content preservation rate | > 99.9% | Core content retained after cleaning |
| False positive rate | < 1% | Content incorrectly identified as scaffolding |
| Defense layer activation | Track | Frequency of validation rejections |

### Functional Metrics

| Metric | Target | Measurement |
|:-------|:-------|:------------|
| Setup completion rate | > 95% | Users completing onboarding |
| OCR success rate | > 98% | Documents completing OCR without error |
| Cleaning success rate | > 99% | Documents completing cleaning without error |
| Export success rate | > 99.5% | Exports completing without error |

### Performance Metrics

| Metric | Target | Measurement |
|:-------|:-------|:------------|
| App launch time | < 1s | Cold start to interactive |
| Import response | < 100ms | File drop to queue addition |
| Preview render | < 200ms | Document select to display |
| Export write | < 500ms | Per document in batch |

### Experience Metrics

| Metric | Target | Measurement |
|:-------|:-------|:------------|
| First document cleaned | < 10 min | From first launch |
| Preset usage | > 80% | Users using presets vs. full customization |
| Export completion | > 85% | Sessions resulting in at least one export |

---

## 9. Constraints & Assumptions

### Technical Constraints

| Constraint | Impact | Mitigation |
|:-----------|:-------|:-----------|
| Dual API dependency | Both Mistral and Claude required | Clear onboarding, graceful degradation |
| Mistral file size limit | 50MB maximum | Validation before upload |
| Claude context limits | Large documents need chunking | Intelligent chunking in pipeline |
| Network required | No offline operation | Clear connectivity indicators |

### Business Constraints

| Constraint | Impact |
|:-----------|:-------|
| API costs to user | Users must have both Mistral and Anthropic accounts |
| No vendor partnership | Standard API terms apply for both services |

### Assumptions

| Assumption | Risk if False |
|:-----------|:--------------|
| Both APIs remain stable | Major rework for API changes |
| Claude boundary detection reliable | More heuristic fallback needed |
| Users have reliable internet | Core functionality blocked |
| Document structure patterns consistent | Cleaning effectiveness varies |

### Platform Requirements

| Requirement | Specification |
|:------------|:--------------|
| Minimum macOS version | macOS 14 (Sonoma) |
| Primary target | macOS 15 (Sequoia) |
| Architecture | Universal (Apple Silicon + Intel) |
| Distribution | Direct download; App Store considered |

---

## 10. Glossary

| Term | Definition |
|:-----|:-----------|
| **API Key** | Authentication credential for external service access |
| **Back Matter** | Content after main body: appendices, about author, bibliography |
| **Boundary Detection** | AI-powered identification of content section boundaries |
| **Cleaning Pipeline** | The 14-step process that transforms OCR output to clean text |
| **Claude API** | Anthropic's AI service used for intelligent cleaning operations |
| **Content Type** | Classification of document content: prose, poetry, code, academic, etc. |
| **Diff View** | Visual comparison showing changes between original and cleaned |
| **Front Matter** | Content before main body: copyright, LOC data, publisher info |
| **Heuristic Fallback** | Pattern-based detection used when AI detection fails |
| **Keychain** | macOS secure credential storage system |
| **LLM** | Large Language Model (AI systems like GPT, Claude, Llama) |
| **Mistral OCR** | Mistral AI's optical character recognition service |
| **Multi-Layer Defense** | Architecture protecting against AI errors through validation |
| **OCR** | Optical Character Recognition—extracting text from images |
| **Phase** | Grouping of related cleaning steps (5 phases total) |
| **Preset** | Pre-configured cleaning settings optimized for use case |
| **Scaffolding** | Document structure not part of core content (TOC, index, etc.) |
| **Scholarly Apparatus** | Academic references: citations, footnotes, bibliography |
| **Session** | Single working period; not persisted between launches |
| **Step** | Individual cleaning operation within the pipeline |
| **Validation Layer** | Protection mechanism checking AI outputs before applying |

---

## Document History

| Version | Date | Author | Changes |
|:--------|:-----|:-------|:--------|
| 1.0 | January 2025 | Claude | Initial draft (OCR-focused) |
| 1.1 | January 2025 | Claude | Renamed to Horus; enhanced export formats |
| 2.0 | January 2026 | Claude | Major expansion: 14-step cleaning pipeline, multi-layer defense, presets, dual API integration |

---

*This document is part of the Horus documentation suite.*
*Next: Technical Architecture Document*
