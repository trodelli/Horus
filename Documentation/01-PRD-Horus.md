# Horus: Product Requirements Document (V2/V3)

**Version:** 2.0
**Last Updated:** February 2025
**Status:** Active Development
**Platform:** macOS 14+ (Sonoma)

---

## Executive Summary

Horus is a native macOS application that transforms raw documents into clean, AI-ready content through an intelligent dual-API architecture combining Mistral's advanced OCR capabilities with Claude's sophisticated content cleaning pipeline. Designed for ML data engineers, research curators, and content operations professionals, Horus eliminates the tedious manual process of removing OCR scaffolding (front matter, tables of contents, page numbers, citations, and indexes) from extracted document content.

The application delivers enterprise-grade document processing through a user-friendly interface, providing both automated intelligence and granular user control through configurable presets and toggleable processing steps. With comprehensive cost tracking, confidence scoring, and multi-format export capabilities, Horus becomes an essential tool for organizations managing large-scale document datasets.

---

## Product Vision & Strategy

### Vision Statement

Transform document processing from a manual, error-prone task into an automated, intelligent workflow that respects document structure while eliminating scaffolding, enabling data engineers and researchers to focus on content rather than cleanup.

### Strategic Objectives

1. **Automation Excellence**: Reduce manual document cleanup time by 90% through AI-powered content intelligence
2. **User Empowerment**: Provide fine-grained control through presets and toggleable processing steps without overwhelming non-technical users
3. **Cost Transparency**: Track and report actual API costs to enable informed decision-making for large-scale processing
4. **Data Privacy**: Maintain privacy-first architecture with no external telemetry, leveraging macOS Keychain for secure credential storage
5. **Reliability at Scale**: Process up to 50 documents per session with > 99% content preservation and > 98% OCR success rates

### Target Market & Personas

#### Alex - ML Data Engineer
- **Role**: Builds training datasets from document sources
- **Challenge**: Manually removes headers, footers, and metadata from OCR output before model training
- **Goal**: Automate cleanup pipeline to process hundreds of documents with consistent quality standards
- **Usage Pattern**: Batch processing with Training preset, emphasis on cost optimization and consistency metrics

#### Jordan - Research Curator
- **Role**: Manages academic and scientific document collections
- **Challenge**: Preserves citation integrity while removing index entries and structural scaffolding
- **Goal**: Maintain scholarly formatting while eliminating non-content material
- **Usage Pattern**: Selective processing with Scholarly preset, prioritizes content preservation and confidence scoring

#### Sam - Content Operations Lead
- **Role**: Non-technical professional managing content workflows
- **Challenge**: Needs reliable document processing without technical knowledge
- **Goal**: "Set and forget" solution with clear progress indicators and export options
- **Usage Pattern**: GUI-driven workflow with Default preset, focuses on simplicity and reliability

---

## Core Product Specification

### 1. Document Import & Format Support

#### Supported Input Formats

**OCR Processing Path** (images → text extraction → cleaning):
- PDF (multi-page and single-page, with encryption detection)
- PNG, JPEG, TIFF, GIF, WebP, BMP

**Direct-to-Clean Path** (existing text → cleaning only):
- Plain text (.txt)
- Rich Text Format (.rtf)
- JSON (v1.1 compatible)
- XML
- HTML

#### Input Format Constraints

- **Maximum file size:** 100 MB per document
- **Maximum pages:** 1000 pages per PDF
- **PDF encryption detection:** Encrypted PDFs are rejected before processing
- **Supported page formats:** A4, Letter, Legal, Tabloid
- **Image dimensions:** Minimum 100×100 pixels, maximum 10,000×10,000 pixels

#### Import Mechanisms

1. **Drag-and-Drop**: Users drag files directly onto the application window
2. **File Picker Dialog**: Browse filesystem and select single or multiple documents
3. **Batch Import**: Support for importing 2-50 documents per session

#### Document Metadata Capture

- Original filename (preserved through processing)
- File type and size
- Import timestamp
- Processing start time (upon user initiation)
- Processing completion time
- Document word count (calculated post-cleaning)

### 2. OCR Processing Engine

#### Mistral API Integration

- **Model**: pixtral-large-latest (vision-capable OCR model)
- **Processing Scope**: Document images only (PDF pages, PNG, JPEG, TIFF, GIF, WebP, BMP)
- **Per-Page Processing**: Each page processed independently with granular progress tracking
- **Retry Logic**: Automatic retry (3 attempts max) with exponential backoff on API failures
- **Timeout Handling**: 120-second per-page timeout with graceful error reporting

#### OCR Quality Metrics

- **Success Rate Target**: > 98% of pages successfully extracted
- **Content Confidence**: Per-page confidence scoring based on Mistral model's output
- **Error Handling**: Detailed error logging with user-visible retry options
- **Cost Tracking**: Per-page and per-document OCR cost calculation with Decimal precision

#### Progress Tracking UI

- Current page processing indicator (e.g., "Page 5 of 23")
- Real-time progress bar with percentage completion
- Elapsed time and estimated remaining time
- Per-page status: queued, processing, complete, or error
- Pause/resume functionality for extended sessions
- Cancel with option to save partial work

### 3. Intelligent Content Cleaning Pipeline (V3 Evolved)

#### Overview

The cleaning pipeline represents the core intelligence of Horus, implementing a 16-step process across 8 distinct phases. Each phase serves a specific purpose in the transformation from raw OCR output to publication-ready content.

#### Phase Architecture

**Phase A: Reconnaissance & Boundary Validation**
- Step 1: `analyzeStructure` - AI-powered document structure analysis
- Step 2: `extractMetadata` - YAML front matter generation
- **Validation**: BoundaryValidator ensures structural integrity throughout pipeline

**Phase B: Content Verification & Detection**
- **Responsibility**: ContentVerifier validates removal operations
- Ensures no unintended content elimination
- Maintains document coherence scores

**Phase C: Heuristic Boundary Detection**
- **Responsibility**: HeuristicBoundaryDetector identifies structural elements
- Works in conjunction with AI analysis
- Provides multi-layer confidence validation

**Phase D: Structural Element Removal**
- Step 3: `removePageNumbers` - Eliminates page number artifacts
- Step 4: `removeHeadersFooters` - Removes recurring header/footer content
- Step 5: `removeFrontMatter` - Strips cover pages, title pages, copyrights
- Step 6: `removeTableOfContents` - Removes TOC (toggleable)
- Step 7: `removeBackMatter` - Eliminates back covers, colophons

**Phase E: Index & Reference Removal**
- Step 8: `removeIndex` - Removes alphabetical and subject indexes
- Step 9: `removeAuxiliaryLists` - Eliminates glossaries, abbreviations (toggleable)
- Step 10: `removeCitations` - Removes bibliographies and references (toggleable)
- Step 11: `removeFootnotesEndnotes` - Eliminates footnotes and endnotes (toggleable)

**Phase F: Character & Formatting Normalization**
- Step 12: `cleanSpecialCharacters` - Normalizes Unicode artifacts, OCR errors
- Handles: smart quotes → straight quotes, em-dashes normalization, symbol standardization
- Preserves: intentional Unicode (accents, diacritics in non-English text)

**Phase G: Paragraph Reflow & Optimization**
- Step 13: `reflowParagraphs` - Reconstructs logical paragraph boundaries
- Step 14: `optimizeParagraphLength` - Targets 80-250 character average paragraph length
- Adjusts for readability without sacrificing content

**Phase H: Final Structure & Quality Assurance**
- Step 15: `addStructure` - Reconstructs heading hierarchy from content analysis
- Step 16: `finalQualityReview` - Confidence scoring and validation gate

#### Toggleable Processing Steps

Users can disable the following 4 steps via configuration:
- `removeTableOfContents` (Phase D)
- `removeAuxiliaryLists` (Phase E) — includes figures, illustrations, plates, maps, charts, diagrams, tables, exhibits, abbreviations, acronyms, symbols, contributors, authors
- `removeCitations` (Phase E)
- `removeFootnotesEndnotes` (Phase E)

This enables specialized workflows (e.g., scholarly documents requiring citation preservation).

#### Confidence Scoring System

Each processing phase generates confidence metrics:

```
Phase Confidence = (Steps Passed / Total Steps) × (Content Integrity Score)
Content Integrity Score = 1 - (Words Removed / Original Word Count)
Pipeline Confidence = Average(All Phase Confidences)
```

**Target Metrics**:
- Minimum phase confidence: 0.80
- Minimum pipeline confidence: 0.75
- Content preservation rate: > 99.9%

### 4. Content Type Detection

The pipeline includes automatic detection of 13 content types, enabling intelligent processing decisions:

1. **autoDetect** - Automatic classification (default)
2. **fiction** - Novels, short stories, narratives
3. **nonFiction** - Essays, memoirs, self-help
4. **academic** - Research papers, theses, dissertations
5. **technical** - Lab reports, technical documentation
6. **poetry** - Verse, poems, poetic works
7. **children** - Picture books, children's literature
8. **legal** - Contracts, legislation, legal documents
9. **medical** - Medical documents, clinical reports
10. **financial** - Financial statements, reports
11. **biography** - Biographies, memoirs, autobiographies
12. **history** - Historical texts, archives
13. **reference** - Dictionaries, encyclopedias, reference materials

Content type influences:
- Toggleable step defaults (e.g., scholarly documents preserve citations by default)
- Paragraph optimization thresholds
- Heading hierarchy reconstruction
- Output formatting recommendations
- Citation style defaults (APA, MLA, IEEE, Harvard, Chicago, BibTeX, footnote, mixed)
- Footnote marker style defaults (numericSuperscript, symbolSuperscript, alphabeticSuperscript, bracketedNumeric, parentheticalNumeric, inlineNote, asteriskSeries, mixed)
- Chapter marker style selection (none, htmlComments, markdownH1, markdownH2, tokenStyle)
- End marker style selection (none, minimal, simple, standard, htmlComment, markdownHR, token, tokenWithAuthor)

### 5. Processing Presets

Four pre-configured processing profiles enable users to optimize for specific use cases:

#### Default Preset
- **Target Users**: General audience
- **Configuration**:
  - All structural removal steps enabled
  - Toggleable steps: enabled (standard configuration)
  - Content type: AutoDetect
  - Paragraph optimization: 100-200 chars (balanced)
  - Output format: Markdown
- **Use Case**: General document cleanup

#### Training Preset
- **Target Users**: ML data engineers preparing training datasets
- **Configuration**:
  - All structural removal steps enabled
  - Toggleable steps: DISABLED (maximum content extraction)
  - Content type: Mixed (handles diverse sources)
  - Paragraph optimization: 80-150 chars (compact)
  - Output format: JSON (for integration with data pipelines)
  - Cost optimization: prioritizes volume over formatting
- **Use Case**: Large-scale dataset preparation

#### Minimal Preset
- **Target Users**: Users wanting light cleaning only
- **Configuration**:
  - Page numbers removed only
  - Headers/footers removed only
  - All other structural removals disabled
  - Toggleable steps: disabled
  - Content type: Mixed
  - Minimal paragraph reflow
- **Use Case**: Preservation-focused cleaning

#### Scholarly Preset
- **Target Users**: Researchers, academics, curators
- **Configuration**:
  - All structural removal steps enabled
  - Toggleable steps: DISABLED (preserves citations, footnotes)
  - Content type: Academic
  - Paragraph optimization: 120-250 chars (readable)
  - Output format: Markdown with extended YAML front matter
  - Emphasis: Citation and reference preservation
- **Use Case**: Academic document curation

### 6. Library Management

#### Document Library

Documents processed in Horus are automatically added to an in-memory library:

**Library Features**:
- Persistent document storage with search and filtering capabilities
- Document listing with metadata (filename, source format, processing status, word count)
- Search functionality by filename or content preview
- Sort by: import date, processing time, word count, processing status
- Document preview (first 500 chars of cleaned content)
- Status indicators: pending, processing, complete, failed
- Processing history with timestamps
- Quality ratings from final review: excellent (0.9+), good (0.75+), acceptable (0.6+), needsReview (0.4+), poor (<0.4)

**Library Operations**:
- View cleaned content in-app editor
- Compare original vs. cleaned content (side-by-side preview)
- Re-run cleaning pipeline on existing document with different preset
- Tag documents for export batches
- Remove documents from session

#### Session Persistence

**Design Philosophy**: Non-persistent, session-based library
- Documents exist only during active application session
- No database or file storage (except explicit exports)
- Session data cleared on application close
- User must export to preserve cleaned content
- Supports up to 50 documents per session

### 7. Multi-Format Export

#### Markdown Export

**Format**: GitHub-flavored Markdown with YAML front matter

```yaml
---
title: "Original Document Title"
source_format: "pdf"
source_filename: "document.pdf"
processing_timestamp: "2025-02-08T14:30:00Z"
processing_duration_seconds: 145
word_count: 8432
confidence_score: 0.87
ocr_success_rate: 0.98
content_type: "proseNonFiction"
preset_used: "default"
api_costs:
  ocr_cost_usd: 2.15
  cleaning_cost_usd: 0.45
  total_cost_usd: 2.60
---

# Cleaned Document Content

[Document body with preserved heading hierarchy]
```

**Features**:
- Structured heading hierarchy (H1-H6)
- Preserved paragraph breaks and logical flow
- Special character normalization
- Link preservation (if detected)
- Table preservation (if detected)
- Code block detection and formatting (for technical documents)

#### JSON Export

**Format**: Custom JSON v1.1 schema (with cleaning report) for data pipeline integration

```json
{
  "document": {
    "metadata": {
      "title": "Original Title",
      "source_format": "pdf",
      "source_filename": "document.pdf",
      "processing_timestamp": "2025-02-08T14:30:00Z",
      "word_count": 8432,
      "confidence_score": 0.87
    },
    "processing": {
      "duration_seconds": 145,
      "ocr_success_rate": 0.98,
      "pipeline_phases": {
        "phase_a": 0.92,
        "phase_d": 0.89,
        "phase_h": 0.85
      }
    },
    "content": {
      "body": "Cleaned document text...",
      "sections": [
        {
          "heading": "Section Title",
          "level": 2,
          "content": "Section body..."
        }
      ]
    },
    "cleaning_report": {
      "auxiliary_lists_removed": true,
      "citations_removed": 42,
      "footnote_markers_removed": 156,
      "chapters_detected": 12,
      "content_type_flags": {
        "contains_tables": true,
        "contains_code": false,
        "contains_lists": true
      }
    },
    "costs": {
      "ocr_usd": 2.15,
      "cleaning_usd": 0.45,
      "total_usd": 2.60
    }
  }
}
```

**Features**:
- Structured for programmatic consumption
- Complete metadata preservation
- Hierarchical section organization
- Phase confidence breakdown
- Cost transparency
- Cleaning operation report with statistics

#### Plain Text Export

**Format**: UTF-8 plain text without formatting

**Features**:
- Stripped of all Markdown syntax
- Paragraph breaks preserved
- Special characters normalized
- Suitable for search, indexing, or legacy systems

### 8. Batch Export Operations

#### Batch Processing

- **Selection**: Users tag documents for batch export (up to 50 documents)
- **Format Selection**: Choose single format or multi-format export
- **Progress Tracking**: Real-time progress indicator with:
  - Current document being exported
  - Documents completed vs. total
  - Estimated time remaining
  - Cancel option with option to export partial batch

#### Export Destination

- **Directory Selection**: Users select output directory via file picker
- **Naming Convention**: `[original_filename]_cleaned.[extension]`
- **Duplicate Filename Handling**: Automatic numbering for filename conflicts (e.g., `document_cleaned_1.md`, `document_cleaned_2.md`)
- **Organization**: Optional subdirectory creation by content type or processing date
- **Batch Export Limit**: Up to 50 documents per export operation

#### Export Metadata Summary

Upon completion, Horus generates an export manifest:

```json
{
  "export_session": {
    "timestamp": "2025-02-08T14:45:00Z",
    "total_documents": 5,
    "successful_exports": 5,
    "failed_exports": 0,
    "total_cost_usd": 13.25,
    "documents": [
      {
        "filename": "doc1_cleaned.md",
        "original_size_bytes": 245120,
        "cleaned_size_bytes": 98450,
        "compression_ratio": 0.40,
        "processing_time_seconds": 145
      }
    ]
  }
}
```

### 9. Settings & Configuration

#### API Key Management

**Dual API Key Storage**:
- Mistral API key (for OCR operations)
- Claude API key (for content cleaning)

**Security**:
- Stored in macOS Keychain
- Never written to disk unencrypted
- Never transmitted in logs or telemetry
- Unique account-specific storage

**UI Features**:
- Masked input fields showing only last 4 characters
- Test connection button for each API
- Clear explanatory text on where to obtain keys
- Visual indicator of API connectivity status

#### Cleaning Pipeline Defaults

- Default preset selection
- Content type auto-detection toggle
- Step enablement/disablement at application level
- Paragraph optimization range customization
- Confidence score threshold settings

#### Export Preferences

- Default export format (Markdown, JSON, or Plain Text)
- Default export directory
- Include metadata in exports toggle
- Filename pattern customization
- Directory organization preferences

### 10. Onboarding & First Launch

#### Onboarding Wizard for First-Time Setup

**Step 1: Welcome & Overview**
- Introduction to Horus capabilities
- Overview of API-based architecture
- Expected processing times and costs

**Step 2: API Configuration**
- Mistral API key input with validation
- Claude API key input with validation
- Test connection for each API
- Links to API provider dashboards for key generation

**Step 3: Processing Preferences**
- Default preset selection (Default, Training, Minimal, Scholarly)
- Content type preferences
- Toggle enablement defaults
- Paragraph optimization preferences

**Step 4: Export Configuration**
- Default export format (Markdown, JSON, Plain Text)
- Default export directory selection
- Metadata inclusion preferences

**Step 5: Completion**
- Summary of configuration
- Quick start guide
- Link to detailed documentation
- Ready to process documents button

#### Context Help

- Inline help icons throughout application
- Tooltip explanations for all settings
- Links to detailed documentation
- Video tutorials for key workflows

#### Keyboard Shortcuts

Quick access to common operations via keyboard:

- **⌘N** - New document (open file picker)
- **⌘O** - Open file picker
- **⌘E** - Export selected document
- **⇧⌘E** - Batch export documents
- **⌘R** - Run cleaning pipeline on selected document
- **⌘K** - Open settings/preferences
- **⌘L** - Focus library panel
- **⌘1** - Switch to Input tab
- **⌘2** - Switch to OCR tab
- **⌘3** - Switch to Cleaning tab
- **⌘4** - Switch to Library tab

---

## Processing Workflow & Document Lifecycle

### Document Status Pipeline

Documents progress through defined lifecycle stages:

```
pending → processing → complete
         ├─ queued
         ├─ ocr_processing
         ├─ ocr_complete
         ├─ cleaning
         ├─ cleaned
         └─ exported
```

**Status Definitions**:

- **pending**: Document imported, awaiting processing initiation
- **processing/queued**: Document queued for processing, waiting for resources
- **processing/ocr_processing**: OCR extraction in progress (image inputs only)
- **processing/ocr_complete**: OCR complete, cleaning pipeline starting
- **processing/cleaning**: Cleaning pipeline executing
- **complete/cleaned**: All pipeline steps complete, ready for export
- **complete/exported**: Document exported to disk

### Processing Session

**Session Characteristics**:
- Begins when application launches
- Accommodates up to 50 documents maximum
- Library exists in memory only
- No persistence between sessions
- Cost tracking maintained throughout session
- Documents cleared on application close (unless exported)

**Session Operations**:
- Import documents (drag-drop or file picker)
- Process documents (sequential or with concurrency controls)
- Review and edit in-app
- Export to disk (before session closes)
- Generate cost reports

### Processing Concurrency

**Design**: Sequential document processing with pause/resume
- Processes one document at a time to maintain API rate limits and cost control
- Pause/resume functionality for extended sessions
- Queue management with priority options (future enhancement)

---

## Technical Specifications

### Architecture Requirements

**Platform**: Native macOS Application
- **OS Requirements**: macOS 14+ (Sonoma)
- **Architecture**: Apple Silicon (M-series) and Intel support
- **UI Framework**: SwiftUI for native macOS experience
- **Sandboxing**: Full macOS App Sandbox compliance

### Security & Privacy

**Credential Management**:
- All API keys stored in macOS Keychain
- Encrypted at rest by operating system
- Never persisted to application preferences files
- Cleared from memory when application terminates

**Privacy**:
- No telemetry transmitted externally
- No analytics tracking
- No user behavior data collection
- All processing occurs on-device (OCR/cleaning delegated to APIs, no data stored by Horus)
- Compliance with macOS privacy requirements

**Data Handling**:
- Document content never cached to disk
- Temporary files cleaned up automatically
- Session data ephemeral (cleared on exit)
- No cloud synchronization

### Performance Targets

**Application Launch**:
- Cold start time: < 1 second
- Memory footprint (idle): < 150 MB
- Memory footprint (50 documents in session): < 500 MB

**Processing**:
- OCR processing: 8-15 seconds per page (dependent on content density)
- Cleaning pipeline: 3-8 seconds per 1000 words (dependent on content complexity)
- Export: < 500 ms per document

**Network**:
- API request timeout: 120 seconds
- Retry attempts: 3 (exponential backoff)
- Concurrent API requests: 1 (sequential processing)

### Data Validation

**Input Validation**:
- File type verification on import
- File size limits: 100 MB maximum per document (not 500 MB)
- Page count limits: up to 1000 pages per PDF
- Format validation for direct-to-clean paths
- PDF encryption detection (reject encrypted PDFs)

**Output Validation**:
- Content integrity checks pre-export
- Confidence score validation (minimum 0.75 required for export)
- File write verification
- Metadata completeness verification

### API Integration

**Mistral OCR**:
- Model: pixtral-large-latest
- Rate limits: Per Mistral pricing/usage terms
- Timeout: 120 seconds per page
- Error handling: 3-attempt retry with exponential backoff

**Claude Content Cleaning**:
- Model: claude-sonnet-4-20250514
- Prompt engineering for specialized cleaning tasks
- Token counting with Anthropic tokenizer
- Cost tracking with Decimal precision

---

## Success Metrics & KPIs

### Content Quality Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Content Preservation Rate | > 99.9% | (Output Words / Input Words) × 100 |
| OCR Success Rate | > 98% | (Pages Extracted / Total Pages) × 100 |
| Cleaning Success Rate | > 99% | (Documents Cleaned / Processed) × 100 |
| Pipeline Confidence Score | ≥ 0.75 avg | Confidence scoring system calculation |
| Structural Integrity | > 99% | Manual spot checks (quarterly) |

### Performance Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| App Launch Time | < 1 second | System timer on cold start |
| Processing Speed (OCR) | 8-15 sec/page | Per-page timing in logs |
| Processing Speed (Cleaning) | 3-8 sec/1K words | Document timing in logs |
| Export Speed | < 500ms/doc | Batch export timing |
| Memory Usage (Idle) | < 150 MB | Activity Monitor |
| Memory Usage (50 docs) | < 500 MB | Activity Monitor with session loaded |

### Business Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Cost Accuracy | 99.9% | Billing reconciliation vs. tracked costs |
| Manual Cleanup Time Reduction | 90% | User feedback and usage patterns |
| User Session Success Rate | > 95% | Session completion without errors |
| Average Documents per Session | 8-15 | Usage analytics (if telemetry enabled) |

---

## Non-Functional Requirements

### Reliability

- Mean Time Between Failures (MTBF): > 100 hours
- Error recovery: Automatic retry with user notification
- Graceful degradation: Partial processing failures don't prevent partial export
- Data loss prevention: Session warning before closing with unsaved exports

### Maintainability

- Code modularity: Clear separation between OCR, cleaning, and UI layers
- Error logging: Comprehensive logs for debugging (stored locally only)
- Testing: Unit tests for pipeline steps, integration tests for workflows
- Documentation: Code comments and architectural guides

### Scalability

- Document session limit: 50 documents (enforced)
- Concurrent processing: Sequential (1 document at a time)
- API call rate limiting: Managed via delay between requests
- Memory management: Automated cleanup of processed documents

### Compliance

- macOS App Sandbox requirements
- Data privacy: GDPR-compliant (no data transmission externally)
- API usage: Compliance with Mistral and Anthropic TOS
- File system: Standard macOS permission model

---

## Future Roadmap (Out of Scope for V2/V3)

These items represent potential enhancements beyond current scope:

- Cloud synchronization of processing preferences
- Document history and recovery
- Advanced preview modes (before/after comparison UI)
- Custom cleaning rule builder
- Scheduled batch processing
- API webhook integration
- Multi-language UI localization
- Pro tier with enhanced features

---

## Glossary

**Scaffolding**: Non-content structural elements added during document creation or OCR (page numbers, headers, footers, TOC, indexes)

**Confidence Score**: Numerical metric (0.0-1.0) indicating pipeline's confidence in cleaning accuracy and content preservation

**Preset**: Pre-configured set of processing parameters optimized for specific use cases

**Content Type**: Categorical classification of document type influencing processing decisions

**Toggleable Step**: Optional pipeline processing step that users can enable/disable per document

**Phase**: Logical grouping of 1-3 related pipeline steps serving a specific purpose

**Reflow**: Process of reconstructing logical paragraph boundaries from raw OCR output

**Session**: Single application instance from launch to termination with non-persistent document library

---

## References & Dependencies

### External Services

- **Mistral API**: pixtral-large-latest model for OCR
- **Anthropic API**: claude-sonnet-4-20250514 for content cleaning

### Documentation References

- Mistral Vision API Documentation
- Anthropic Claude API Documentation
- macOS App Sandbox Entitlements
- SwiftUI Framework Documentation

---

**Document Control**

| Aspect | Value |
|--------|-------|
| Author | Horus Product Team |
| Version | 2.0 |
| Status | Active |
| Last Review | February 2025 |
| Next Review | May 2025 |
| Classification | Internal |

---

**Approval & Sign-Off** (Template for stakeholder approval)

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Product Lead | _____ | _____ | _____ |
| Engineering Lead | _____ | _____ | _____ |
| Design Lead | _____ | _____ | _____ |
| Stakeholder | _____ | _____ | _____ |

---

**Document History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Jan 2025 | Product Team | Initial PRD creation |
| 2.0 | Feb 2025 | Product Team | V2/V3 feature integration, pipeline architecture refinement, expanded specifications |
