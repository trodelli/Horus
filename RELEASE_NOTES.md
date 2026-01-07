# Horus v2.0.0

🎉 **Major Update** — Page Navigation, Improved Progress UX, and more!

## Installation

1. Download `Horus-2.0.0.dmg` below
2. Open the DMG and drag Horus to Applications
3. Launch Horus and enter your [Mistral API key](https://console.mistral.ai)

> **Note**: On first launch, macOS may show a security warning. Go to **System Settings → Privacy & Security** and click **"Open Anyway"**.

---

## ✨ What's New

### 📑 Page Navigation System
Browse multi-page documents with ease! The new thumbnail sidebar in the Inspector lets you:
- **See all pages** at a glance with visual thumbnails
- **Click to navigate** — jump to any page instantly
- **Smart caching** — efficient memory usage even for large documents (500+ pages)

### 🔄 Improved Progress Tracking
Honest, clear progress indication:
- **Phase-based updates**: Preparing → Uploading → Processing → Finalizing
- **Batch progress**: Visual percentage for multi-document processing
- **No more misleading page progress** — we show what we actually know

### ℹ️ Custom About Window
Beautiful About screen accessible from the Horus menu, featuring:
- App description and version info
- Attribution: *Design by THEWAY.INK · Built with AI · Made in Marseille*

### 🧹 Cleaner Interface
- Removed redundant progress indicator from sidebar
- Streamlined processing status bar
- Better visual hierarchy

---

## All Changes

### Added
- Page navigation system with scrollable thumbnail sidebar
- Click-to-scroll page navigation
- LRU thumbnail cache (100 thumbnails max)
- Thumbnail prefetching (±5 pages buffer)
- Custom About window
- Phase-based progress tracking
- Batch progress percentage display

### Changed
- Progress tracking now shows processing phases instead of (inaccurate) page numbers
- Indeterminate progress bar for current document
- About menu opens custom window

### Removed
- Redundant sidebar progress indicator
- Misleading page-level progress bar

### Improved
- Memory management for large documents
- Large document warnings (500+ pages)
- Smooth animated page scrolling

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Mistral AI API key

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Add Documents | ⌘O |
| Process All | ⌘R |
| Export | ⌘E |
| Copy to Clipboard | ⇧⌘C |

---

**Full Changelog**: https://github.com/trodelli/horus/blob/main/CHANGELOG.md

**Previous Release**: [v1.0.0](https://github.com/trodelli/horus/releases/tag/v1.0.0)
