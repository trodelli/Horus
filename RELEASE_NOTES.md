# Horus v2.1.0

🎉 **Export Improvements** — Multiple format export and better UX!

## Installation

1. Download `Horus-2.1.0.dmg` below
2. Open the DMG and drag Horus to Applications
3. Launch Horus and enter your [Mistral API key](https://console.mistral.ai)

> **Note**: On first launch, macOS may show a security warning. Go to **System Settings → Privacy & Security** and click **"Open Anyway"**.

---

## ✨ What's New

### ✅ Multiple Format Export
Export documents to multiple formats in one go!
- **Select multiple formats** — Choose any combination of Markdown, JSON, and Plain Text
- **Smart behavior** — Single format uses traditional Save dialog; multiple formats use folder picker
- **Batch support** — Export entire libraries to all formats at once
- **Clear feedback** — Checkbox interface shows exactly what you're exporting

### 📏 Improved Export Window
Better visibility and usability:
- **Taller windows** — All export options visible without scrolling (420px → 540px)
- **Clear instructions** — "Select one or more formats to export"
- **Disabled state** — Export button disabled when no formats selected (prevents errors)

### 🚀 Enhanced Workflow
- **Faster exports** — Get all formats you need in one operation
- **Progress tracking** — Accurate progress for multi-format exports (documents × formats)
- **Consistent naming** — `document.md`, `document.json`, `document.txt`

---

## Use Cases

**LLM Training**: Export to Markdown for fine-tuning, JSON for structured data, and TXT for tokenization — all at once!

**Data Pipelines**: Get both human-readable (Markdown) and machine-readable (JSON) formats in a single export.

**Backup**: Export to all formats to ensure you have the data in whatever format you need later.

---

## All Changes

### Added
- Multiple format export (Markdown, JSON, Plain Text simultaneously)
- Checkbox-based format selection interface
- Smart export behavior (single format → save dialog, multiple → folder picker)
- Batch multi-format export support

### Changed
- Export window height increased from 420px to 540px
- Batch export window height increased from 450px to 540px
- Export button disabled when no formats selected
- Format selection UI changed from radio buttons to checkboxes

### Improved
- All export options visible without scrolling
- Accurate progress tracking for multi-format exports
- Consistent file naming for exported formats
- Visual feedback with checkbox states

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

**Previous Release**: [v2.0.0](https://github.com/trodelli/horus/releases/tag/v2.0.0)
