//
//  OCRAPIModels.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation

// MARK: - Request Models

/// Request body for Mistral OCR API
struct OCRAPIRequest: Encodable {
    let model: String
    let document: DocumentPayload
    let includeImageBase64: Bool?
    let tableFormat: String?
    let extractHeader: Bool?
    let extractFooter: Bool?
    
    enum CodingKeys: String, CodingKey {
        case model
        case document
        case includeImageBase64 = "include_image_base64"
        case tableFormat = "table_format"
        case extractHeader = "extract_header"
        case extractFooter = "extract_footer"
    }
    
    /// Create a request with default settings
    init(
        model: String = "mistral-ocr-latest",
        document: DocumentPayload,
        includeImageBase64: Bool? = nil,
        tableFormat: String? = nil,
        extractHeader: Bool? = nil,
        extractFooter: Bool? = nil
    ) {
        self.model = model
        self.document = document
        self.includeImageBase64 = includeImageBase64
        self.tableFormat = tableFormat
        self.extractHeader = extractHeader
        self.extractFooter = extractFooter
    }
    
    /// Custom encoding to skip nil values (API doesn't like null)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(model, forKey: .model)
        try container.encode(document, forKey: .document)
        
        // Only encode optional fields if they have values
        if let includeImageBase64 = includeImageBase64 {
            try container.encode(includeImageBase64, forKey: .includeImageBase64)
        }
        if let tableFormat = tableFormat {
            try container.encode(tableFormat, forKey: .tableFormat)
        }
        if let extractHeader = extractHeader {
            try container.encode(extractHeader, forKey: .extractHeader)
        }
        if let extractFooter = extractFooter {
            try container.encode(extractFooter, forKey: .extractFooter)
        }
    }
}

/// Document payload - supports multiple input types
/// According to Mistral API documentation:
/// - PDFs: Use document_url with a signed URL (must upload file first)
/// - Images: Use image_url with either a URL or data URL (data:image/jpeg;base64,...)
enum DocumentPayload: Encodable {
    /// PDF document via URL (must be a signed URL from file upload)
    case documentURL(url: String)
    
    /// Image via URL or data URL (supports data:image/xxx;base64,...)
    case imageURL(url: String)
    
    /// PDF document via file ID (pre-uploaded)
    case fileID(id: String)
    
    enum CodingKeys: String, CodingKey {
        case type
        case documentUrl = "document_url"
        case imageUrl = "image_url"
        case fileId = "file_id"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .documentURL(let url):
            try container.encode("document_url", forKey: .type)
            try container.encode(url, forKey: .documentUrl)
            
        case .imageURL(let url):
            try container.encode("image_url", forKey: .type)
            try container.encode(url, forKey: .imageUrl)
            
        case .fileID(let id):
            try container.encode("file_id", forKey: .type)
            try container.encode(id, forKey: .fileId)
        }
    }
}

// MARK: - Response Models

/// Response from Mistral OCR API
struct OCRAPIResponse: Decodable {
    let pages: [APIPageResult]
    let model: String
    let usageInfo: UsageInfo
    
    enum CodingKeys: String, CodingKey {
        case pages
        case model
        case usageInfo = "usage_info"
    }
}

/// Single page result from API
struct APIPageResult: Decodable {
    let index: Int
    let markdown: String
    let images: [APIImage]?
    let tables: [APITable]?
    let hyperlinks: [APIHyperlink]?
    let dimensions: APIDimensions?
    let header: String?
    let footer: String?
}

/// Image data from API
struct APIImage: Decodable {
    let id: String
    let topLeftX: Int
    let topLeftY: Int
    let bottomRightX: Int
    let bottomRightY: Int
    let imageBase64: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case topLeftX = "top_left_x"
        case topLeftY = "top_left_y"
        case bottomRightX = "bottom_right_x"
        case bottomRightY = "bottom_right_y"
        case imageBase64 = "image_base64"
    }
}

/// Table data from API
struct APITable: Decodable {
    let id: String
    let markdown: String?
    let html: String?
}

/// Hyperlink data from API
struct APIHyperlink: Decodable {
    let text: String?
    let url: String
}

/// Page dimensions from API
struct APIDimensions: Decodable {
    let width: Int
    let height: Int
    let dpi: Int?
}

/// Usage information for billing
struct UsageInfo: Decodable {
    let pagesProcessed: Int
    let docSizeBytes: Int?
    
    enum CodingKeys: String, CodingKey {
        case pagesProcessed = "pages_processed"
        case docSizeBytes = "doc_size_bytes"
    }
}

// MARK: - Error Response

/// Error response from Mistral API
struct APIErrorResponse: Decodable {
    let message: String?
    let requestId: String?
    let object: String?
    let type: String?
    let param: String?
    let code: String?
    let detail: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case requestId = "request_id"
        case object
        case type
        case param
        case code
        case detail
    }
    
    /// Get the best available error message
    var errorMessage: String {
        message ?? detail ?? "Unknown error"
    }
}

// MARK: - Processing Settings

/// Settings for OCR processing
struct ProcessingSettings: Equatable {
    /// Whether to include base64 image data in results
    var includeImages: Bool
    
    /// Table extraction format
    var tableFormat: TableFormatPreference
    
    /// Whether to extract headers separately
    var extractHeader: Bool
    
    /// Whether to extract footers separately
    var extractFooter: Bool
    
    /// Default settings for standard processing
    static let `default` = ProcessingSettings(
        includeImages: false,
        tableFormat: .markdown,
        extractHeader: false,
        extractFooter: false
    )
    
    /// Settings optimized for LLM training data
    static let forTraining = ProcessingSettings(
        includeImages: false,
        tableFormat: .markdown,
        extractHeader: false,
        extractFooter: false
    )
    
    /// Settings for full document export with images
    static let fullExport = ProcessingSettings(
        includeImages: true,
        tableFormat: .markdown,
        extractHeader: true,
        extractFooter: true
    )
    
    /// Convert to API parameter value for table_format
    var tableFormatAPIValue: String? {
        tableFormat.apiValue
    }
}
