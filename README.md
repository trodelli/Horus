<p align="center">
  <img src="Icon/Horus Icon 256x256.png" width="128" height="128" alt="Horus App Icon">
</p>

<h1 align="center">Horus</h1>

<p align="center">
  <strong>Transform documents into searchable text with the power of AI</strong>
</p>

<p align="center">
  A native macOS application that transforms your PDFs and images into clean, structured markdown using Mistral's advanced OCR technology.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0+-blue?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/Version-2.0.0-purple?style=flat-square" alt="Version 2.0.0">
</p>

<p align="center">
  <img src="Screenshots/Horus%20Queue.jpg" width="700" alt="Horus App">
</p>

---

## ✨ What's New in v2.0

- 📑 **Page Navigation** — Scrollable thumbnail sidebar for multi-page documents
- 🖱️ **Click-to-Scroll** — Click any thumbnail to jump to that page instantly
- 🔄 **Improved Progress** — Honest phase-based progress tracking
- ℹ️ **About Window** — Beautiful About screen with app information

---

## Why Horus?

**Horus** brings state-of-the-art OCR to your Mac. Drop in a stack of PDFs or images, and Horus extracts clean, structured text using Mistral AI's powerful document understanding API. No subscriptions, no cloud lock-in—just your API key and your documents.

- 📄 **Batch Processing** — Queue up dozens of documents and process them all at once
- 📑 **Page Navigation** — Browse multi-page documents with thumbnail previews
- ⚡ **Lightning Fast** — Watch real-time progress as documents are processed
- 💰 **Cost Transparent** — Know exactly what you'll pay before you process ($0.001/page)
- 📝 **Clean Output** — Export as Markdown, JSON, or plain text
- 🔒 **Private & Secure** — API keys stored in your Mac's Keychain, documents processed directly with Mistral

---

## Screenshots

<table>
  <tr>
    <td align="center"><strong>Queue</strong><br>Add documents and see estimated costs</td>
    <td align="center"><strong>Library</strong><br>Browse and preview processed documents</td>
  </tr>
  <tr>
    <td><img src="Screenshots/Horus%20Queue.jpg" width="400" alt="Queue View"></td>
    <td><img src="Screenshots/Horus%20Library.jpg" width="400" alt="Library View"></td>
  </tr>
  <tr>
    <td align="center"><strong>Export Options</strong><br>Multiple format choices</td>
    <td align="center"><strong>Settings</strong><br>Configure your API key and preferences</td>
  </tr>
  <tr>
    <td><img src="Screenshots/Horus%20Export%20Options.jpg" width="400" alt="Export Options"></td>
    <td><img src="Screenshots/Horus%20Settings.jpg" width="400" alt="Settings View"></td>
  </tr>
</table>

---

## Getting Started

### 1. Download & Install

Download the latest release from the [Releases](https://github.com/trodelli/horus/releases) page:

1. Download `Horus-2.0.0.dmg`
2. Open the DMG and drag **Horus** to your Applications folder
3. Launch Horus

> **First Launch Note:** macOS may show a security warning for apps downloaded outside the App Store. Go to **System Settings → Privacy & Security** and click **"Open Anyway"**.

### 2. Get Your API Key

Horus uses [Mistral AI](https://mistral.ai) for OCR processing:

1. Create a free account at [console.mistral.ai](https://console.mistral.ai)
2. Navigate to **API Keys** and create a new key
3. Copy the key and paste it into Horus when prompted

### 3. Process Your First Document

1. **Add documents** — Drag PDFs or images into Horus, or click **Add Documents**
2. **Review the queue** — Check estimated pages and costs
3. **Click Process All** — Watch the progress as your documents are processed
4. **Browse results** — Use page thumbnails to navigate multi-page documents
5. **Export** — Save as Markdown, JSON, or copy to clipboard

---

## Features

### Page Navigation (New in v2.0)

For multi-page documents, Horus displays a scrollable thumbnail sidebar in the Inspector panel:

- **Visual Preview** — See all pages at a glance
- **Click to Navigate** — Click any thumbnail to scroll the preview to that page
- **Smart Loading** — Thumbnails load lazily with intelligent prefetching
- **Memory Efficient** — LRU cache keeps memory usage low even for large documents

### Processing Progress

Horus provides honest, clear progress indication:

- **Phase Display** — See exactly what's happening: Preparing → Uploading → Processing → Finalizing
- **Batch Progress** — Visual percentage for multi-document processing
- **Time Estimates** — Estimated time remaining based on completed documents

---

## Supported Formats

| Document Type | Extensions |
|--------------|------------|
| PDF | `.pdf` |
| Images | `.png` `.jpg` `.jpeg` `.tiff` `.gif` `.webp` |

---

## Pricing

Horus itself is **free and open source**. You only pay for Mistral API usage:

| Pages | Cost |
|-------|------|
| 10 | $0.01 |
| 100 | $0.10 |
| 1,000 | $1.00 |

That's **$0.001 per page** — process a 100-page document for a dime.

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Add Documents | `⌘O` |
| Process All | `⌘R` |
| Export Selected | `⌘E` |
| Copy to Clipboard | `⇧⌘C` |
| Pause/Resume | `⇧⌘P` |
| Cancel | `⌘.` |

<details>
<summary><strong>View all shortcuts</strong></summary>

| Action | Shortcut |
|--------|----------|
| Queue Tab | `⌘1` |
| Library Tab | `⌘2` |
| Settings Tab | `⌘3` |
| Delete Selected | `⌫` |
| Clear Queue | `⌘⌫` |
| Clear Library | `⇧⌘⌫` |
| Export All | `⇧⌘E` |

</details>

---

## Building from Source

Prefer to build it yourself? Easy:

```bash
git clone https://github.com/trodelli/horus.git
cd horus
open Horus.xcodeproj
```

Then press `⌘R` in Xcode to build and run.

**Requirements:**
- macOS 14.0 (Sonoma) or later
- Xcode 15.0+

See [BUILDING.md](BUILDING.md) for creating a distributable DMG.

---

## How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Add PDF   │ ──▶ │   Upload    │ ──▶ │  Mistral    │
│  or Image   │     │  to Mistral │     │  OCR API    │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
┌─────────────┐     ┌─────────────┐            │
│   Export    │ ◀── │  Library    │ ◀──────────┘
│  Markdown   │     │   View      │     Structured
└─────────────┘     └─────────────┘     Markdown
```

1. **Queue** — Add documents, see page counts and cost estimates
2. **Process** — Documents are uploaded to Mistral's API for OCR
3. **Library** — Browse results with rendered Markdown preview and page navigation
4. **Export** — Save to files or copy directly to clipboard

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| State Management | Swift Observation (`@Observable`) |
| Networking | Swift Concurrency (`async/await`) |
| Security | macOS Keychain Services |
| PDF Handling | PDFKit |
| Thumbnail Caching | Custom LRU Cache |

---

## Contributing

Contributions are welcome! Here's how:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-idea`)
3. Commit your changes (`git commit -m 'Add amazing idea'`)
4. Push to the branch (`git push origin feature/amazing-idea`)
5. Open a Pull Request

---

## License

MIT License — see [LICENSE](LICENSE) for details.

Free to use, modify, and distribute.

---

## Acknowledgments

- [Mistral AI](https://mistral.ai) for their excellent OCR API
- Named after the [Eye of Horus](https://en.wikipedia.org/wiki/Eye_of_Horus) — the ancient Egyptian symbol of protection, health, and wisdom

---

<p align="center">
  <strong>DESIGN BY THEWAY.INK · BUILT WITH AI · MADE IN MARSEILLE</strong>
</p>

<p align="center">
  <a href="https://github.com/trodelli/horus/releases">Download</a> ·
  <a href="https://github.com/trodelli/horus/issues">Report Bug</a> ·
  <a href="https://github.com/trodelli/horus/issues">Request Feature</a>
</p>
