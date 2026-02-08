# Horus v3.0.0

**Intelligent Document Cleaning** — Transform raw documents into clean, AI-ready content.

---

## Installation

1. Download `Horus-3.0.0.dmg` below
2. Open the DMG and drag Horus to Applications
3. Launch Horus and configure your API keys:
   - [Mistral API key](https://console.mistral.ai) for OCR
   - [Anthropic API key](https://console.anthropic.com) for cleaning

> **Note**: On first launch, macOS may show a security warning. Go to **System Settings → Privacy & Security** and click **"Open Anyway"**.

---

## What's New

### 🧠 Intelligent Content Cleaning

The headline feature of v3.0 is the **V3 Evolved Cleaning Pipeline**—a sophisticated system that transforms raw OCR output into publication-ready content.

**How it works:**

1. **Reconnaissance** — Claude analyzes your document's structure before making changes
2. **Detection** — Identifies structural elements: front matter, TOC, indexes, citations, footnotes
3. **Cleaning** — Removes scaffolding while preserving content integrity
4. **Quality Assurance** — Confidence scoring ensures reliable results

**What it removes:**
- Page numbers, headers, and footers
- Front matter (cover pages, title pages, copyrights)
- Back matter (colophons, back covers)
- Table of contents (optional)
- Indexes and auxiliary lists (optional)
- Citations and bibliographies (optional)
- Footnotes and endnotes (optional)
- OCR artifacts and encoding issues

**What it preserves:**
- Core document content
- Heading hierarchy
- Paragraph structure
- Intentional formatting

### ⚙️ Processing Presets

Four pre-configured profiles for different use cases:

| Preset | Best For |
|--------|----------|
| **Default** | General document cleanup |
| **Training** | ML datasets—maximum extraction |
| **Minimal** | Light cleanup—headers and page numbers only |
| **Scholarly** | Academic documents—preserves citations |

### 📄 Direct-to-Clean Path

Process text files without OCR:
- Plain text (.txt)
- Rich text (.rtf)
- JSON, XML, HTML

Perfect for cleaning content you've already extracted elsewhere.

### 🔐 Dual-API Architecture

Horus now uses two AI providers:
- **Mistral** (pixtral-large-latest) — OCR and text extraction
- **Claude** (claude-sonnet-4-20250514) — Intelligent content cleaning

Both API keys are stored securely in your Mac's Keychain.

### 🖥️ New Clean Tab

A dedicated interface for the cleaning workflow:
- Preset selection
- Toggleable cleaning steps
- Real-time progress with phase indicators
- Confidence score display
- Before/after content preview

---

## Use Cases

**ML Data Engineers**
Prepare training datasets at scale. Export to JSON for direct pipeline integration.

**Research Curators**
Maintain scholarly integrity. Preserve citations and footnotes while removing structural noise.

**Content Operations**
Transform document archives into usable content. Batch process entire collections.

---

## Pricing

### Mistral OCR
- **$0.001 per page**
- 100 pages = $0.10

### Claude Cleaning
- Approximately **$0.01 per 1,000 words**
- Varies with document complexity

Horus displays cost estimates before processing.

---

## All Changes

### Added

**Cleaning Pipeline**
- V3 Evolved Cleaning Pipeline with 16 steps across 8 phases
- AI-powered document structure analysis
- Content type detection (13 types)
- Processing presets (Default, Training, Minimal, Scholarly)
- Toggleable cleaning steps
- Confidence scoring system

**Dual-API Architecture**
- Claude API integration for cleaning
- Separate cost tracking for OCR and cleaning
- Independent processing paths

**Direct-to-Clean Path**
- Text file support (.txt, .rtf, JSON, XML, HTML)
- Bypass OCR for text-based documents

**UI Enhancements**
- Clean tab with dedicated cleaning interface
- Cleaning inspector view
- Preset selector
- Phase and confidence indicators

### Changed

- Tab structure expanded from 3 to 5 tabs
- Settings view includes Claude API configuration
- Keyboard shortcuts updated (⌘K for Clean Selected)
- Added Clean menu with cleaning commands
- Export metadata includes cleaning information

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Mistral AI API key (for OCR)
- Anthropic API key (for cleaning)

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Add Documents | ⌘O |
| Process All (OCR) | ⌘R |
| Clean Selected | ⌘K |
| Export Selected | ⌘E |
| Toggle Inspector | ⌥⌘I |

---

**Full Changelog**: https://github.com/trodelli/Horus/blob/main/CHANGELOG.md

**Previous Release**: [v2.1.0](https://github.com/trodelli/Horus/releases/tag/v2.1.0)
