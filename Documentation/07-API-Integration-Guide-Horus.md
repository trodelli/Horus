# Horus — API Integration Guide

**Version:** 3.0 — February 2026

---

## Table of Contents

1. [Dual-API Architecture Overview](#dual-api-architecture-overview)
2. [Mistral OCR API Integration](#mistral-ocr-api-integration)
3. [Claude API Integration (Anthropic)](#claude-api-integration-anthropic)
4. [Authentication & Credential Management](#authentication--credential-management)
5. [Error Handling & Recovery](#error-handling--recovery)
6. [Network Client Implementation](#network-client-implementation)
7. [Response Parsing & Data Handling](#response-parsing--data-handling)
8. [Prompt Engineering & Management](#prompt-engineering--management)
9. [Cost Tracking & Financial Controls](#cost-tracking--financial-controls)
10. [Rate Limiting & Throttling](#rate-limiting--throttling)
11. [Testing & Mocking Strategies](#testing--mocking-strategies)

---

## Dual-API Architecture Overview

The Horus document processing system employs a carefully designed dual-API architecture that leverages two distinct external services, each optimized for specific tasks. This separation of concerns ensures efficiency, maintainability, and clear responsibility boundaries.

### API Role Distribution

**Mistral Vision API** serves as the document text extraction layer, handling Optical Character Recognition (OCR) operations. It excels at transforming visual content—PDFs and images—into structured, machine-readable text and markdown formats. Mistral's specialized vision capabilities make it the ideal choice for initial document digitization.

**Claude API (Anthropic)** provides the intelligent analysis layer, performing sophisticated pattern recognition, boundary detection, content classification, and cleaning operations. Claude's advanced reasoning capabilities enable understanding of document structure, citation patterns, footnote markers, chapter divisions, and other semantic features that require contextual comprehension.

### Design Principles

- **Separation of Concerns:** Each API handles distinct responsibilities with no functional overlap. Mistral extracts; Claude analyzes.
- **Independent Authentication:** Both services require separate API keys stored securely in the system Keychain under the "com.horus.app" service identifier.
- **Sequential Processing Pipeline:** Documents flow first to Mistral for OCR extraction, then to Claude for comprehensive analysis and cleaning.
- **Fallback Mechanisms:** Alternative models and error recovery strategies ensure resilience when primary services are unavailable.

---

## Mistral OCR API Integration

### Endpoint Configuration

The Mistral API provides a robust endpoint structure for document processing:

| Component | Value |
|-----------|-------|
| **Base URL** | https://api.mistral.ai/v1 |
| **OCR Endpoint** | POST /v1/ocr |
| **File Upload Endpoint** | POST /v1/files |
| **Signed URL Endpoint** | GET /v1/files/{fileId}/url |
| **Primary Model** | mistral-ocr-latest |
| **Alternative Model** | pixtral-large-latest |
| **Authentication** | Bearer token in Authorization header |

### Request Flow for PDF Documents

The PDF processing workflow involves three sequential steps:

1. **File Upload:** Submit the PDF file via multipart/form-data with purpose="ocr"
2. **Signed URL Generation:** Request a 24-hour signed URL for the uploaded file
3. **OCR Processing:** Submit OCR request with the signed URL

This approach ensures secure, temporary access to uploaded documents without exposing permanent file paths.

### Request Flow for Image Documents

Image processing bypasses the file upload step:

1. **Read & Encode:** Read the image file and encode to base64
2. **Construct Data URL:** Create a data URI using the format `data:image/[format];base64,[encoded_data]`
3. **OCR Processing:** Submit OCR request with the image_url payload

### Request Format

```json
{
  "model": "mistral-ocr-latest",
  "document": {
    "type": "document_url",
    "document_url": "https://signed-url-with-24-hour-expiry..."
  },
  "include_image_base64": false,
  "table_format": "markdown"
}
```

For image documents, replace the document object with:

```json
{
  "type": "image_url",
  "image_url": "data:image/png;base64,iVBORw0KGgo..."
}
```

### Response Format

Mistral's OCR response provides structured output across all pages:

```json
{
  "pages": [
    {
      "index": 0,
      "markdown": "# Chapter 1\n\nContent extracted and formatted as markdown...",
      "images": [
        {
          "index": 0,
          "base64": "iVBORw0KGgo...",
          "format": "png"
        }
      ],
      "tables": [
        {
          "id": "table_0_0",
          "markdown": "| Header 1 | Header 2 |\n|----------|----------|\n| Cell 1   | Cell 2   |"
        }
      ],
      "dimensions": {
        "width": 612,
        "height": 792,
        "unit": "pt"
      }
    }
  ],
  "model": "mistral-ocr-latest",
  "usage_info": {
    "pages_processed": 5,
    "doc_size_bytes": 1234567
  }
}
```

### Processing Configuration Options

Mistral OCR supports several configuration parameters to customize extraction behavior:

| Parameter | Values | Default | Purpose |
|-----------|--------|---------|---------|
| **includeImages** | true, false | false | Include base64-encoded images in response |
| **tableFormat** | "markdown", "html" | "markdown" | Format for extracted tables |
| **extractHeader** | true, false | N/A | Extract document headers |
| **extractFooter** | true, false | N/A | Extract document footers |
| **preset** | .default, .forTraining, .fullExport | .default | Pre-configured extraction profiles |

Presets provide optimized configurations for specific use cases:
- **.default:** Balanced extraction for standard documents
- **.forTraining:** Optimized for machine learning datasets
- **.fullExport:** Maximum detail including all metadata and formatting

### Pricing & Limits

- **Cost:** $0.001 per page ($1.00 per 1,000 pages)
- **Maximum File Size:** 50MB per document
- **Supported Formats:** PDF, PNG, JPEG, WEBP
- **Processing Time:** Typically 5-30 seconds depending on page count

---

## Claude API Integration (Anthropic)

### Endpoint Configuration

Claude's API provides intelligent analysis capabilities through a streamlined endpoint structure:

| Component | Value |
|-----------|-------|
| **Base URL** | https://api.anthropic.com/v1 |
| **Messages Endpoint** | POST /v1/messages |
| **Primary Model** | claude-sonnet-4-20250514 |
| **Fallback Model** | claude-3-5-sonnet-20241022 |
| **Standard Max Tokens** | 8192 |
| **Extended Max Tokens** | 16384 |
| **Standard Timeout** | 90 seconds |
| **Extended Timeout** | 180 seconds |
| **Maximum Retries** | 2 with 2-second base delay |
| **API Version** | 2023-06-01 |
| **Minimum Content Length** | 100 characters |
| **Max Content Per Request** | 150,000 characters |
| **Authentication** | x-api-key header + anthropic-version header |

### ClaudeAPIConfig Constants

All configuration constants are defined in `ClaudeAPIConfig`:
- **baseURL:** https://api.anthropic.com/v1
- **messagesEndpoint:** "messages"
- **model:** "claude-sonnet-4-20250514"
- **alternativeModel:** "claude-3-5-sonnet-20241022"
- **maxTokens:** 8192
- **extendedMaxTokens:** 16384
- **timeout:** 90 seconds
- **extendedTimeout:** 180 seconds
- **maxRetryAttempts:** 2
- **retryDelay:** 2.0 seconds
- **apiVersion:** "2023-06-01"
- **contentType:** "application/json"
- **minimumContentLength:** 100 characters
- **maxContentPerRequest:** 150,000 characters

### Request Format

Claude requests follow a standardized message structure with the `ClaudeAPIRequest` model:

```swift
struct ClaudeAPIRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
    let system: String?
    let temperature: Double?
    let stopSequences: [String]?

    /// Create a simple single-message request
    static func simple(
        prompt: String,
        system: String? = nil,
        maxTokens: Int = ClaudeAPIConfig.maxTokens
    ) -> ClaudeAPIRequest
}
```

Example JSON request:
```json
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 8192,
  "system": "You are a document analysis expert specializing in structure detection, boundary identification, and content classification. Provide responses in valid JSON format.",
  "messages": [
    {
      "role": "user",
      "content": "Analyze the following document text and identify structural boundaries...\n\n[Document content]"
    }
  ]
}
```

### Message Structure

Messages use the `ClaudeMessage` struct with `MessageRole` enum:

```swift
struct ClaudeMessage: Codable, Equatable, Sendable {
    let role: MessageRole
    let content: String
}

enum MessageRole: String, Codable, Sendable {
    case user = "user"
    case assistant = "assistant"
}
```

### Response Format

Claude responds with structured message objects using `ClaudeAPIResponse`:

```swift
struct ClaudeAPIResponse: Decodable, Equatable, Sendable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContentBlock]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: ClaudeUsage

    /// Extract text content from response (combines all text blocks)
    var textContent: String? { ... }

    /// Whether response was truncated due to max tokens
    var wasTruncated: Bool { stopReason == "max_tokens" }

    /// Whether response completed normally
    var completedNormally: Bool { stopReason == "end_turn" }
}

struct ClaudeContentBlock: Decodable, Equatable, Sendable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: [String: AnyCodable]?
}

struct ClaudeUsage: Decodable, Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int

    var totalTokens: Int { inputTokens + outputTokens }
    var estimatedCost: Decimal { /* $3/$15 per M tokens */ }
    var formattedCost: String { /* USD currency format */ }
}
```

Example JSON response:
```json
{
  "id": "msg_abc123def456",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "{\"boundaries\": [...], \"metadata\": {...}}"
    }
  ],
  "model": "claude-sonnet-4-20250514",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 1234,
    "output_tokens": 567
  }
}
```

### Request Tracking

All Claude API requests are tracked via `ClaudeAPIRequestInfo`:

```swift
struct ClaudeAPIRequestInfo: Sendable {
    let requestId: UUID
    let startedAt: Date
    let prompt: String
    let systemPrompt: String?
    var completedAt: Date?
    var response: ClaudeAPIResponse?
    var error: Error?

    var duration: TimeInterval?
    var formattedDuration: String
    var succeeded: Bool { response != nil && error == nil }
}
```

The ClaudeService maintains a `recentRequests` array (max 50 items) for debugging and performance analysis.

### Claude Service Operations

The `ClaudeService` class conforms to `ClaudeServiceProtocol` and provides the following operational methods:

#### 1. **sendMessage(prompt:system:maxTokens)**
Low-level raw API call method. Handles request formatting, response parsing, error handling, and retry logic. Used internally by all higher-level operations.

```swift
func sendMessage(
    _ prompt: String,
    system: String?,
    maxTokens: Int
) async throws -> ClaudeAPIResponse
```

#### 2. **validateAPIKey()**
Sends a simple test message ("Respond with: OK") to verify API key validity. Returns a boolean indicating successful authentication and connectivity.

```swift
func validateAPIKey() async throws -> Bool
```

#### 3. **analyzeDocument(content:documentType)**
Legacy method for basic pattern detection. Use `analyzeDocumentComprehensive` for full-spectrum analysis.

```swift
func analyzeDocument(
    content: String,
    documentType: String?
) async throws -> DetectedPatterns
```

#### 4. **analyzeDocumentComprehensive(content:enableContentTypeDetection:enableCitationDetection:enableFootnoteDetection:enableChapterDetection)**
Performs full-spectrum pattern detection including content type classification, citation pattern identification, footnote detection, and chapter boundary identification. Returns comprehensive analysis results.

```swift
func analyzeDocumentComprehensive(
    content: String,
    enableContentTypeDetection: Bool,
    enableCitationDetection: Bool,
    enableFootnoteDetection: Bool,
    enableChapterDetection: Bool
) async throws -> DetectedPatterns
```

#### 5. **detectAuxiliaryLists(content)**
Identifies auxiliary structural elements: List of Figures, List of Tables, Index, Bibliography, etc.

```swift
func detectAuxiliaryLists(
    content: String
) async throws -> [AuxiliaryListInfo]
```

#### 6. **detectCitationPatterns(sampleContent)**
Analyzes citation formatting across styles: APA, MLA, Chicago/Turabian, IEEE, Custom.

```swift
func detectCitationPatterns(
    sampleContent: String
) async throws -> CitationDetectionResult
```

#### 7. **detectFootnotePatterns(sampleContent)**
Identifies footnote/endnote markers: superscript numbers (¹, ²), bracketed ([1], [2]), symbols (*, †), letters (a, b, c).

```swift
func detectFootnotePatterns(
    sampleContent: String
) async throws -> FootnoteDetectionResult
```

#### 8. **detectChapterBoundaries(content)**
Locates chapter/part divisions: headers, numbers, hierarchical structure, boundaries.

```swift
func detectChapterBoundaries(
    content: String
) async throws -> ChapterDetectionResult
```

#### 9. **identifyBoundaries(content:sectionType)**
Performs section-specific boundary detection for front matter, TOC, index, back matter.

```swift
func identifyBoundaries(
    content: String,
    sectionType: SectionType
) async throws -> BoundaryInfo
```

#### 10. **extractMetadata(frontMatter)**
Extracts document metadata: title, author, publisher, date, ISBN, language, genre, version.

```swift
func extractMetadata(
    frontMatter: String
) async throws -> DocumentMetadata
```

#### 11. **extractMetadataWithContentType(frontMatter:sampleContent)**
Extracts metadata with content type classification flags.

```swift
func extractMetadataWithContentType(
    frontMatter: String,
    sampleContent: String
) async throws -> (metadata: DocumentMetadata, contentType: ContentTypeFlags)
```

#### 12. **reflowParagraphs(chunk:previousContext:patterns)**
Repairs paragraphs split across page breaks, reconstructing logical units from fragmented OCR output.

```swift
func reflowParagraphs(
    chunk: String,
    previousContext: String?,
    patterns: DetectedPatterns
) async throws -> String
```

#### 13. **optimizeParagraphLength(chunk:maxWords)**
Analyzes paragraph length distribution and intelligently splits excessively long paragraphs while maintaining semantic coherence.

```swift
func optimizeParagraphLength(
    chunk: String,
    maxWords: Int
) async throws -> String
```

### Pricing

Claude API usage is metered by token consumption:

| Component | Cost |
|-----------|------|
| **Input Tokens** | $3.00 per million |
| **Output Tokens** | $15.00 per million |

A typical document analysis might consume 1,000-3,000 input tokens and produce 500-2,000 output tokens, resulting in $0.01-0.10 per document.

---

## Authentication & Credential Management

### Keychain Storage Strategy

Both API keys are securely stored in the system Keychain under a unified service identifier:

```
Service: "com.horus.app"
Accounts: "mistral-api-key", "claude-api-key"
Accessibility: kSecAttrAccessibleWhenUnlocked
```

The `kSecAttrAccessibleWhenUnlocked` attribute ensures keys are only accessible when the device is unlocked, providing security against unauthorized access while maintaining usability during normal operation.

### Credential Operations

The credential management system supports four core operations:

- **store(key, value):** Save an API key to Keychain with automatic encryption
- **retrieve(key):** Fetch an API key from Keychain with decryption
- **delete(key):** Permanently remove an API key from Keychain
- **has(key):** Check whether a key exists without retrieving its value

### Key Validation

Validation occurs in two stages:

#### Format Validation
- Minimum length: 10 characters
- Mistral standard format: "sk-" prefix with minimum 20 characters total
- Claude standard format: "sk-ant-" prefix with minimum 20 characters total

#### API Validation
- **Mistral:** Perform a test call to `/v1/models` endpoint
- **Claude:** Send a simple message with content "Respond with: OK"

Failed validation returns specific error descriptions enabling users to identify and correct issues.

### Display & Masking

API keys are never displayed in plain text in the UI. Masked display follows the pattern:

```
sk-****...****
```

Showing first 5 characters and last 4 characters, masking the sensitive middle portion.

---

## Error Handling & Recovery

### HTTP Status Code Mapping

Horus implements standardized error handling across both APIs:

| HTTP Status | Mistral Error Type | Claude Error Type | Recovery |
|-------------|-------------------|-------------------|----------|
| 400 | invalidRequest | apiError | User review required |
| 401 | authenticationFailed | authenticationFailed | Check API key settings |
| 403 | accessDenied | authenticationFailed | Verify key permissions |
| 413 | fileTooLarge | N/A | Split into smaller files |
| 422 | unprocessableDocument | N/A | Convert/repair document |
| 429 | rateLimited | rateLimited | Wait and retry |
| 5xx | serverError | apiError | Automatic retry |

### Retry Strategy

#### Mistral OCR Retries
- **Maximum Attempts:** 3
- **Backoff Formula:** baseDelay × 2^(attempt-1) + random jitter
- **Initial Delay:** Configurable (typically 1 second)
- **Maximum Delay:** No hard limit, but typically 30 seconds
- **Retryable Errors:** rateLimited, timeout, networkUnavailable, serverError

#### Claude API Retries
- **Maximum Attempts:** 2
- **Backoff Formula:** 2 seconds × 2^(attempt-1) for standard errors, 30 seconds for rate limits
- **Jitter:** Random value (0-1 second) added to reduce thundering herd
- **Retryable Errors:** rateLimited, timeout

The exponential backoff formula prevents overwhelming the API during recovery:

```
delay = baseDelay × 2^(attempt-1) + random(0, 1000)ms

Attempt 1: ~1s
Attempt 2: ~2-3s
Attempt 3: ~4-5s
```

### User-Facing Error Messages

Every error encountered by users includes two components:

1. **errorDescription:** A clear explanation of what went wrong
   - Example: "Authentication failed"

2. **recoverySuggestion:** Actionable guidance for resolution
   - Example: "Please check your API key in Settings."

Complete error message examples:
- "Rate limited. Please wait a moment and try again."
- "Document too large. Maximum file size is 50MB. Please split the document and process separately."
- "Invalid document format. Supported formats: PDF, PNG, JPEG, WEBP."

---

## Network Client Implementation

### NetworkClient.swift Architecture

The NetworkClient provides generic, type-safe HTTP communication:

#### GET Method
```swift
func get<T: Decodable>(url: URL) -> T
```
- Default timeout: 30 seconds
- Automatic JSON decoding with snake_case conversion
- Generic response type support

#### POST Method
```swift
func post<T: Decodable>(url: URL, body: Encodable) -> T
```
- Default timeout: 120 seconds
- JSON request encoding with camelCase conversion
- Automatic response parsing

### JSON Encoding/Decoding Strategy

The network client applies consistent JSON transformation:

- **Encoding:** Convert Swift camelCase to JSON snake_case
  - Example: `documentURL` → `document_url`

- **Decoding:** Convert JSON snake_case to Swift camelCase
  - Example: `doc_size_bytes` → `docSizeBytes`

This strategy maintains idiomatic conventions in both Swift and JSON while preserving API contract compatibility.

### Error Response Parsing

The client automatically parses error responses from both providers:

- **Mistral Format:** Extracts error code and message fields
- **Claude Format:** Extracts error type and message fields
- Generic fallback: HTTP status code interpretation

---

## Response Parsing & Data Handling

### Claude Response Parsing

Claude frequently returns JSON-formatted responses wrapped in markdown code blocks:

```markdown
Here's the analysis:

```json
{
  "boundaries": [...],
  "metadata": {...}
}
```

Additional notes...
```

The response parser performs the following operations:

1. **Markdown Fence Removal:** Strip enclosing ` ```json ` and ` ``` ` markers
2. **Trailing Comma Fixes:** Correct malformed JSON with trailing commas in objects/arrays
3. **JSON Extraction:** Identify and extract valid JSON from mixed responses
4. **Validation:** Verify extracted JSON matches expected schema

### Mistral Response Parsing

Mistral responses arrive in standard JSON format and require straightforward decoding without special handling.

### AnyCodable Wrapper

Many API responses contain dynamically-typed values. The `AnyCodable` struct provides safe type handling through Codable conformance:

```swift
struct AnyCodable: Codable, Equatable, Sendable {
    let value: Any

    // Supports: null, bool, int, double, string, array, dict

    init(from decoder: Decoder) throws
    func encode(to encoder: Encoder) throws
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool
}
```

This enables parsing of heterogeneous JSON structures without predefined schemas:

```swift
struct ClaudeContentBlock: Decodable {
    let type: String
    let input: [String: AnyCodable]?  // Flexible tool input
}
```

Useful for:
- Flexible metadata fields
- Variable response formats
- Dynamic configuration objects
- Tool input parameters

---

## Prompt Engineering & Management

### PromptManager Actor Architecture

The `PromptManager` provides thread-safe management of prompt templates:

- **Storage:** .txt template files in application bundle (`Resources/Prompts/`)
- **Access Pattern:** Actor-based concurrency for thread safety
- **Variable Substitution:** `{variableName}` syntax for dynamic content
- **Caching:** Templates cached in memory after first load

```swift
actor PromptManager {
    func loadTemplate(_ name: String) async throws -> String
    func populateTemplate(_ template: String, with variables: [String: String]) -> String
}
```

### Prompt Template Library

Eight primary prompt templates optimize different analysis operations:

| Template | Purpose | Primary Use |
|----------|---------|-------------|
| **structureAnalysis_v1.txt** | Analyze document structure and hierarchy | Initial document processing |
| **contentTypeDetection_v1.txt** | Classify document type and category | Content categorization |
| **patternDetection_v1.txt** | Identify recurring patterns in content | Statistical analysis |
| **frontMatterBoundary_v1.txt** | Detect front matter sections | Structural boundaries |
| **backMatterBoundary_v1.txt** | Detect back matter sections | Structural boundaries |
| **paragraphReflow_v1.txt** | Repair broken paragraphs | Document cleaning |
| **paragraphOptimization_v1.txt** | Split and optimize paragraph length | Readability improvement |
| **finalReview_v1.txt** | Comprehensive quality review | Final validation |

### Variable Substitution

Templates use curly-brace syntax for variable insertion:

```
Analyze the following document text:

{documentContent}

Specifically identify:
- Chapter boundaries
- Citation styles used
- Footnote markers
```

The PromptManager substitutes variables at runtime before sending requests to Claude:

```swift
let template = try await promptManager.loadTemplate("patternDetection_v1.txt")
let populated = promptManager.populateTemplate(template, with: [
    "documentContent": ocrText,
    "sampleLength": "1000"
])
```

### Key Prompting Patterns

**System Prompts** define Claude's role and constraints:
- "You are a document analysis expert specializing in structure detection"
- "Preserve ambiguous content when uncertain"
- "Respond only with valid JSON"

**User Prompts** provide document content and specific instructions:
- Include raw OCR text from Mistral
- Specify the exact analysis required
- Request JSON-formatted responses for structured parsing

**Conservative Instructions** guide Claude toward safer outputs:
- "When uncertain, preserve content rather than removing it"
- "Include sections that might be relevant even if not definitive"
- "Prioritize completeness over aggressiveness"

---

## Cost Tracking & Financial Controls

### Per-Operation Token Tracking

The `ClaudeUsage` struct records token consumption for each API call:

```swift
struct ClaudeUsage: Decodable, Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int

    var totalTokens: Int { inputTokens + outputTokens }

    /// Estimated cost based on Claude Sonnet pricing
    /// Input: $3 per million tokens
    /// Output: $15 per million tokens
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

This enables precise cost accounting at the operation level, with automatic cost calculation using `Decimal` for precision.

### Per-Document Cost Calculation

Document-level cost aggregation sums all operations performed:

```
documentCost = (totalInputTokens × $0.000003) + (totalOutputTokens × $0.000015)
```

A typical document might cost $0.02-0.10 depending on size and complexity.

### Session-Level Accumulation

Sessions maintain cumulative costs using `Decimal` arithmetic for precision:

```swift
var sessionCost: Decimal = 0.0

// After each operation
if let usage = response.usage {
    sessionCost += usage.estimatedCost
}
```

`Decimal` types prevent floating-point rounding errors that could accumulate across many documents. The `CostCalculator` service provides:

```swift
protocol CostCalculatorProtocol {
    func calculateOCRCost(pageCount: Int) -> Decimal
    func calculateCleaningCost(tokens: Int) -> Decimal
    func formatCurrency(_ amount: Decimal) -> String
}
```

### Real-Time Cost Display

The UI displays costs at multiple levels:
- Per-operation cost upon completion
- Per-document cost summary
- Session total cost in progress indicator
- Estimated final cost based on current usage patterns

### Cost Confirmation Dialog

When document processing would exceed a configurable threshold (default $0.50):

1. Display estimated final cost
2. Request user confirmation before proceeding
3. Allow proceeding, adjusting parameters, or canceling
4. Track confirmed vs. estimated costs for accuracy

---

## Rate Limiting & Throttling

### Provider Rate Limits

Both Mistral and Claude implement rate limits:

- **Mistral:** Typically 30-100 requests per minute depending on plan tier
- **Claude:** Typically 1000-5000 requests per minute depending on plan tier

### Exponential Backoff on 429 Responses

When either API returns HTTP 429 (Too Many Requests):

1. Calculate backoff delay using exponential formula
2. Pause processing for calculated duration
3. Retry the request
4. Repeat up to configured maximum retries

### Server-Side Rate Limit Respect

Rather than implementing client-side rate limiting, Horus respects server-side limits:

- No pre-emptive request throttling
- Reactive retry on 429 responses
- No token bucket algorithms
- No sliding window implementations

This simplification assumes API providers manage rate limits appropriately and prefer responsive error feedback to client-side prediction.

### Sequential Processing

Documents are processed sequentially, not in parallel:

- One document at a time through Mistral OCR
- One document at a time through Claude analysis
- This prevents thundering herd situations
- Provides predictable, reproducible behavior
- Simplifies rate limit management

---

## Testing & Mocking Strategies

### MockClaudeService

The MockClaudeService provides complete Claude API simulation:

#### Configurable Responses
```swift
var mockResponse: String = "{\"boundaries\": []}"
```
Set expected response for any operation.

#### Error Simulation
```swift
var simulateError: ClaudeError? = nil
```
Inject errors to test error handling paths.

#### Call Tracking
```swift
var callHistory: [(operation: String, document: String)] = []
```
Track invocations for assertion in tests.

#### Delay Simulation
```swift
var responseDelay: TimeInterval = 0
```
Simulate network latency for timeout testing.

### MockOCRService

The MockOCRService simulates Mistral OCR processing:

- Configurable OCR results per file
- Error injection for failure scenarios
- Response time simulation
- Call history tracking

### MockNetworkClient

Generic network client mock:

- Configurable responses for any URL
- HTTP status code simulation
- Request/response tracking
- Timeout simulation

### MockAPIKeyValidator

API key validation simulation:

- Configurable set of "valid" keys
- Network error simulation
- Validation logic override

### Preview Configurations

Three predefined configurations support different testing scenarios:

#### .preview
Realistic data, normal delays. Suitable for visual testing and user flows.

#### .failing
All operations fail with appropriate errors. Tests error UI and recovery flows.

#### .slow
2-second response delays. Tests timeout handling and loading state UI.

---

## Integration Workflow

### Complete Document Processing Pipeline

1. **User Selection:** User selects document file
2. **Upload & Validation:** File size and format validation
3. **Mistral OCR:** Extract text and structure via Mistral Vision API
4. **Claude Analysis:** Comprehensive analysis via Claude API
5. **Cleaning Operations:** Apply Claude-powered cleaning transformations
6. **Quality Review:** Final review and validation
7. **Export:** Deliver processed document to user
8. **Cost Accounting:** Record final costs and usage metrics

### Error Recovery Workflow

1. **Error Detection:** Network or API error occurs
2. **Classification:** Categorize error (auth, rate limit, server, network)
3. **Retry Decision:** Determine if retryable (based on error type)
4. **Exponential Backoff:** Wait with increasing delays
5. **Retry Attempt:** Re-submit request
6. **Exhaustion or Success:** Either succeed or present error to user

### Cost Control Workflow

1. **Cost Calculation:** Track tokens for each operation
2. **Threshold Check:** Compare cumulative cost to threshold
3. **Confirmation:** If exceeded, request user approval
4. **Proceeding:** Continue with user confirmation or cancel
5. **Final Accounting:** Record actual vs. estimated costs

---

## Best Practices & Recommendations

### API Key Management
- Store keys in Keychain, never in files or memory longer than necessary
- Validate keys immediately after user entry
- Implement key rotation procedures for security
- Never log or display full API keys

### Error Handling
- Always present user-friendly error descriptions
- Provide actionable recovery suggestions
- Log detailed error information server-side for debugging
- Implement exponential backoff to avoid overwhelming APIs

### Cost Management
- Display costs proactively before expensive operations
- Implement threshold warnings for high-cost documents
- Track usage over time to identify optimization opportunities
- Offer users granularity controls (quality levels, document partitioning)

### Performance Optimization
- Cache OCR results to avoid reprocessing identical documents
- Batch small documents when possible while respecting rate limits
- Use appropriate model selection (cost vs. quality tradeoff)
- Implement request timeout thresholds appropriate to operation types

### Testing & Quality Assurance
- Use provided mock services for rapid iteration
- Test error paths as thoroughly as happy paths
- Verify retry logic with synthetic rate limit scenarios
- Validate cost calculations against known token counts

---

## Conclusion

The Horus API integration architecture provides a robust, well-tested foundation for document processing. By clearly separating OCR concerns (Mistral) from analysis concerns (Claude), implementing comprehensive error handling and retry logic, and maintaining strict financial controls, the system delivers reliable document processing with predictable costs and user-friendly error experiences.

The combination of well-designed APIs, careful credential management, strategic retry policies, and extensive testing capabilities creates a platform capable of processing diverse document types while maintaining security, reliability, and cost efficiency.
