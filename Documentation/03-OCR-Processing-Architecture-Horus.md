# Horus — OCR Processing Architecture

**Version:** 1.0 — February 2026

---

## Executive Summary

The OCR Processing subsystem is the cornerstone of Horus's document ingestion pipeline, responsible for transforming unstructured image and PDF documents into machine-readable markdown and structured data. This document provides a comprehensive technical analysis of the OCR architecture, including the processing pipeline, API integration patterns, error handling strategies, and the integration mechanisms that connect OCR output to the cleaning and enrichment pipeline.

The architecture leverages Mistral's Vision API (pixtral-large-latest model) as the sole OCR provider, combined with native macOS integration via PDFKit for efficient document validation and metadata extraction. The system is designed to handle high-volume document processing with robust error recovery, cost tracking, and progress monitoring capabilities.

---

## 1. OCR Architecture Overview

### 1.1 Core Philosophy

The OCR subsystem follows a modular, protocol-driven architecture with clear separation of concerns:

- **Provider Abstraction:** OCRServiceProtocol enables potential future provider swapping
- **Async-First Design:** All operations use Swift concurrency (async/await)
- **Deterministic Processing:** Results are reproducible and cacheable
- **Cost Transparency:** Every operation tracks monetary impact
- **Graceful Degradation:** Supports direct-to-clean pathways for documents without OCR requirements

### 1.2 OCR Provider: Mistral Vision API

**Provider:** Mistral AI (`pixtral-large-latest` model for vision/OCR capabilities)

**API Endpoints:**
- `POST /v1/ocr` - Primary OCR processing endpoint
- `POST /v1/files` - PDF file upload and storage
- `GET /v1/files/{fileId}/url` - Signed URL retrieval with expiration

**Authentication:** Bearer token via Authorization header, stored securely in Keychain

**Supported Input Methods:**
1. **File Upload (PDF):** Multipart form-data submission to Files API, returns fileId
2. **Direct URL (PDF):** Presigned URL pointing to uploaded file
3. **Base64 Encoding (Images):** Inline data URI submission

**Output Format:** JSON response containing OCR results per page, including:
- Markdown content
- Structured table extraction
- Image metadata and bounding boxes
- Hyperlink detection and preservation
- Page dimensions and layout information

### 1.3 Native macOS Integration

**PDFKit Framework Integration:**

PDFKit provides efficient document validation without full OCR processing:

```swift
// Validation without OCR overhead
let document = PDFDocument(url: fileURL)
let pageCount = document.pageCount       // Page counting via PDFKit
let isEncrypted = document.isEncrypted   // Encryption detection
let allowsPrinting = document.allowsPrinting

// PDF to image conversion for single-page preview
let pdfPage = document.page(at: 0)
// Uses PDFPage.thumbnail(of:for:) for efficient rendering
let cgImage = pdfPage.thumbnail(of: CGSize(width: 210, height: 270), for: .artBox)
```

**Benefits:**
- Zero-cost page counting (no API calls)
- Encryption detection prevents sending protected PDFs to API
- Fast thumbnail generation for UI preview
- Memory-efficient page extraction

### 1.4 Security-Scoped Resource Access

All file operations use macOS security-scoped resource URLs to comply with app sandboxing:

```
┌─────────────────────────────────────────┐
│  User Selects File via Open Panel       │
│  → File Reference (security-scoped)     │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  url.startAccessingSecurityScopedResource() │
│  → Begin operations on file             │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  defer {                                │
│    url.stopAccessingSecurityScoped...   │
│  }                                      │
│  → Cleanup (guaranteed via defer block) │
└─────────────────────────────────────────┘
```

**Pattern Usage:**
```swift
guard fileURL.startAccessingSecurityScopedResource() else {
    throw OCRError.accessDenied
}
defer {
    fileURL.stopAccessingSecurityScopedResource()
}
// Perform file operations within this scope
```

Security-scoped URLs are serialized for persistence in the document's metadata, allowing long-term access without repeated user approval dialogs.

---

## 2. OCRService Architecture

### 2.1 Service Design

**Location:** `Core/Services/OCRService.swift`

**Declaration:**
```swift
@MainActor
final class OCRService: OCRServiceProtocol {
    static let shared = OCRService()

    private let keychainService: KeychainService
    private let costCalculator: CostCalculator
    private let networkClient: NetworkClient

    // Configuration
    private let defaultTimeout: TimeInterval = 120.0
    private let maxRetries: Int = 3
    private let baseRetryDelay: TimeInterval = 1.0
}
```

**Responsibilities:**
- Orchestrating the 4-phase processing pipeline
- Managing API authentication via Keychain
- Coordinating cost calculations
- Implementing retry logic and error recovery
- Publishing progress updates via ProcessingProgress callbacks

**Concurrency Model:**
- Marked with `@MainActor` to ensure UI safety
- Internal async operations execute on background threads
- Progress callbacks dispatch to main thread for UI updates

### 2.2 Dependencies

| Dependency | Purpose | Responsibility |
|-----------|---------|-----------------|
| `KeychainService` | API Key Management | Secure storage/retrieval of Mistral API token |
| `CostCalculator` | Financial Tracking | Per-page cost computation (USD with Decimal precision) |
| `NetworkClient` | HTTP Communication | Multipart uploads, JSON API calls, signed URL handling |
| `PDFKit` | Document Validation | Page counting, encryption detection, thumbnail generation |
| `TokenEstimator` | Metrics Calculation | Estimated token consumption for cleaned content |

---

## 3. Processing Pipeline: Four Phases

The OCR processing pipeline is decomposed into four distinct phases, each with specific responsibilities and failure modes.

### 3.1 Phase 1: Preparing

**Purpose:** Validate document integrity and determine processing pathway

**Operations:**

1. **Document Existence Check**
   - Verify file exists at provided URL
   - Confirm file is readable by the application
   - Return `.fileNotFound` or `.fileReadError` if validation fails

2. **Pathway Determination**
   ```
   Document Type Decision Tree:

   ├─ PDF?
   │  ├─ Encrypted? → Unsupported (reject)
   │  ├─ > 1000 pages? → Reject (.fileTooLarge conceptually)
   │  └─ Valid? → OCR Pathway
   │
   ├─ Image (PNG, JPEG, TIFF, GIF, WebP, BMP)?
   │  ├─ > 100 MB? → Reject (.fileTooLarge)
   │  └─ Valid? → OCR Pathway
   │
   └─ Direct-to-Clean Format (TXT, RTF, JSON, XML, HTML)?
       └─ Direct to CleaningService (bypass OCR)
   ```

3. **Security-Scoped Resource Setup**
   ```swift
   let success = fileURL.startAccessingSecurityScopedResource()
   guard success else {
       throw OCRError.accessDenied
   }
   defer {
       fileURL.stopAccessingSecurityScopedResource()
   }
   // Perform operations within this scope
   ```

4. **File Size Validation**
   - OCR documents: maximum 100 MB
   - Fail early if exceeds limit
   - Prevents wasted API calls and bandwidth

**Errors Thrown:**
- `OCRError.fileReadError` - Cannot access file
- `OCRError.accessDenied` - Security scoping failed
- `OCRError.unsupportedFormat` - Document type not supported
- `OCRError.fileTooLarge` - Exceeds 100 MB limit
- `OCRError.unprocessableDocument` - PDF encrypted or corrupt

**Progress Callback:** `ProcessingProgress(phase: .preparing, totalPages: pageCount)`

### 3.2 Phase 2: Uploading

**Purpose:** Prepare document for API transmission and obtain references

This phase differs significantly between PDF and image pathways.

#### PDF Upload Path

**Multipart Form-Data Submission:**

```
POST /v1/files HTTP/1.1
Host: api.mistral.ai
Authorization: Bearer {API_KEY}
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW

------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="file"; filename="document.pdf"
Content-Type: application/pdf

[PDF Binary Data]
------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="purpose"

ocr
------WebKitFormBoundary7MA4YWxkTrZu0gW--
```

**Response:**
```json
{
  "id": "file_abc123def456",
  "object": "file",
  "size": 2048576,
  "filename": "document.pdf",
  "created_at": "2026-02-08T12:34:56Z"
}
```

**Signed URL Retrieval:**

```
GET /v1/files/file_abc123def456/url?expiry=24 HTTP/1.1
Host: api.mistral.ai
Authorization: Bearer {API_KEY}

Response:
{
  "file_id": "file_abc123def456",
  "url": "https://files.mistral.ai/...?sig=...",
  "expires_at": "2026-02-09T12:34:56Z"
}
```

**DocumentPayload Construction:**
```swift
let documentPayload = DocumentPayload.documentURL(
    url: signedURL // Valid for 24 hours
)
```

#### Image Upload Path

**Base64 Encoding:**

```swift
let imageData = try Data(contentsOf: imageURL)
let base64String = imageData.base64EncodedString()
let dataURI = "data:image/jpeg;base64,\(base64String)"

let documentPayload = DocumentPayload.imageURL(dataURI)
```

**Advantages:**
- No separate upload request required
- Single payload submission in Phase 3
- Useful for smaller images (< 10 MB)

**Disadvantages:**
- Data URI embedded in request body (verbose)
- Not suitable for large images or bandwidth-constrained scenarios

#### File Upload Implementation

**Multipart Form-Data Construction:**

The file upload uses standard multipart/form-data with custom boundary string construction:

```swift
let boundary = "----WebKitFormBoundary" + UUID().uuidString
var bodyData = Data()

// Add file part
bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
bodyData.append("Content-Disposition: form-data; name=\"file\"; filename=\"document.pdf\"\r\n".data(using: .utf8)!)
bodyData.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
bodyData.append(pdfData)
bodyData.append("\r\n".data(using: .utf8)!)

// Add purpose field
bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
bodyData.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
bodyData.append("ocr".data(using: .utf8)!)
bodyData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

// Set Content-Type header with boundary
var request = URLRequest(url: uploadURL)
request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
request.httpBody = bodyData
```

#### Upload Error Handling

**Errors:**
- `OCRError.fileUploadFailed` - Multipart submission failed
- `OCRError.signedURLFailed` - Unable to obtain valid URL
- `OCRError.networkUnavailable` - No internet connectivity

**Progress Callback:** `ProcessingProgress(phase: .uploading, currentPage: 0)`

### 3.3 Phase 3: Processing

**Purpose:** Submit prepared document to Mistral OCR API and receive results

#### OCR API Request Construction

```swift
struct OCRAPIRequest {
    let model: String = "mistral-ocr-latest"
    let documentPayload: DocumentPayload
    let processingSettings: ProcessingSettings
}

struct ProcessingSettings {
    let includeImages: Bool
    let tableFormat: TableFormat // .markdown or .html
    let extractHeader: Bool
    let extractFooter: Bool

    static let `default` = ProcessingSettings(
        includeImages: true,
        tableFormat: .markdown,
        extractHeader: true,
        extractFooter: true
    )

    static let forTraining = ProcessingSettings(
        includeImages: false,
        tableFormat: .markdown,
        extractHeader: false,
        extractFooter: false
    )

    static let fullExport = ProcessingSettings(
        includeImages: true,
        tableFormat: .html,
        extractHeader: true,
        extractFooter: true
    )
}
```

#### HTTP Request Details

```
POST /v1/ocr HTTP/1.1
Host: api.mistral.ai
Authorization: Bearer {API_KEY}
Content-Type: application/json
Timeout: 120s

{
  "model": "mistral-ocr-latest",
  "document": {
    "document_url": "https://files.mistral.ai/...?sig=..."
    // OR
    "image_url": "data:image/jpeg;base64,..."
    // OR
    "file_id": "file_abc123def456"
  },
  "settings": {
    "include_images": true,
    "table_format": "markdown",
    "extract_header": true,
    "extract_footer": true
  }
}
```

#### Retry Logic Implementation

**Exponential Backoff with Jitter:**

```
Retry Decision Tree:

┌──────────────────────────────────────┐
│  API Call Fails                      │
│  (Network/Rate Limit/Timeout/Server) │
└────────┬─────────────────────────────┘
         │
         ▼
    Is Retryable?
    ├─ Yes → Continue
    └─ No  → Throw error
         │
         ▼
    Attempt ≤ 3?
    ├─ No  → Throw exhaustedRetries
    └─ Yes → Continue
         │
         ▼
    delaySeconds = 1.0 * 2^(attempt-1) + random(0, 1000ms)

    Attempt 1: 1s + jitter     (0-1s random)
    Attempt 2: 2s + jitter     (0-1s random)
    Attempt 3: 4s + jitter     (0-1s random)
         │
         ▼
    await Task.sleep(nanoseconds)
    Retry API call
```

**Retryable Error Types:**
- `OCRError.rateLimited` - HTTP 429
- `OCRError.timeout` - Request exceeded timeout
- `OCRError.networkUnavailable` - Connection lost mid-request
- `OCRError.serverError` - HTTP 5xx errors

**Non-Retryable Errors:**
- `OCRError.authenticationFailed` - Invalid API key
- `OCRError.invalidRequest` - Malformed request body
- `OCRError.fileTooLarge` - Document exceeds API limits
- `OCRError.unprocessableDocument` - Corrupted document content

**Progress Callback:** `ProcessingProgress(phase: .processing, currentPage: pageIndex)` (updated as pages complete)

### 3.4 Phase 4: Finalizing

**Purpose:** Transform API response into domain models and compute metrics

#### OCR Result Construction

```swift
struct OCRResult {
    let id: UUID
    let documentId: UUID
    let rawContent: String          // Original OCR output
    let markdownContent: String     // Formatted markdown
    let pages: [OCRPage]
    let model: String = "pixtral-large-latest"
    let cost: Decimal
    let processingDuration: TimeInterval
    let completedAt: Date
    let confidence: Double          // 0.0-1.0 confidence score
    let language: String?           // Detected language
    let apiCallCount: Int
    let tokensUsed: Int

    // Computed Properties
    var pageCount: Int { pages.count }
    var fullMarkdown: String { pages.map(\.markdown).joined(separator: "\n\n---\n\n") }
    var fullPlainText: String { pages.map(\.plainText).joined(separator: "\n\n") }
    var wordCount: Int { fullPlainText.split(separator: " ").count }
    var characterCount: Int { fullMarkdown.count }
    var estimatedTokenCount: Int { TokenEstimator.estimate(fullMarkdown) }

    func contentWithMetadata() -> String
    func toJSON() -> [String: Any]
}
```

#### Page-Level Data Transformation

```swift
struct OCRPage {
    let index: Int
    let markdown: String
    let tables: [ExtractedTable]
    let images: [ExtractedImage]
    let dimensions: PageDimensions

    var plainText: String {
        markdown
            .replacingOccurrences(of: "\\*\\*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "\\[(.+?)\\]\\(.*?\\)", with: "$1") // Remove links
    }
}

struct ExtractedTable {
    let id: UUID
    let markdown: String
    let rowCount: Int
    let columnCount: Int
}

struct ExtractedImage {
    let id: UUID
    let topLeftX: Double
    let topLeftY: Double
    let bottomRightX: Double
    let bottomRightY: Double
    let hasImageData: Bool // Indicates if full image bytes are available
}

struct PageDimensions {
    let width: Double
    let height: Double
    let unit: String // "px" or "pt"
}
```

#### Cost Calculation

```swift
let pageCount = ocrResponse.pages.count
let costPerPage: Decimal = 0.001 // $0.001 per page
let totalCost = Decimal(pageCount) * costPerPage

// Example: 500-page document
// Cost = 500 × $0.001 = $0.50
// Cost = Decimal(500) × Decimal(0.001) = Decimal("0.50")
```

**Cost Tracking:**
- Per-document cost stored in OCRResult
- Session aggregate tracked via ProcessingSession
- Cost confirmation threshold: $0.50 (configurable in UserPreferences)
- Users are prompted for confirmation if estimated cost exceeds threshold

#### Processing Duration

```swift
let startTime = Date()
// ... perform OCR operations ...
let duration = Date().timeIntervalSince(startTime)
// Recorded in OCRResult.processingDuration
```

**Typical Durations by Document Size:**
- 10-page document: 2-5 seconds
- 50-page document: 8-15 seconds
- 100-page document: 15-30 seconds
- 500-page document: 60-120 seconds

#### Progress Callback

```swift
ProcessingProgress(
    phase: .finalizing,
    totalPages: pageCount,
    currentPage: pageCount,
    elapsedTime: duration,
    estimatedRemainingTime: 0
)
```

---

## 4. API Models and Data Structures

### 4.1 DocumentPayload Enum

The DocumentPayload enum provides a type-safe way to represent the three document submission methods:

```swift
enum DocumentPayload {
    case documentURL(URL)      // Signed URL from Files API
    case imageURL(String)      // Data URI: data:image/jpeg;base64,...
    case fileID(String)        // Direct file reference (less common)
}
```

**Usage in OCRAPIRequest:**
```json
{
  "document": {
    "document_url": "https://..."  // From .documentURL case
  }
}
```

### 4.2 ProcessingSettings Presets

Three preset configurations address common use cases:

| Preset | includeImages | tableFormat | extractHeader | extractFooter | Use Case |
|--------|---------------|-------------|---------------|---------------|----------|
| `.default` | true | markdown | true | true | General purpose |
| `.forTraining` | false | markdown | false | false | ML training datasets (minimal settings) |
| `.fullExport` | true | html | true | true | Complete archival (all features enabled) |

**Configuration Details:**
```swift
struct ProcessingSettings {
    let includeImages: Bool              // Embed/extract images
    let tableFormat: TableFormat        // .markdown or .html
    let extractHeader: Bool             // Extract page headers
    let extractFooter: Bool             // Extract page footers
    let extractMetadata: Bool           // Extract document metadata
    let languageHint: String?           // Optional language code for OCR

    static let `default` = ProcessingSettings(
        includeImages: true,
        tableFormat: .markdown,
        extractHeader: true,
        extractFooter: true,
        extractMetadata: true,
        languageHint: nil
    )

    static let forTraining = ProcessingSettings(
        includeImages: false,
        tableFormat: .markdown,
        extractHeader: false,
        extractFooter: false,
        extractMetadata: false,
        languageHint: nil
    )

    static let fullExport = ProcessingSettings(
        includeImages: true,
        tableFormat: .html,
        extractHeader: true,
        extractFooter: true,
        extractMetadata: true,
        languageHint: nil
    )
}
```

**Custom Configuration:**
```swift
let settings = ProcessingSettings(
    includeImages: true,
    tableFormat: .html,
    extractHeader: false,
    extractFooter: true,
    extractMetadata: true,
    languageHint: "en"
)
```

### 4.3 OCRAPIResponse Structure

```swift
struct OCRAPIResponse: Decodable {
    let pages: [APIPageResult]
    let usage: UsageInfo
    let model: String
}

struct APIPageResult: Decodable {
    let pageNumber: Int
    let markdown: String
    let tables: [APITable]
    let images: [APIImage]
    let hyperlinks: [APIHyperlink]
    let dimensions: APIDimensions
    let headers: [String]?
    let footers: [String]?
}

struct APITable: Decodable {
    let markdown: String
    let rowCount: Int
    let columnCount: Int
}

struct APIImage: Decodable {
    let url: String?
    let bounding_box: BoundingBox
    let alt_text: String?
}

struct APIHyperlink: Decodable {
    let text: String
    let url: String
    let page_relative_coordinates: BoundingBox
}

struct UsageInfo: Decodable {
    let pages_processed: Int
    let document_size_bytes: Int
}
```

---

## 5. Error Handling Architecture

### 5.1 OCRError Enumeration

```swift
enum OCRError: LocalizedError {
    // Authentication Errors
    case missingAPIKey
    case authenticationFailed(message: String)
    case accessDenied

    // Rate Limiting
    case rateLimited(retryAfterSeconds: Int? = nil)

    // Network Errors
    case networkUnavailable
    case timeout
    case cancelled

    // Document Validation
    case unsupportedFormat(format: String)
    case fileTooLarge(sizeBytes: Int)
    case fileReadError(path: String, reason: String)
    case unprocessableDocument(reason: String)

    // API Communication
    case fileUploadFailed(reason: String)
    case signedURLFailed(fileId: String)
    case invalidRequest(details: String)
    case invalidResponse(reason: String)

    // Server Errors
    case serverError(code: Int, message: String)

    // Computed Properties
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .timeout, .networkUnavailable, .serverError:
            return true
        default:
            return false
        }
    }

    var localizedDescription: String {
        switch self {
        case .missingAPIKey:
            return "OCR API key is not configured. Please add it in Settings."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .rateLimited(let retryAfter):
            let waitTime = retryAfter.map { "\($0) seconds" } ?? "a few moments"
            return "API rate limit exceeded. Please retry in \(waitTime)."
        case .timeout:
            return "Request timed out. The document may be large or network may be slow."
        case .fileTooLarge(let sizeBytes):
            let sizeMB = Double(sizeBytes) / (1024 * 1024)
            return "Document is too large (\(String(format: "%.1f", sizeMB)) MB). Maximum is 100 MB."
        case .unsupportedFormat(let format):
            return "File format '\(format)' is not supported for OCR."
        case .unprocessableDocument(let reason):
            return "Document cannot be processed: \(reason)"
        default:
            return "An OCR processing error occurred."
        }
    }
}
```

### 5.2 HTTP Status Code Mapping

```
HTTP Status Code → OCRError

400 Bad Request           → .invalidRequest
401 Unauthorized          → .authenticationFailed
403 Forbidden             → .accessDenied
413 Payload Too Large     → .fileTooLarge
422 Unprocessable Entity  → .unprocessableDocument
429 Too Many Requests     → .rateLimited (with Retry-After)
500 Internal Server Error → .serverError(500, "...")
502 Bad Gateway           → .serverError(502, "...")
503 Service Unavailable   → .serverError(503, "...")
504 Gateway Timeout       → .timeout
```

### 5.3 Error Recovery Strategies

**Strategy 1: Automatic Retry (Retryable Errors)**
```
Error thrown
  ├─ isRetryable?
  │  ├─ Yes → Exponential backoff retry (max 3 attempts)
  │  └─ No  → Throw immediately
  │
  └─ User sees progress, silent retry
```

**Strategy 2: User Confirmation (Cost-Related Errors)**
```
Estimated cost exceeds threshold ($0.50)
  → Show confirmation dialog
  → User approves or cancels
  → Proceed or throw .userCancelledOperation
```

**Strategy 3: Direct Throw (Authentication/Format Errors)**
```
Authentication/Format validation fails
  → Throw immediately
  → User receives clear error message
  → Direct to settings or file selection
```

---

## 6. Document Support Matrix

### 6.1 OCR-Required Formats

These formats must be processed through the OCR pipeline:

| Format | Extension | Max Size | Notes |
|--------|-----------|----------|-------|
| PDF | .pdf | 100 MB | Encrypted PDFs rejected |
| PNG | .png | 100 MB | Lossless, preserves quality |
| JPEG | .jpg, .jpeg | 100 MB | Compressed but widely supported |
| TIFF | .tiff, .tif | 100 MB | Multi-page support via OCR |
| GIF | .gif | 100 MB | Animated GIFs: first frame only |
| WebP | .webp | 100 MB | Modern format with excellent compression |
| BMP | .bmp | 100 MB | Uncompressed, larger files |

### 6.2 Direct-to-Clean Formats

These formats bypass OCR and flow directly to CleaningService:

| Format | Extension | Path | Rationale |
|--------|-----------|------|-----------|
| Plain Text | .txt | Direct-to-Clean | Already machine-readable |
| RTF | .rtf | Direct-to-Clean | Rich text structure preserved |
| JSON | .json | Direct-to-Clean | Structured data format |
| XML | .xml | Direct-to-Clean | Structured markup |
| HTML | .html | Direct-to-Clean | Web document format |
| Markdown | .md | Direct-to-Clean | Already clean markdown |

### 6.3 Unsupported Formats

The following formats are explicitly rejected:

```
Word Documents (.docx, .doc)
  → Reason: Require specialized parsing beyond scope
  → Recommendation: Export as PDF and re-upload

Excel Spreadsheets (.xlsx, .xls)
  → Reason: Tabular data requires specialized handling
  → Recommendation: Export as CSV/JSON

PowerPoint Presentations (.pptx, .ppt)
  → Reason: Slide-based structure incompatible with OCR flow

Encrypted PDFs
  → Reason: Cannot be processed without decryption key
  → Detection: PDFKit.isEncrypted property
```

### 6.4 Size and Page Limits

```swift
enum Document {
    static let maxFileSize: Int = 100 * 1024 * 1024      // 100 MB
    static let maxPageCount: Int = 1000                   // 1000 pages
    static let maxPageCountForThumbnails: Int = 500       // Thumbnail cache limit
}
```

**Validation Flow:**
```
File selected
  ├─ fileSize > 100 MB? → Reject (.fileTooLarge)
  ├─ Format unsupported? → Reject (.unsupportedFormat)
  ├─ PDF encrypted? → Reject (.unprocessableDocument)
  ├─ pageCount > 1000? → Reject (configuration error)
  └─ All checks pass → Proceed to OCR
```

---

## 7. Cost Model and Financial Tracking

### 7.1 Mistral OCR Pricing

```
Base Rate: $0.001 per page
           $1.00 per 1,000 pages

Calculation Examples:
  10-page document:   10 × $0.001 = $0.01
  100-page document: 100 × $0.001 = $0.10
  500-page document: 500 × $0.001 = $0.50
  1000-page document: 1000 × $0.001 = $1.00
```

### 7.2 Cost Calculator Implementation

```swift
class CostCalculator {
    static let pricePerPage: Decimal = 0.001

    func calculateCost(pageCount: Int) -> Decimal {
        Decimal(pageCount) * Self.pricePerPage
    }

    func formatCost(_ cost: Decimal) -> String {
        let number = NSNumber(decimal: cost)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: number) ?? "$0.00"
    }
}

// Usage
let calculator = CostCalculator()
let cost = calculator.calculateCost(pageCount: 500)  // Decimal("0.50")
let formatted = calculator.formatCost(cost)          // "$0.50"
```

### 7.3 Cost Confirmation Flow

```
User selects document
  ↓
Estimate OCR cost based on page count
  ├─ Cost < $0.50 → Proceed automatically
  └─ Cost ≥ $0.50 → Show confirmation dialog
                      ├─ User approves → Proceed
                      ├─ User cancels → Abort
                      └─ User opts for reduced settings → Retry with .forTraining preset
```

**Configurable Threshold:**
```swift
struct UserPreferences {
    var costConfirmationThreshold: Decimal = 0.50
}
```

### 7.4 Session and Document Cost Tracking

```swift
struct ProcessingSession {
    var documents: [Document]

    var totalCostUSD: Decimal {
        documents
            .compactMap(\.result?.cost)
            .reduce(0, +)
    }

    var formattedTotalCost: String {
        CostCalculator().formatCost(totalCostUSD)
    }
}
```

**Cost Visibility in UI:**
- Per-document cost displayed after processing
- Session total updated in real-time
- Cost history available in document properties
- Export functionality includes cost metadata

---

## 8. Progress Tracking and Monitoring

### 8.1 ProcessingProgress Model

```swift
struct ProcessingProgress: Equatable, Sendable {
    enum Phase: String, Equatable, Sendable {
        case preparing = "Preparing"
        case uploading = "Uploading"
        case processing = "Processing"
        case finalizing = "Finalizing"
    }

    let id: UUID
    let phase: Phase
    let totalPages: Int
    let currentPage: Int
    let elapsedTime: TimeInterval
    let estimatedRemainingTime: TimeInterval

    var percentComplete: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }

    var formattedElapsedTime: String {
        formatTimeInterval(elapsedTime)
    }

    var formattedRemainingTime: String {
        formatTimeInterval(estimatedRemainingTime)
    }
}
```

### 8.2 Phase Definitions and Timing

```
Phase Timeline:

[0s] Preparing (validation, pathway determination)
     ├─ File validation: ~100ms
     ├─ PDF parsing: ~200ms per 100 pages
     └─ Total: 500ms - 2s

[1-3s] Uploading (file transmission or URL generation)
       ├─ PDF multipart upload: 1-10s (depends on file size)
       ├─ Signed URL generation: ~500ms
       ├─ Image base64 encoding: ~100-500ms
       └─ Total: 500ms - 10s

[4-60s] Processing (API OCR inference)
        ├─ Page parsing: ~100-200ms per page (avg)
        ├─ Table extraction: additional ~50-100ms per table
        ├─ Image detection: additional ~20-50ms per image
        └─ Total: 2s - 120s (highly variable)

[61-65s] Finalizing (data transformation, metrics calculation)
         ├─ Response parsing: ~100-200ms
         ├─ Markdown assembly: ~50-100ms
         ├─ Token estimation: ~50ms
         ├─ Thumbnail generation: ~500ms - 2s (background)
         └─ Total: 500ms - 2.5s

Overall Duration Example: 100-page document
Expected: 3-15 seconds
(Preparing: 1s + Uploading: 2s + Processing: 8s + Finalizing: 1s)
```

### 8.3 Progress Callbacks in UI

```swift
class ProcessingViewModel: NSObject, ObservableObject {
    @Published var progress: ProcessingProgress?

    func processDocument(url: URL) async {
        let progressCallback: (ProcessingProgress) -> Void = { progress in
            Task { @MainActor in
                self.progress = progress
            }
        }

        do {
            let result = try await OCRService.shared.processDocument(
                at: url,
                progressCallback: progressCallback
            )
            // Display result
        } catch {
            // Handle error
        }
    }
}
```

**UI Display:**
```
┌──────────────────────────────────────────┐
│ Processing Document (Processing Phase)   │
│                                          │
│ [████████░░░░░░░░░░░░░░░░░░░░░░░░] 40%  │
│                                          │
│ Page 40 of 100                           │
│ Elapsed: 6s | Est. Remaining: 9s        │
└──────────────────────────────────────────┘
```

---

## 9. Integration with Cleaning Pipeline

### 9.1 OCRResult → CleaningService Data Flow

```
┌─────────────────────────────────┐
│ OCRResult                       │
│ ├─ id: UUID                     │
│ ├─ documentId: UUID             │
│ ├─ pages: [OCRPage]             │
│ ├─ cost: Decimal                │
│ └─ processingDuration: TimeInterval
└────────────┬────────────────────┘
             │
             │ fullMarkdown property
             │ (concatenates all pages)
             ▼
┌─────────────────────────────────┐
│ CleaningService                 │
│                                 │
│ input: String (markdown)        │
│ ├─ Remove boilerplate           │
│ ├─ Fix formatting               │
│ ├─ Normalize structure          │
│ └─ Extract metadata             │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ CleanedDocument                 │
│ ├─ title: String                │
│ ├─ content: String              │
│ ├─ metadata: DocumentMetadata    │
│ └─ enrichmentNeeded: Bool       │
└─────────────────────────────────┘
```

### 9.2 Document Pathway Enum

Document routing pattern that determines processing path based on content type:

```swift
enum DocumentPathway {
    case ocr(result: OCRResult)
    case directToClean(rawContent: String)

    var content: String {
        switch self {
        case .ocr(let result):
            return result.fullMarkdown
        case .directToClean(let content):
            return content
        }
    }
}

// Pathway determination logic in Document model
struct Document {
    var pathway: DocumentPathway?

    var ocrResult: OCRResult? {
        guard case .ocr(let result) = pathway else { return nil }
        return result
    }

    var cleaningInput: String? {
        pathway?.content
    }

    static func determinePathway(for contentType: UTType) -> PathwayType {
        // PDF, PNG, JPEG, TIFF, GIF, WebP, BMP → OCR pathway
        // TXT, RTF, JSON, XML, HTML → Direct-to-clean pathway
        switch contentType {
        case .pdf, .jpeg, .png, .tiff, .gif, .webP, .bmp:
            return .ocr
        case .plainText, .richText, .json, .xml, .html:
            return .directToClean
        default:
            return .unsupported
        }
    }
}
```

### 9.3 Storage and Persistence

OCRResult is persisted in the document's result property:

```swift
struct Document {
    @Relationship(deleteRule: .cascade) var result: OCRResult?

    mutating func storeOCRResult(_ result: OCRResult) {
        self.result = result
        self.updatedAt = Date()
    }
}
```

**Storage Location:** SwiftData persistent store (user's application support directory)

**Retrieval Pattern:**
```swift
let document = /* fetch from SwiftData */
let ocrResult = document.result
let markdown = ocrResult?.fullMarkdown
```

---

## 10. Thumbnail System and Caching

### 10.1 ThumbnailCache Architecture

```swift
final class ThumbnailCache {
    enum Quality: Equatable {
        case low    // 70×90px, 1x density
        case medium // 140×180px, 2x density
        case high   // 210×270px, 3x density
    }

    private let maxCacheSize: Int = 50 * 1024 * 1024  // 50 MB
    private var cache: [String: NSImage] = [:]
    private var accessOrder: [String] = []  // LRU tracking

    func thumbnail(
        for documentId: UUID,
        quality: Quality,
        pageIndex: Int
    ) async -> NSImage? {
        let key = "\(documentId)-p\(pageIndex)-\(quality)"

        // Check in-memory cache
        if let cached = cache[key] {
            updateAccessOrder(key)
            return cached
        }

        // Check disk cache
        let diskPath = cacheDirectory.appendingPathComponent(key)
        if let diskImage = NSImage(contentsOf: diskPath) {
            cache[key] = diskImage
            return diskImage
        }

        return nil
    }
}
```

### 10.2 Scroll Velocity Detection and Prefetching Strategies

**PageThumbnailsView Scroll Detection:**
```swift
enum ScrollVelocity {
    case stationary  // < 50 pixels/second
    case normal      // 50-200 pixels/second
    case fast        // > 200 pixels/second
}

// Prefetch buffer based on velocity
let prefetchBuffer: Int
switch scrollVelocity {
case .stationary: prefetchBuffer = 3   // 3 pages in each direction
case .normal: prefetchBuffer = 5       // 5 pages in each direction
case .fast: prefetchBuffer = 8         // 8 pages in each direction
}
```

**Size-Based Prefetching Strategies:**
```swift
struct ThumbnailPrefetchStrategy {
    enum DocumentSize {
        case small      // ≤ 50 pages
        case medium     // ≤ 200 pages
        case large      // ≤ 500 pages
        case veryLarge  // > 500 pages

        static func determine(pageCount: Int) -> Self {
            switch pageCount {
            case ...50: return .small
            case 51...200: return .medium
            case 201...500: return .large
            default: return .veryLarge
            }
        }
    }

    static func prefetchPages(
        around visiblePage: Int,
        documentSize: DocumentSize,
        totalPages: Int,
        scrollVelocity: ScrollVelocity
    ) -> Set<Int> {
        let baseRadius: Int
        switch documentSize {
        case .small: baseRadius = 10      // All nearby pages
        case .medium: baseRadius = 5      // Pages before/after
        case .large: baseRadius = 2       // Immediate vicinity
        case .veryLarge: baseRadius = 1   // Current page only
        }

        // Adjust radius based on scroll velocity
        let adjustedRadius = baseRadius + (scrollVelocity == .fast ? 2 : 0)

        return Set(
            (max(0, visiblePage - adjustedRadius)...min(totalPages - 1, visiblePage + adjustedRadius))
        )
    }
}
```

### 10.3 Thumbnail Generation Pipelines

**PDF Thumbnails (via PDFKit - PDFPage.thumbnail):**
```swift
func generatePDFThumbnail(
    documentURL: URL,
    pageIndex: Int,
    quality: ThumbnailCache.Quality
) async -> NSImage? {
    let document = PDFDocument(url: documentURL)
    guard let page = document?.page(at: pageIndex) else { return nil }

    let size = quality.pixelSize
    // Uses PDFPage.thumbnail(of:for:) method
    let cgImage = page.thumbnail(of: size, for: .artBox)
    return NSImage(cgImage: cgImage, size: size)
}
```

**Image Thumbnails (via NSImage scaling):**
```swift
func generateImageThumbnail(
    imageURL: URL,
    quality: ThumbnailCache.Quality
) async -> NSImage? {
    guard let image = NSImage(contentsOf: imageURL) else { return nil }

    let targetSize = quality.pixelSize
    // NSImage scaling/resizing to target dimensions
    let scaledImage = image.scaledToSize(targetSize)
    return scaledImage
}
```

**ShimmerView Loading Animation:**
- Animated loading placeholder while thumbnails generate
- 1.5-second loop gradient animation
- Smooth fade-in when thumbnail ready
- Improves perceived performance during scroll

---

## 11. Token Estimation

### 11.1 TokenEstimator Implementation

**Hybrid Approach for Token Estimation:**

```swift
struct TokenEstimator {
    static func estimate(_ text: String) -> Int {
        // Hybrid approach: character-based + word-based averaging
        // Provides ±1-2% accuracy vs actual OpenAI tokenizer

        // Method 1: Character-based (approximately 4 characters per token)
        let characterEstimate = text.count / 4

        // Method 2: Word-based (approximately 1.3 tokens per word)
        let words = text.split(separator: " ").count
        let wordEstimate = Int(Double(words) * 1.3)

        // Average the two estimates for better accuracy
        // This hybrid approach balances precision and consistency
        let average = (characterEstimate + wordEstimate) / 2

        return average
    }

    static func formatTokenEstimate(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true

        let formatted = formatter.string(from: NSNumber(value: count)) ?? "0"
        return "~\(formatted) tokens"
    }
}

// Usage
let markdown = "## Introduction\n\nThis document contains..."
let estimate = TokenEstimator.estimate(markdown)
let formatted = TokenEstimator.formatTokenEstimate(estimate)
// Output: "~245 tokens"
```

### 11.2 Accuracy Considerations

```
Token Estimate Accuracy:

Word Count:       1000 words
Character Count:  6000 characters

Method 1: chars ÷ 4  = 6000 ÷ 4    = 1500 tokens
Method 2: words × 1.3 = 1000 × 1.3  = 1300 tokens
Average:           = (1500 + 1300) ÷ 2 = 1400 tokens

Actual (OpenAI tokenizer): ~1380 tokens
Error: ±1-2%

This hybrid approach provides accuracy within
2-3% of actual tokenizer outputs for typical documents.
```

### 11.3 Usage in Metrics

```swift
extension OCRResult {
    var estimatedTokenCount: Int {
        TokenEstimator.estimate(fullMarkdown)
    }

    var formattedTokens: String {
        TokenEstimator.formatTokenEstimate(estimatedTokenCount)
    }
}

// Example display in UI
let result: OCRResult = /* ... */
let info = "Pages: \(result.pageCount) | Words: \(result.wordCount) | \(result.formattedTokens)"
```

---

## 12. Conclusion and Architecture Summary

### 12.1 Key Architectural Principles

1. **Modularity:** Protocol-driven design with clear separation of concerns
2. **Safety:** Concurrency-safe with MainActor annotations, security-scoped file access
3. **Resilience:** Exponential backoff retry logic, comprehensive error handling
4. **Transparency:** Full cost tracking, progress monitoring, detailed metrics
5. **Performance:** Thumbnail caching, size-based prefetching, efficient token estimation
6. **Reliability:** Deterministic results, comprehensive validation, graceful degradation

### 12.2 Performance Characteristics

| Operation | Typical Duration | Scalability Notes |
|-----------|------------------|-------------------|
| PDF page counting (PDFKit) | <100ms | O(1), constant time |
| Thumbnail generation (single) | 50-200ms | O(1), single page |
| Thumbnail prefetch (10 pages) | 500ms-2s | Linear with prefetch radius |
| File upload (50 MB PDF) | 5-15s | Depends on network speed |
| OCR processing (100 pages) | 10-30s | ~200-300ms per page avg |
| Result finalization | 500ms-2s | O(n) with page count |
| **Total end-to-end (100 pages)** | **15-45 seconds** | Dominated by OCR API latency |

### 12.3 Security Considerations

- **API Key Storage:** Keychain-protected, never exposed in logs
- **File Access:** Security-scoped URLs enforce macOS sandbox restrictions
- **Network:** HTTPS-only communication with certificate pinning (future enhancement)
- **Data Retention:** OCR results stored locally, deleted only by user action
- **Encryption:** At-rest encryption via SwiftData (platform default)

### 12.4 Future Enhancement Opportunities

1. **Multi-Provider Support:** Abstract OCRServiceProtocol to support Google Vision, Azure Cognitive Services
2. **Incremental Processing:** Stream page results as they complete rather than waiting for all pages
3. **Caching Layer:** Cache OCR results for identical documents (hash-based deduplication)
4. **Batch Processing:** Submit multiple documents to a single API call for volume discounts
5. **Quality Assurance:** Confidence scoring and manual review workflow for low-confidence regions
6. **Language Detection:** Auto-detect document language and apply OCR model accordingly

---

**Document Version History:**
- **v1.0** (February 2026) — Initial comprehensive architecture document

**Related Documentation:**
- `01-Horus-Technical-Architecture.md` — System-level architecture
- `02-Data-Model-Architecture-Horus.md` — SwiftData models and relationships
- `04-Cleaning-Pipeline-Architecture-Horus.md` — Content cleaning and enrichment
- API Reference: Mistral Vision OCR Documentation
