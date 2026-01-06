# Changelog

All notable changes to Horus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
| 1.0.0 | 2026-01-06 | Initial release |
