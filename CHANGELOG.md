# Changelog

All notable changes to Horus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [3.0.0] - 2026-02-08

### Added

#### Intelligent Content Cleaning Pipeline

- **V3 Evolved Cleaning Pipeline** — Sophisticated 16-step document cleaning system powered by Claude AI
- **8 Processing Phases** — Reconnaissance, Verification, Detection, Structural Removal, Reference Removal, Normalization, Optimization, and Quality Assurance
- **AI-Powered Structure Analysis** — Claude analyzes document structure before cleaning begins
- **Content Type Detection** — Automatic classification across 13 document types (fiction, academic, technical, legal, medical, financial, and more)
- **Confidence Scoring System** — Per-phase and pipeline-wide confidence metrics for transparency
- **Toggleable Processing Steps** — Disable removal of citations, footnotes, auxiliary lists, or table of contents as needed
- **Processing Presets** — Four pre-configured profiles: Default, Training, Minimal, and Scholarly
- **Clean Tab Interface** — Dedicated tab for the cleaning workflow with real-time progress and confidence display

#### Dual-API Architecture

- **Claude API Integration** — Anthropic's Claude (claude-sonnet-4-20250514) powers the cleaning pipeline
- **Dual Keychain Storage** — Secure storage for both Mistral and Claude API keys
- **Cost Tracking for Cleaning** — Transparent cost estimation and tracking for Claude API usage
- **Independent Processing Paths** — OCR and cleaning can run independently or as a combined pipeline

#### Direct-to-Clean Path

- **Text File Support** — Process plain text (.txt), rich text (.rtf), JSON, XML, and HTML directly through the cleaning pipeline without OCR
- **Bypass OCR** — Skip OCR entirely for documents that are already text-based
- **Format Flexibility** — Handle both image-based documents (via OCR) and text-based documents (direct cleaning)

#### UI Enhancements

- **Clean Tab** — New fourth tab dedicated to the cleaning interface
- **Cleaning Inspector** — Detailed view of cleaning configuration, progress, and results
- **Preset Selector** — Easy switching between cleaning presets
- **Toggle Controls** — Individual switches for each toggleable cleaning step
- **Confidence Display** — Visual indicators for cleaning confidence scores
- **Processing Phase Indicator** — Real-time display of current cleaning phase

### Changed

- **Tab Structure** — Expanded from 3 tabs (Queue, Library, Settings) to 5 tabs (Input, OCR, Clean, Library, Settings)
- **Navigation Sidebar** — Updated to reflect new tab structure with appropriate icons
- **Settings View** — Added Claude API key configuration alongside Mistral
- **Keyboard Shortcuts** — Added `⌘K` for Clean Selected and updated tab shortcuts for new structure
- **Menu Structure** — Added Clean menu with cleaning-specific commands

### Improved

- **Document Lifecycle** — Documents can now progress through both OCR and cleaning stages
- **Export Metadata** — Cleaned documents include cleaning-specific metadata (preset used, confidence scores, steps applied)
- **Error Handling** — Enhanced error reporting for cleaning pipeline failures
- **Cost Transparency** — Separate cost tracking for OCR and cleaning operations

---

## [2.1.0] - 2026-01-09

### Added

- **Multiple Format Export** — Export documents to multiple formats simultaneously (Markdown, JSON, TXT)
- **Checkbox-Based Format Selection** — Intuitive checkbox interface for selecting one or more export formats
- **Smart Export Behavior** — Single format uses traditional Save dialog; multiple formats use folder picker
- **Batch Multi-Format Export** — Export entire document libraries to multiple formats at once

### Changed

- **Export Window Height** — Increased from 420px to 540px for better visibility
- **Export Window (Batch)** — Increased from 450px to 540px
- **Export Button Logic** — Now disabled when no formats are selected
- **Format Selection UI** — Changed from radio buttons (single selection) to checkboxes (multiple selection)

### Improved

- **Export UX** — All export options visible without scrolling
- **Export Progress** — Accurate progress tracking across multiple formats (documents × formats)
- **File Naming** — Consistent naming for multi-format exports (e.g., `document.md`, `document.json`, `document.txt`)
- **Visual Feedback** — Clear indication of selected formats with checkbox states

---

## [2.0.0] - 2026-01-07

### Added

- **Page Navigation System** — Scrollable thumbnail sidebar in Inspector for multi-page documents
- **Click-to-Scroll Navigation** — Click any page thumbnail to instantly scroll to that page in preview
- **LRU Thumbnail Cache** — Efficient caching system (100 thumbnails max) with lazy loading
- **Thumbnail Prefetching** — Automatically loads thumbnails for nearby pages (±5 buffer)
- **Custom About Window** — Beautiful About window with app description and attribution
- **Phase-Based Progress** — Clear progress phases: Preparing → Uploading → Processing → Finalizing
- **Batch Progress Percentage** — Visual percentage indicator for multi-document batches

### Changed

- **Progress Tracking** — Replaced misleading page-level progress with honest phase-based updates
- **Processing Status Bar** — Indeterminate progress bar for current document (since API doesn't provide page-level progress)
- **About Menu** — Now opens custom About window instead of navigating to Settings

### Removed

- **Sidebar Progress Indicator** — Removed redundant progress display from navigation sidebar
- **Page-Level Progress Bar** — Removed inaccurate page progress (API returns all pages at once)

### Improved

- **Memory Management** — Optimized thumbnail handling for documents with 500+ pages
- **Large Document Support** — Warning indicator for documents over 500 pages
- **Preview Scrolling** — Smooth animated scrolling when navigating between pages

---

## [1.0.0] - 2026-01-06

### Added

- **Initial Release** of Horus OCR application
- Tab-based navigation with Queue, Library, and Settings views
- Batch document processing with real-time progress tracking
- Support for PDF, PNG, JPEG, TIFF, GIF, and WebP formats
- Drag-and-drop document import
- Processing statistics: elapsed time, pages/second, running cost
- Rendered and raw markdown preview in Library
- Export to Markdown, JSON, and plain text formats
- Copy to clipboard functionality
- Document tooltips showing file path, size, and date added
- Delete individual documents with confirmation dialogs
- Clear Queue and Clear Library bulk actions
- Keyboard shortcuts for all major actions
- Secure API key storage in macOS Keychain
- Cost estimation and confirmation dialogs
- Pause/resume processing controls
- Search and filter in Library view
- Improved empty states with step-by-step guidance

### Security

- API keys stored securely in macOS Keychain
- No API keys or secrets stored in code or preferences

---

## [Unreleased]

### Planned Features

- Session persistence between app launches
- Batch selection for bulk operations
- Export history tracking
- Dark/light mode theme support
- Localization support
- Custom cleaning rule builder
- Before/after comparison UI

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 3.0.0 | 2026-02-08 | Intelligent cleaning pipeline, dual-API architecture, Clean tab |
| 2.1.0 | 2026-01-09 | Multiple format export, improved export UX |
| 2.0.0 | 2026-01-07 | Page navigation, improved progress UX, About window |
| 1.0.0 | 2026-01-06 | Initial release |
