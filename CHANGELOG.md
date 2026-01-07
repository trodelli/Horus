# Changelog

All notable changes to Horus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 2.0.0 | 2026-01-07 | Page navigation, improved progress UX, About window |
| 1.0.0 | 2026-01-06 | Initial release |
