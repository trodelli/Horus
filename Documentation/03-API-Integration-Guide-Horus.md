# API Integration Guide
## Horus — Dual AI Integration for Document Processing

> **Document Version:** 2.0  
> **Last Updated:** January 2026  
> **Status:** Active Development  
> **Prerequisites:** PRD v2.0, Technical Architecture v2.0

---

## Table of Contents

1. [API Overview](#1-api-overview)
2. [Authentication](#2-authentication)
3. [Mistral OCR API](#3-mistral-ocr-api)
4. [Claude API](#4-claude-api)
5. [Multi-Layer Defense Integration](#5-multi-layer-defense-integration)
6. [Request Construction](#6-request-construction)
7. [Response Handling](#7-response-handling)
8. [Error Handling](#8-error-handling)
9. [Rate Limiting & Retry Strategy](#9-rate-limiting--retry-strategy)
10. [Cost Tracking](#10-cost-tracking)
11. [Network Considerations](#11-network-considerations)
12. [Testing & Mocking](#12-testing--mocking)
13. [Implementation Checklist](#13-implementation-checklist)

---

## 1. API Overview

### 1.1 Dual API Architecture

Horus integrates with two AI APIs, each serving a distinct purpose in the document processing pipeline:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DUAL API ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    MISTRAL OCR API                                 │ │
│  │  ─────────────────────────────────────────────────────────────── │ │
│  │  Purpose: Document text extraction                                │ │
│  │  Endpoint: api.mistral.ai/v1/chat/completions                    │ │
│  │  Input: PDF/Image documents (base64)                             │ │
│  │  Output: Markdown-formatted text with structure                  │ │
│  │  When: Step 0 - Before cleaning pipeline                         │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│                              ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    ANTHROPIC CLAUDE API                           │ │
│  │  ─────────────────────────────────────────────────────────────── │ │
│  │  Purpose: Intelligent content analysis & boundary detection       │ │
│  │  Endpoint: api.anthropic.com/v1/messages                         │ │
│  │  Input: OCR text content                                         │ │
│  │  Output: Structured JSON (patterns, boundaries, metadata)        │ │
│  │  When: Steps 1-14 of cleaning pipeline                           │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│                              ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    VALIDATION LAYER                               │ │
│  │  ─────────────────────────────────────────────────────────────── │ │
│  │  Purpose: Validate AI responses before applying changes          │ │
│  │  Phase A: Boundary validation (position, size constraints)       │ │
│  │  Phase B: Content verification (pattern matching)                │ │
│  │  Phase C: Heuristic fallback (AI-independent detection)          │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Why Two APIs?

| Aspect | Mistral OCR | Claude |
|:-------|:------------|:-------|
| **Specialization** | State-of-the-art OCR with document structure preservation | Intelligent content analysis and natural language understanding |
| **Strength** | Visual document processing, table extraction, image handling | Semantic boundary detection, pattern recognition, content classification |
| **Reliability** | Consistent OCR output | Requires validation layer due to potential hallucination |
| **Token Efficiency** | Vision model optimized for document processing | Text model optimized for analysis tasks |

### 1.3 API Summary

| API | Base URL | Authentication | Primary Use |
|:----|:---------|:---------------|:------------|
| **Mistral AI** | `https://api.mistral.ai/v1` | Bearer token | OCR extraction |
| **Anthropic Claude** | `https://api.anthropic.com/v1` | x-api-key header | Boundary detection, pattern analysis |

### 1.4 Processing Flow

```
Document Import
      │
      ▼
┌─────────────────┐
│  Mistral OCR    │ ──▶ OCR Result (Markdown text)
└─────────────────┘
      │
      ▼
┌─────────────────┐     ┌───────────────────┐
│  Claude API     │ ──▶ │ Validation Layer  │ ──▶ Validated Response
└─────────────────┘     └───────────────────┘
      │                         │
      │                    ┌────┴────┐
      │                   Pass    Fail
      │                    │         │
      │                    ▼         ▼
      │               Apply      Heuristic
      │               Changes    Fallback
      │                    │         │
      └────────────────────┴─────────┘
                    │
                    ▼
              Cleaned Content
```

---

## 2. Authentication

### 2.1 Dual API Key Management

Horus stores API keys separately for each service in the macOS Keychain:

```swift
/// Service for secure storage of API credentials
final class KeychainService: KeychainServiceProtocol {
    
    // Keychain identifiers
    private let serviceName = "com.horus.app"
    private let mistralAccountName = "mistral-api-key"
    private let claudeAccountName = "claude-api-key"
    
    // Status checks
    var hasMistralAPIKey: Bool { /* check keychain */ }
    var hasClaudeAPIKey: Bool { /* check keychain */ }
    
    // Mistral key operations
    func storeMistralAPIKey(_ key: String) throws
    func retrieveMistralAPIKey() throws -> String?
    func deleteMistralAPIKey() throws
    
    // Claude key operations
    func storeClaudeAPIKey(_ key: String) throws
    func retrieveClaudeAPIKey() throws -> String?
    func deleteClaudeAPIKey() throws
}
```

### 2.2 API Key Formats

**Mistral API Key:**
```
sk-[a-zA-Z0-9]{32,}
```
Example: `sk-aBcDeFgHiJkLmNoPqRsTuVwXyZ123456`

**Claude API Key:**
```
sk-ant-api[0-9]{2}-[a-zA-Z0-9-_]{95}
```
Example: `sk-ant-api03-xxxxxxxx...`

### 2.3 Obtaining API Keys

**Mistral:**
1. Navigate to https://console.mistral.ai
2. Sign in or create account
3. Go to "API Keys" section
4. Click "Create new key"
5. Copy key (shown only once)

**Claude:**
1. Navigate to https://console.anthropic.com
2. Sign in or create account
3. Go to "API Keys" in Settings
4. Click "Create Key"
5. Copy key (shown only once)

### 2.4 Key Validation

Both services support validation through lightweight API calls:

**Mistral Validation:**
```http
GET https://api.mistral.ai/v1/models
Authorization: Bearer {api_key}
```

**Claude Validation:**
```http
POST https://api.anthropic.com/v1/messages
x-api-key: {api_key}
anthropic-version: 2023-06-01
Content-Type: application/json

{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 10,
  "messages": [{"role": "user", "content": "Respond with only: OK"}]
}
```

### 2.5 Keychain Storage Configuration

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.horus.app",
    kSecAttrAccount as String: accountName,  // "mistral-api-key" or "claude-api-key"
    kSecValueData as String: keyData,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
]
```

**Security Properties:**
- Keys accessible only when device is unlocked
- Keys tied to app's bundle identifier
- Keys not synced to iCloud Keychain (local only)
- Keys never logged or included in error messages

---

## 3. Mistral OCR API

### 3.1 Endpoint Details

```http
POST https://api.mistral.ai/v1/chat/completions
Content-Type: application/json
Authorization: Bearer {api_key}
```

### 3.2 Request Schema

```json
{
  "model": "mistral-ocr-latest",
  "document": {
    "type": "document_base64",
    "document_base64": "JVBERi0xLjQK..."
  },
  "include_image_base64": false,
  "table_format": "markdown"
}
```

### 3.3 OCR Parameters

| Parameter | Type | Default | Description |
|:----------|:-----|:--------|:------------|
| `model` | string | Required | `mistral-ocr-latest` recommended |
| `document` | object | Required | Document payload (base64 or URL) |
| `include_image_base64` | boolean | `false` | Include image data in response |
| `table_format` | string | `null` | `"markdown"` or `"html"` |
| `extract_header` | boolean | `false` | Separate headers from content |
| `extract_footer` | boolean | `false` | Separate footers from content |

### 3.4 Response Schema

```json
{
  "pages": [
    {
      "index": 0,
      "markdown": "# Document Title\n\nContent...",
      "images": [],
      "tables": [],
      "dimensions": {"width": 1700, "height": 2200, "dpi": 200}
    }
  ],
  "model": "mistral-ocr-latest",
  "usage_info": {
    "pages_processed": 1,
    "doc_size_bytes": 245632
  }
}
```

### 3.5 Pricing

| Tier | Cost | Notes |
|:-----|:-----|:------|
| Standard API | $0.001 per page | $1.00 per 1,000 pages |

### 3.6 Constraints

| Constraint | Limit |
|:-----------|:------|
| Maximum file size | 50 MB |
| Maximum pages | 1,000 per document |
| Supported formats | PDF, PNG, JPEG, TIFF, GIF, WebP |

---

## 4. Claude API

### 4.1 Configuration Constants

```swift
enum ClaudeAPIConfig {
    /// Base URL for Claude API
    static let baseURL = URL(string: "https://api.anthropic.com/v1")!
    
    /// Messages endpoint
    static let messagesEndpoint = "messages"
    
    /// Model for cleaning operations
    static let model = "claude-sonnet-4-20250514"
    
    /// Maximum tokens for response
    static let maxTokens = 8192
    
    /// Extended max tokens for large chunks
    static let extendedMaxTokens = 16384
    
    /// Request timeout (per chunk)
    static let timeout: TimeInterval = 90
    
    /// Extended timeout for large requests
    static let extendedTimeout: TimeInterval = 180
    
    /// Maximum retry attempts
    static let maxRetryAttempts = 2
    
    /// Delay between retries (seconds)
    static let retryDelay: TimeInterval = 2.0
    
    /// API version header
    static let apiVersion = "2023-06-01"
    
    /// Maximum content per request (characters)
    static let maxContentPerRequest = 150_000
}
```

### 4.2 Endpoint Details

```http
POST https://api.anthropic.com/v1/messages
Content-Type: application/json
x-api-key: {api_key}
anthropic-version: 2023-06-01
```

### 4.3 Request Schema

```swift
struct ClaudeAPIRequest: Encodable {
    let model: String
    let maxTokens: Int  // "max_tokens" in JSON
    let messages: [ClaudeMessage]
    let system: String?
    let temperature: Double?
    let stopSequences: [String]?  // "stop_sequences" in JSON
}

struct ClaudeMessage: Codable {
    let role: MessageRole  // "user" or "assistant"
    let content: String
}
```

**Example Request:**
```json
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 8192,
  "system": "You are an expert document processor...",
  "messages": [
    {
      "role": "user",
      "content": "Identify where the back matter begins..."
    }
  ]
}
```

### 4.4 Response Schema

```swift
struct ClaudeAPIResponse: Decodable {
    let id: String
    let type: String              // "message"
    let role: String              // "assistant"
    let content: [ClaudeContentBlock]
    let model: String
    let stopReason: String?       // "stop_reason"
    let stopSequence: String?     // "stop_sequence"
    let usage: ClaudeUsage
}

struct ClaudeContentBlock: Decodable {
    let type: String              // "text"
    let text: String?
}

struct ClaudeUsage: Decodable {
    let inputTokens: Int          // "input_tokens"
    let outputTokens: Int         // "output_tokens"
}
```

**Example Response:**
```json
{
  "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "{\n  \"startLine\": 850,\n  \"endLine\": null,\n  \"confidence\": 0.85,\n  \"notes\": \"Back matter starts at line 850 with '# NOTES'\"\n}"
    }
  ],
  "model": "claude-sonnet-4-20250514",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 15234,
    "output_tokens": 89
  }
}
```

### 4.5 Pricing

| Component | Cost |
|:----------|:-----|
| Input tokens | $3.00 per million tokens |
| Output tokens | $15.00 per million tokens |

```swift
/// Estimated cost calculation
var estimatedCost: Decimal {
    let inputCost = Decimal(inputTokens) * Decimal(string: "0.000003")!
    let outputCost = Decimal(outputTokens) * Decimal(string: "0.000015")!
    return inputCost + outputCost
}
```

### 4.6 Claude Service Operations

The ClaudeService exposes specialized methods for document cleaning:

#### Core Methods

| Method | Purpose | Max Tokens |
|:-------|:--------|:-----------|
| `sendMessage` | Generic Claude API call | 8,192 |
| `validateAPIKey` | Verify stored API key | 10 |

#### Pattern Detection (V2)

| Method | Purpose | Max Tokens |
|:-------|:--------|:-----------|
| `analyzeDocumentComprehensive` | Full pattern analysis | 8,192 |
| `detectAuxiliaryLists` | Find List of Figures, Tables, etc. | 2,048 |
| `detectCitationPatterns` | Identify citation style and patterns | 2,048 |
| `detectFootnotePatterns` | Find footnote markers and sections | 2,048 |
| `detectChapterBoundaries` | Identify chapter structure | 4,096 |

#### Boundary Detection

| Method | Purpose | Max Tokens |
|:-------|:--------|:-----------|
| `identifyBoundaries` | Generic section boundary detection | 1,024 |

Section types supported:
- `frontMatter` — Preliminary pages before Chapter 1
- `tableOfContents` — TOC section boundaries
- `index` — Alphabetized index section
- `backMatter` — Post-content sections (notes, appendix, etc.)
- `auxiliaryLists` — Lists of figures, tables, illustrations
- `footnotesEndnotes` — Note collection sections

#### Content Processing

| Method | Purpose | Max Tokens |
|:-------|:--------|:-----------|
| `extractMetadataWithContentType` | Extract metadata and classify content | 4,096 |
| `reflowParagraphs` | Join paragraphs broken by page breaks | 16,384 |
| `optimizeParagraphLength` | Split overly long paragraphs | 16,384 |

---

## 5. Multi-Layer Defense Integration

### 5.1 Defense Architecture

Claude's boundary detection must pass through a three-phase validation system before changes are applied:

```
Claude API Response
       │
       ▼
┌──────────────────────────────────────────────────────────────────┐
│  PHASE A: RESPONSE VALIDATION (BoundaryValidator)                │
│  ────────────────────────────────────────────────────────────── │
│  Checks:                                                         │
│  • Position constraints (e.g., back matter must start after 50%) │
│  • Size constraints (max removal percentage per section)         │
│  • Confidence thresholds (reject low-confidence detections)      │
│  • Bounds checking (lines within document range)                 │
│                                                                  │
│  Outcome: PASS → Continue to Phase B                             │
│           FAIL → Skip to Phase C (Heuristic Fallback)           │
└──────────────────────────────────────────────────────────────────┘
       │
       ▼ (if passed)
┌──────────────────────────────────────────────────────────────────┐
│  PHASE B: CONTENT VERIFICATION (ContentVerifier)                 │
│  ────────────────────────────────────────────────────────────── │
│  Checks:                                                         │
│  • Section contains expected patterns for its type               │
│  • Back matter: NOTES, APPENDIX, BIBLIOGRAPHY, GLOSSARY, etc.   │
│  • Index: Alphabetized entries with page numbers                 │
│  • Front matter: ISBN, copyright, publisher patterns             │
│                                                                  │
│  Outcome: PASS → Apply Claude's detection                        │
│           FAIL → Skip to Phase C (Heuristic Fallback)           │
└──────────────────────────────────────────────────────────────────┘
       │
       ▼ (if passed)
┌──────────────────────────────────────────────────────────────────┐
│  APPLY REMOVAL                                                   │
│  Claude's boundary detection has been validated.                 │
│  Safe to remove the detected section.                            │
└──────────────────────────────────────────────────────────────────┘

       │
       ▼ (if Phase A or B failed)
┌──────────────────────────────────────────────────────────────────┐
│  PHASE C: HEURISTIC FALLBACK (HeuristicBoundaryDetector)        │
│  ────────────────────────────────────────────────────────────── │
│  Pattern-based detection using regex and keyword matching        │
│  • AI-independent (works when Claude fails or is rejected)       │
│  • Conservative boundaries (better to preserve than destroy)     │
│  • Searches only in appropriate document regions                 │
│  • All fallbacks logged for analysis and improvement             │
└──────────────────────────────────────────────────────────────────┘
```

### 5.2 Validation Constraints

```swift
enum BoundaryValidationConstraints {
    // Position constraints (percentage of document)
    static let frontMatterMaxEndPercent: Double = 0.40
    static let tocMaxEndPercent: Double = 0.35
    static let indexMinStartPercent: Double = 0.60
    static let backMatterMinStartPercent: Double = 0.50  // CRITICAL
    
    // Maximum removal constraints
    static let frontMatterMaxRemovalPercent: Double = 0.40
    static let tocMaxRemovalPercent: Double = 0.20
    static let indexMaxRemovalPercent: Double = 0.25
    static let backMatterMaxRemovalPercent: Double = 0.45
    
    // Confidence thresholds
    static let frontMatterMinConfidence: Double = 0.60
    static let tocMinConfidence: Double = 0.60
    static let indexMinConfidence: Double = 0.65
    static let backMatterMinConfidence: Double = 0.70  // Higher for high-risk
}
```

### 5.3 Integration Pattern

```swift
/// Each boundary detection step follows this pattern
private func executeRemoveBackMatter(
    content: String,
    configuration: CleaningConfiguration
) async throws -> StepResult {
    
    // 1. Claude AI Detection
    let boundary = try await claudeService.identifyBoundaries(
        content: content,
        sectionType: .backMatter
    )
    
    // 2. Phase A: Response Validation
    let validationResult = boundaryValidator.validate(
        boundary: boundary,
        sectionType: .backMatter,
        documentLineCount: content.lineCount
    )
    
    guard validationResult.isValid else {
        logger.warning("Phase A rejected: \(validationResult.explanation)")
        // Fall through to Phase C
        return try executeHeuristicFallback(content: content, sectionType: .backMatter)
    }
    
    // 3. Phase B: Content Verification
    let verificationResult = contentVerifier.verifyBackMatter(
        content: content,
        startLine: boundary.startLine!
    )
    
    guard verificationResult.isValid else {
        logger.warning("Phase B rejected: \(verificationResult.explanation)")
        return try executeHeuristicFallback(content: content, sectionType: .backMatter)
    }
    
    // 4. Apply removal (all validations passed)
    let cleaned = textService.removeLineRange(
        from: content,
        startLine: boundary.startLine!,
        endLine: boundary.endLine ?? content.lineCount - 1
    )
    
    return StepResult(content: cleaned, /* ... */)
}
```

### 5.4 Why This Matters

This architecture was developed after a critical incident where Claude incorrectly identified line 4 as the start of back matter, which would have deleted 99% of the document. The multi-layer defense ensures:

1. **No catastrophic content loss** — Even if Claude hallucinates, validation catches dangerous detections
2. **Graceful degradation** — Heuristic fallback ensures operations complete even when AI fails
3. **Continuous improvement** — All rejections and fallbacks are logged for analysis

---

## 6. Request Construction

### 6.1 Mistral OCR Request

```swift
/// Build OCR request for document processing
func buildOCRRequest(
    for document: Document,
    settings: ProcessingSettings
) async throws -> URLRequest {
    
    // Read and encode file
    let fileData = try Data(contentsOf: document.sourceURL)
    let base64String = fileData.base64EncodedString()
    
    // Determine payload type
    let payload: DocumentPayload
    if document.contentType.conforms(to: .pdf) {
        payload = .pdfBase64(base64String)
    } else {
        payload = .imageBase64(base64String)
    }
    
    // Build request body
    let requestBody = OCRAPIRequest(
        document: payload,
        settings: settings
    )
    
    // Construct URLRequest
    var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/ocr")!)
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(requestBody)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 120
    
    return request
}
```

### 6.2 Claude API Request

```swift
/// Build Claude API request
private func performSingleRequest(
    _ request: ClaudeAPIRequest,
    apiKey: String
) async throws -> ClaudeAPIResponse {
    
    let url = ClaudeAPIConfig.baseURL.appendingPathComponent(ClaudeAPIConfig.messagesEndpoint)
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue(ClaudeAPIConfig.contentType, forHTTPHeaderField: "Content-Type")
    urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    urlRequest.setValue(ClaudeAPIConfig.apiVersion, forHTTPHeaderField: "anthropic-version")
    urlRequest.httpBody = try JSONEncoder().encode(request)
    
    let (data, response) = try await session.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw CleaningError.invalidResponse
    }
    
    return try handleResponse(data: data, statusCode: httpResponse.statusCode)
}
```

### 6.3 Prompt Templates

Claude requests use structured prompts defined in `CleaningPrompts`:

**System Prompts:**

```swift
/// V2 system prompt for comprehensive analysis
static let systemPromptV2 = """
You are an expert document processor specializing in cleaning OCR output 
for use in RAG systems and LLM training. You are precise, consistent, 
and preserve the semantic meaning of text while removing artifacts.

Your expertise includes:
- Document structure analysis (books, academic papers, technical manuals)
- Citation and reference detection (APA, MLA, Chicago, IEEE, numeric)
- Footnote and endnote pattern recognition
- Chapter and section boundary identification
- Content type classification (fiction, non-fiction, technical, academic)

Always respond with only the requested JSON format. Do not include 
explanations or commentary outside the JSON structure.
Escape all regex backslashes properly (use \\\\ for a literal backslash).
"""
```

**Boundary Detection Prompt (Back Matter Example):**

```swift
static func backMatterBoundaryDetection(content: String) -> String {
    """
    Identify where the BACK MATTER begins in this document.
    
    BACK MATTER SECTIONS (in typical order):
    1. NOTES / ENDNOTES
    2. APPENDIX / APPENDICES
    3. GLOSSARY
    4. BIBLIOGRAPHY / REFERENCES / WORKS CITED
    5. ACKNOWLEDGMENTS (if at end)
    6. ABOUT THE AUTHOR
    7. INDEX
    
    BACK MATTER STARTS AT:
    - The FIRST section header that matches any of the above categories
    - After the last numbered chapter
    
    Respond ONLY with JSON:
    {
      "startLine": 1200,
      "endLine": null,
      "confidence": 0.85,
      "notes": "Back matter starts at line 1200 with '# NOTES' section"
    }
    
    DOCUMENT:
    \(String(content.prefix(60000)))
    """
}
```

---

## 7. Response Handling

### 7.1 Mistral OCR Response Transformation

```swift
/// Transform Mistral OCR response to domain model
func transformOCRResponse(
    _ response: OCRAPIResponse,
    startTime: Date,
    settings: ProcessingSettings
) -> OCRResult {
    
    let pages = response.pages.map { apiPage in
        OCRPage(
            index: apiPage.index,
            markdown: apiPage.markdown,
            dimensions: apiPage.dimensions.map {
                PageDimensions(width: $0.width, height: $0.height, dpi: $0.dpi)
            },
            images: (apiPage.images ?? []).map { /* transform */ },
            tables: (apiPage.tables ?? []).map { /* transform */ }
        )
    }
    
    return OCRResult(
        pages: pages,
        model: response.model,
        processing: ProcessingMetadata(
            startedAt: startTime,
            completedAt: Date(),
            pagesProcessed: response.usageInfo.pagesProcessed,
            costUSD: calculateCost(pages: response.usageInfo.pagesProcessed),
            settings: settings
        )
    )
}
```

### 7.2 Claude Response Parsing

Claude responses contain JSON embedded in text. The parsing handles:

1. **Markdown code fence removal** — Strip \`\`\`json markers
2. **JSON extraction** — Find content between `{` and `}`
3. **Trailing comma fix** — Remove commas before `}` or `]`
4. **Decode to domain model** — Parse into typed structures

```swift
/// Parse boundary detection response
private func parseBoundaryResponse(_ text: String) throws -> BoundaryInfo {
    // Clean markdown fences
    var cleanedText = text
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Extract JSON
    guard let jsonStart = cleanedText.firstIndex(of: "{"),
          let jsonEnd = cleanedText.lastIndex(of: "}") else {
        return BoundaryInfo(startLine: nil, endLine: nil, confidence: 0, notes: "No JSON found")
    }
    
    var jsonString = String(cleanedText[jsonStart...jsonEnd])
    
    // Fix trailing commas
    jsonString = jsonString.replacingOccurrences(
        of: #",\s*([\}\]])"#,
        with: "$1",
        options: .regularExpression
    )
    
    // Decode
    guard let jsonData = jsonString.data(using: .utf8) else {
        return BoundaryInfo(startLine: nil, endLine: nil, confidence: 0, notes: "Invalid encoding")
    }
    
    struct BoundaryResponse: Decodable {
        let startLine: Int?
        let endLine: Int?
        let confidence: Double?
        let notes: String?
    }
    
    let response = try JSONDecoder().decode(BoundaryResponse.self, from: jsonData)
    
    return BoundaryInfo(
        startLine: response.startLine,
        endLine: response.endLine,
        confidence: response.confidence ?? 0.5,
        notes: response.notes
    )
}
```

### 7.3 Response Convenience Properties

```swift
extension ClaudeAPIResponse {
    /// Extract text content from response
    var textContent: String? {
        let texts = content.compactMap { block -> String? in
            if block.type == "text" { return block.text }
            return nil
        }
        return texts.isEmpty ? nil : texts.joined(separator: "\n")
    }
    
    /// Whether response was truncated
    var wasTruncated: Bool {
        stopReason == "max_tokens"
    }
    
    /// Whether response completed normally
    var completedNormally: Bool {
        stopReason == "end_turn"
    }
}
```

---

## 8. Error Handling

### 8.1 HTTP Status Codes

**Mistral:**

| Status | Meaning | Horus Handling |
|:-------|:--------|:---------------|
| 200 | Success | Parse response |
| 400 | Bad Request | Show error message |
| 401 | Unauthorized | Invalid API key |
| 413 | Payload Too Large | File exceeds 50 MB |
| 429 | Rate Limited | Retry with backoff |
| 500-599 | Server Error | Retry; show message if persists |

**Claude:**

| Status | Meaning | Horus Handling |
|:-------|:--------|:---------------|
| 200 | Success | Parse response |
| 400 | Bad Request | Show error detail |
| 401 | Unauthorized | Invalid API key |
| 429 | Rate Limited | Retry with exponential backoff |
| 500-599 | Server Error | Retry with backoff |

### 8.2 Error Types

```swift
/// Cleaning-specific errors
enum CleaningError: Error, LocalizedError {
    case missingAPIKey
    case authenticationFailed
    case rateLimited
    case timeout
    case networkError(String)
    case invalidResponse
    case apiError(code: Int, message: String)
    case patternDetectionFailed(reason: String)
    case stepFailed(step: CleaningStep, reason: String)
    case validationRejected(step: CleaningStep, reason: BoundaryRejectionReason)
    case cancelled
}

/// Reasons for boundary rejection
enum BoundaryRejectionReason {
    case positionTooEarly
    case positionTooLate
    case invalidRange
    case outOfBounds
    case excessiveRemoval
    case sectionTooSmall
    case lowConfidence
    case missingExpectedPatterns
}
```

### 8.3 Claude Error Response Handling

```swift
private func handleResponse(data: Data, statusCode: Int) throws -> ClaudeAPIResponse {
    switch statusCode {
    case 200:
        return try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)
        
    case 401:
        throw CleaningError.authenticationFailed
        
    case 429:
        throw CleaningError.rateLimited
        
    case 400:
        if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
            throw CleaningError.apiError(code: 400, message: errorResponse.error.message)
        }
        throw CleaningError.apiError(code: 400, message: "Bad request")
        
    case 500...599:
        let message: String
        if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
            message = errorResponse.error.message
        } else {
            message = "Server error"
        }
        throw CleaningError.apiError(code: statusCode, message: message)
        
    default:
        throw CleaningError.apiError(code: statusCode, message: "Unknown error")
    }
}
```

### 8.4 User-Friendly Error Messages

```swift
extension CleaningError {
    var userMessage: String {
        switch self {
        case .missingAPIKey:
            return "API key not found. Please add your key in Settings."
        case .authenticationFailed:
            return "Your API key is invalid or has expired."
        case .rateLimited:
            return "Rate limit reached. Processing will resume shortly."
        case .timeout:
            return "Request timed out. Try processing a smaller section."
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .validationRejected(let step, let reason):
            return "Validation failed for \(step.displayName): \(reason.explanation)"
        default:
            return localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey, .authenticationFailed:
            return "Check your API key in Settings."
        case .rateLimited:
            return "Horus will automatically retry. No action needed."
        case .timeout:
            return "Try processing fewer pages at once."
        default:
            return nil
        }
    }
}
```

---

## 9. Rate Limiting & Retry Strategy

### 9.1 Retry Configuration

```swift
/// Retry policy for transient failures
struct RetryConfiguration {
    let maxAttempts: Int = 3
    let initialDelay: TimeInterval = 2.0
    let maxDelay: TimeInterval = 60.0
    let multiplier: Double = 2.0
    
    func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(multiplier, Double(attempt - 1))
        return min(exponentialDelay, maxDelay)
    }
}
```

### 9.2 Claude Retry Implementation

```swift
private func performRequest(
    _ request: ClaudeAPIRequest,
    apiKey: String
) async throws -> ClaudeAPIResponse {
    var lastError: Error?
    
    for attempt in 1...ClaudeAPIConfig.maxRetryAttempts {
        do {
            return try await performSingleRequest(request, apiKey: apiKey)
            
        } catch CleaningError.timeout {
            lastError = CleaningError.timeout
            if attempt < ClaudeAPIConfig.maxRetryAttempts {
                logger.warning("Timeout (attempt \(attempt)), retrying after \(ClaudeAPIConfig.retryDelay)s...")
                try await Task.sleep(nanoseconds: UInt64(ClaudeAPIConfig.retryDelay * 1_000_000_000))
            }
            
        } catch CleaningError.rateLimited {
            lastError = CleaningError.rateLimited
            if attempt < ClaudeAPIConfig.maxRetryAttempts {
                // Exponential backoff for rate limiting
                let waitTime = ClaudeAPIConfig.retryDelay * Double(attempt * 2)
                logger.warning("Rate limited, waiting \(waitTime)s...")
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
            
        } catch let error as CleaningError {
            // Don't retry authentication or other non-transient errors
            throw error
            
        } catch {
            lastError = error
            if attempt < ClaudeAPIConfig.maxRetryAttempts {
                try await Task.sleep(nanoseconds: UInt64(ClaudeAPIConfig.retryDelay * 1_000_000_000))
            }
        }
    }
    
    throw lastError ?? CleaningError.networkError("Unknown error after retries")
}
```

### 9.3 Rate Limit Headers

**Claude rate limit headers:**
```http
x-ratelimit-limit-requests: 1000
x-ratelimit-limit-tokens: 400000
x-ratelimit-remaining-requests: 995
x-ratelimit-remaining-tokens: 385000
x-ratelimit-reset-requests: 2024-01-30T18:00:00Z
x-ratelimit-reset-tokens: 2024-01-30T18:00:00Z
retry-after: 60
```

---

## 10. Cost Tracking

### 10.1 Mistral Cost Calculation

```swift
/// Calculate Mistral OCR cost
func calculateOCRCost(pagesProcessed: Int) -> Decimal {
    Decimal(pagesProcessed) * Decimal(string: "0.001")!
}
```

### 10.2 Claude Cost Calculation

```swift
extension ClaudeUsage {
    /// Estimated cost based on Claude Sonnet pricing
    /// Input: $3/M tokens, Output: $15/M tokens
    var estimatedCost: Decimal {
        let inputCost = Decimal(inputTokens) * Decimal(string: "0.000003")!
        let outputCost = Decimal(outputTokens) * Decimal(string: "0.000015")!
        return inputCost + outputCost
    }
    
    var formattedCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: estimatedCost as NSDecimalNumber) ?? "$0.0000"
    }
}
```

### 10.3 Session Cost Tracking

```swift
/// Track costs across a processing session
@Observable
class SessionCostTracker {
    private(set) var ocrCost: Decimal = 0
    private(set) var claudeCost: Decimal = 0
    private(set) var pagesProcessed: Int = 0
    private(set) var tokensUsed: Int = 0
    
    var totalCost: Decimal {
        ocrCost + claudeCost
    }
    
    func recordOCRCost(pages: Int) {
        let cost = Decimal(pages) * Decimal(string: "0.001")!
        ocrCost += cost
        pagesProcessed += pages
    }
    
    func recordClaudeCost(usage: ClaudeUsage) {
        claudeCost += usage.estimatedCost
        tokensUsed += usage.totalTokens
    }
}
```

### 10.4 Request History Tracking

```swift
/// Track Claude API requests for debugging
struct ClaudeAPIRequestInfo: Sendable {
    let requestId: UUID
    let startedAt: Date
    let prompt: String
    let systemPrompt: String?
    var completedAt: Date?
    var response: ClaudeAPIResponse?
    var error: Error?
    
    var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }
    
    var formattedDuration: String {
        guard let dur = duration else { return "—" }
        return String(format: "%.2fs", dur)
    }
}
```

---

## 11. Network Considerations

### 11.1 URLSession Configuration

```swift
/// Configure URLSession for API requests
func createAPISession() -> URLSession {
    let config = URLSessionConfiguration.default
    
    // Timeouts
    config.timeoutIntervalForRequest = ClaudeAPIConfig.timeout      // 90s
    config.timeoutIntervalForResource = ClaudeAPIConfig.extendedTimeout  // 180s
    
    // Connection behavior
    config.waitsForConnectivity = true
    config.allowsCellularAccess = true
    config.allowsExpensiveNetworkAccess = true
    
    // Caching (disabled for API calls)
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.urlCache = nil
    
    return URLSession(configuration: config)
}
```

### 11.2 Request Size Considerations

**Mistral OCR:**
- Base64 encoding adds ~33% overhead
- 10 MB PDF → ~13.3 MB request body
- 50 MB limit (pre-encoding: ~37 MB)

**Claude:**
- Text content limited to 150,000 characters per request
- Long documents processed in chunks
- Each chunk maintains context from previous chunk

### 11.3 Connectivity Monitoring

```swift
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}
```

---

## 12. Testing & Mocking

### 12.1 Mock Claude Service

```swift
/// Mock Claude service for testing
final class MockClaudeService: ClaudeServiceProtocol {
    
    // Configuration
    var shouldSucceed = true
    var simulatedDelay: TimeInterval = 0.5
    var simulatedError: CleaningError?
    
    // Configurable results
    var identifyBoundariesResult: Result<BoundaryInfo, Error>?
    var detectPatternsResult: Result<DetectedPatterns, Error>?
    
    // Call tracking
    var sendMessageCallCount = 0
    var identifyBoundariesCallCount = 0
    var lastSectionType: SectionType?
    var lastContent: String?
    
    func sendMessage(_ prompt: String, system: String?, maxTokens: Int) async throws -> ClaudeAPIResponse {
        sendMessageCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = simulatedError {
            throw error
        }
        
        return ClaudeAPIResponse(
            id: "mock-\(UUID().uuidString)",
            type: "message",
            role: "assistant",
            content: [ClaudeContentBlock(type: "text", text: "{}", id: nil, name: nil, input: nil)],
            model: "mock-model",
            stopReason: "end_turn",
            stopSequence: nil,
            usage: ClaudeUsage(inputTokens: 100, outputTokens: 50)
        )
    }
    
    func identifyBoundaries(content: String, sectionType: SectionType) async throws -> BoundaryInfo {
        identifyBoundariesCallCount += 1
        lastSectionType = sectionType
        lastContent = content
        
        if let result = identifyBoundariesResult {
            return try result.get()
        }
        
        // Default mock behavior
        return BoundaryInfo(startLine: nil, endLine: nil, confidence: 0, notes: "Mock: Section not found")
    }
    
    // Additional mock implementations...
}
```

### 12.2 API Response Fixtures

```swift
enum ClaudeTestFixtures {
    
    /// Successful boundary detection
    static let backMatterBoundary = """
    {
      "startLine": 850,
      "endLine": null,
      "confidence": 0.85,
      "notes": "Back matter starts at line 850 with '# NOTES' section"
    }
    """
    
    /// No section found
    static let noSectionFound = """
    {
      "startLine": null,
      "endLine": null,
      "confidence": 0.9,
      "notes": "Section not found in document"
    }
    """
    
    /// Pattern detection result
    static let patternDetection = """
    {
      "pageNumberPatterns": ["^\\\\d+$", "^[ivxlc]+$"],
      "headerPatterns": ["THE GREAT NOVEL"],
      "footerPatterns": [],
      "frontMatterEndLine": 205,
      "tocStartLine": 50,
      "tocEndLine": 150,
      "indexStartLine": null,
      "backMatterStartLine": 850,
      "confidence": 0.85,
      "notes": "Standard book structure detected"
    }
    """
}
```

### 12.3 Defense Layer Testing

```swift
final class BoundaryValidationTests: XCTestCase {
    
    var validator: BoundaryValidator!
    
    override func setUp() {
        validator = BoundaryValidator()
    }
    
    func testBackMatterTooEarly_IsRejected() {
        // Back matter at line 4 of 415-line document (0.96%)
        let boundary = BoundaryInfo(startLine: 4, endLine: 414, confidence: 0.8)
        
        let result = validator.validate(
            boundary: boundary,
            sectionType: .backMatter,
            documentLineCount: 415
        )
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.rejectionReason, .positionTooEarly)
    }
    
    func testBackMatterAfterHalfway_Passes() {
        // Back matter at line 300 of 500-line document (60%)
        let boundary = BoundaryInfo(startLine: 300, endLine: 400, confidence: 0.8)
        
        let result = validator.validate(
            boundary: boundary,
            sectionType: .backMatter,
            documentLineCount: 500
        )
        
        XCTAssertTrue(result.isValid)
    }
    
    func testLowConfidence_IsRejected() {
        let boundary = BoundaryInfo(startLine: 300, endLine: 400, confidence: 0.5)
        
        let result = validator.validate(
            boundary: boundary,
            sectionType: .backMatter,  // Requires 0.70 confidence
            documentLineCount: 500
        )
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.rejectionReason, .lowConfidence)
    }
}
```

---

## 13. Implementation Checklist

### 13.1 Mistral OCR Integration

- [ ] Create `OCRAPIRequest` encodable model
- [ ] Create `OCRAPIResponse` decodable model
- [ ] Implement base64 encoding for documents
- [ ] Configure URLSession with appropriate timeouts
- [ ] Implement request building with all parameters
- [ ] Implement response parsing and transformation
- [ ] Add OCR cost calculation

### 13.2 Claude API Integration

- [ ] Create `ClaudeAPIRequest` encodable model
- [ ] Create `ClaudeAPIResponse` decodable model
- [ ] Implement all ClaudeServiceProtocol methods
- [ ] Create prompt templates for each detection type
- [ ] Implement JSON parsing with error handling
- [ ] Add request tracking for debugging
- [ ] Implement cost tracking

### 13.3 Authentication

- [ ] Implement dual Keychain storage
- [ ] Implement key validation for both APIs
- [ ] Handle authentication errors gracefully
- [ ] Never log API keys or include in error messages

### 13.4 Error Handling

- [ ] Create `CleaningError` enum with all cases
- [ ] Implement HTTP status code mapping for both APIs
- [ ] Create user-friendly error messages
- [ ] Create recovery suggestions
- [ ] Implement error logging (without sensitive data)

### 13.5 Retry Logic

- [ ] Implement `RetryConfiguration`
- [ ] Implement exponential backoff with rate limit handling
- [ ] Handle rate limit headers
- [ ] Add progress callbacks during retry
- [ ] Test retry behavior

### 13.6 Multi-Layer Defense

- [ ] Implement `BoundaryValidator` (Phase A)
- [ ] Implement `ContentVerifier` (Phase B)
- [ ] Implement `HeuristicBoundaryDetector` (Phase C)
- [ ] Integrate defense layers with ClaudeService calls
- [ ] Log all rejections and fallbacks
- [ ] Test defense layer behavior

### 13.7 Testing

- [ ] Create `MockClaudeService`
- [ ] Create `MockOCRService`
- [ ] Create API response fixtures
- [ ] Write unit tests for request building
- [ ] Write unit tests for response parsing
- [ ] Write unit tests for error handling
- [ ] Write unit tests for defense layers
- [ ] Write integration tests (with real APIs)

---

## Document History

| Version | Date | Author | Changes |
|:--------|:-----|:-------|:--------|
| 1.0 | January 2025 | Claude | Initial draft (Mistral OCR only) |
| 2.0 | January 2026 | Claude | Major expansion: Claude API integration, multi-layer defense, V2 detection methods, dual cost tracking |

---

*This document is part of the Horus documentation suite.*
*Previous: Technical Architecture Document*
*Next: UI/UX Specification*
