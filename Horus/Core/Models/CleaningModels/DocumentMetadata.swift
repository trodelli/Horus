//
//  DocumentMetadata.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//
//  Metadata extracted from a document by Claude during Step 1.
//  Contains bibliographic information and content type characteristics.
//
//  Document History:
//  - 2026-01-22: Initial creation with core bibliographic fields
//  - 2026-01-27: V2 Expansion — Added fields for enhanced metadata extraction
//    • Added subtitle, translator, editor fields
//    • Added originalDate, originalLanguage, originalTitle for translations
//    • Added seriesNumber for series tracking
//    • Integrated ContentTypeFlags for content type detection
//    • Added Step 14 output fields (chaptersDetected, hasParts)
//    • Updated formatting methods to render new fields
//

import Foundation

// MARK: - DocumentMetadata

/// Metadata extracted from a document by Claude.
///
/// Contains bibliographic information parsed from front matter during Step 1,
/// plus content type characteristics that inform downstream processing.
///
/// **Core Fields** (from original implementation):
/// - title, author, publisher, publishDate, isbn, language, genre, series, edition
///
/// **V2 Enhanced Fields**:
/// - subtitle, translator, editor (for translations and edited volumes)
/// - originalDate, originalLanguage, originalTitle (for translated works)
/// - seriesNumber (for series tracking)
/// - contentType (content type flags for downstream steps)
///
/// **Step 14 Output Fields**:
/// - chaptersDetected, chapterMarkerStyle, hasParts (set during structure step)
struct DocumentMetadata: Codable, Equatable, Sendable {
    
    // MARK: - Core Bibliographic Fields
    
    /// Document title (required).
    var title: String
    
    /// Document subtitle (e.g., "A Novel", "Volume 2").
    var subtitle: String?
    
    /// Author name(s).
    var author: String?
    
    /// Translator name(s) for translated works.
    var translator: String?
    
    /// Editor name(s) for edited volumes or anthologies.
    var editor: String?
    
    /// Publisher name.
    var publisher: String?
    
    /// Publication date or year of this edition.
    var publishDate: String?
    
    /// ISBN (if found).
    var isbn: String?
    
    /// Language of the text.
    var language: String?
    
    /// Genre/category (Claude-inferred).
    var genre: String?
    
    /// Series name (if part of a series).
    var series: String?
    
    /// Series number or volume (e.g., "Book 3", "Vol. 2").
    var seriesNumber: String?
    
    /// Edition information (e.g., "2nd Edition", "Revised").
    var edition: String?
    
    // MARK: - Translation Fields
    
    /// Original publication date (for translations).
    var originalDate: String?
    
    /// Original language (for translations).
    var originalLanguage: String?
    
    /// Original title (for translations).
    var originalTitle: String?
    
    // MARK: - Content Type Detection 
    
    /// Content type flags detected during Step 1.
    /// Informs behavior of downstream steps (reflow, optimization, etc.).
    var contentType: ContentTypeFlags?
    
    // MARK: - Step 14 Output Fields
    
    /// Number of chapters detected during Step 14.
    var chaptersDetected: Int?
    
    /// Chapter marker style used in output.
    var chapterMarkerStyle: String?
    
    /// Whether document has parts (Part I, Part II, etc.).
    var hasParts: Bool?
    
    // MARK: - Initialization
    
    init(
        title: String,
        subtitle: String? = nil,
        author: String? = nil,
        translator: String? = nil,
        editor: String? = nil,
        publisher: String? = nil,
        publishDate: String? = nil,
        isbn: String? = nil,
        language: String? = nil,
        genre: String? = nil,
        series: String? = nil,
        seriesNumber: String? = nil,
        edition: String? = nil,
        originalDate: String? = nil,
        originalLanguage: String? = nil,
        originalTitle: String? = nil,
        contentType: ContentTypeFlags? = nil,
        chaptersDetected: Int? = nil,
        chapterMarkerStyle: String? = nil,
        hasParts: Bool? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.author = author
        self.translator = translator
        self.editor = editor
        self.publisher = publisher
        self.publishDate = publishDate
        self.isbn = isbn
        self.language = language
        self.genre = genre
        self.series = series
        self.seriesNumber = seriesNumber
        self.edition = edition
        self.originalDate = originalDate
        self.originalLanguage = originalLanguage
        self.originalTitle = originalTitle
        self.contentType = contentType
        self.chaptersDetected = chaptersDetected
        self.chapterMarkerStyle = chapterMarkerStyle
        self.hasParts = hasParts
    }
    
    // MARK: - Formatting
    
    /// Format metadata according to specified format.
    func format(as format: MetadataFormat) -> String {
        switch format {
        case .yaml: return toYAML()
        case .json: return toJSON()
        case .markdown: return toMarkdown()
        }
    }
    
    /// Generate YAML representation.
    /// Field order follows logical grouping: title → authorship → publication → original work.
    func toYAML() -> String {
        var lines: [String] = ["---"]
        
        // Title block
        lines.append("title: \(escapeYAMLValue(title))")
        if let subtitle = subtitle, !subtitle.isEmpty {
            lines.append("subtitle: \(escapeYAMLValue(subtitle))")
        }
        
        // Authorship block
        if let author = author, !author.isEmpty {
            lines.append("author: \(escapeYAMLValue(author))")
        }
        if let translator = translator, !translator.isEmpty {
            lines.append("translator: \(escapeYAMLValue(translator))")
        }
        if let editor = editor, !editor.isEmpty {
            lines.append("editor: \(escapeYAMLValue(editor))")
        }
        
        // Series block
        if let series = series, !series.isEmpty {
            lines.append("series: \(escapeYAMLValue(series))")
            if let seriesNumber = seriesNumber, !seriesNumber.isEmpty {
                lines.append("series_number: \(escapeYAMLValue(seriesNumber))")
            }
        }
        
        // Publication block
        if let publisher = publisher, !publisher.isEmpty {
            lines.append("publisher: \(escapeYAMLValue(publisher))")
        }
        if let publishDate = publishDate, !publishDate.isEmpty {
            lines.append("publish_date: \(escapeYAMLValue(publishDate))")
        }
        if let edition = edition, !edition.isEmpty {
            lines.append("edition: \(escapeYAMLValue(edition))")
        }
        if let isbn = isbn, !isbn.isEmpty {
            lines.append("isbn: \(escapeYAMLValue(isbn))")
        }
        
        // Original work block (for translations)
        if isTranslation {
            if let originalTitle = originalTitle, !originalTitle.isEmpty {
                lines.append("original_title: \(escapeYAMLValue(originalTitle))")
            }
            if let originalLanguage = originalLanguage, !originalLanguage.isEmpty {
                lines.append("original_language: \(escapeYAMLValue(originalLanguage))")
            }
            if let originalDate = originalDate, !originalDate.isEmpty {
                lines.append("original_date: \(escapeYAMLValue(originalDate))")
            }
        }
        
        // Classification block
        if let language = language, !language.isEmpty {
            lines.append("language: \(escapeYAMLValue(language))")
        }
        if let genre = genre, !genre.isEmpty {
            lines.append("genre: \(escapeYAMLValue(genre))")
        }
        
        // Content type (if detected)
        if let contentType = contentType, contentType.hasSpecialContent {
            lines.append("content_type: \(contentType.primaryType.rawValue)")
        }
        
        // Structure info (if chapters detected)
        if let chapters = chaptersDetected, chapters > 0 {
            lines.append("chapters: \(chapters)")
        }
        if let hasParts = hasParts, hasParts {
            lines.append("has_parts: true")
        }
        
        lines.append("---")
        return lines.joined(separator: "\n")
    }
    
    /// Generate JSON representation.
    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // Create a dictionary with only non-nil, non-empty values
        var dict: [String: Any] = ["title": title]
        
        // Add optional string fields
        if let subtitle = subtitle, !subtitle.isEmpty { dict["subtitle"] = subtitle }
        if let author = author, !author.isEmpty { dict["author"] = author }
        if let translator = translator, !translator.isEmpty { dict["translator"] = translator }
        if let editor = editor, !editor.isEmpty { dict["editor"] = editor }
        if let publisher = publisher, !publisher.isEmpty { dict["publisher"] = publisher }
        if let publishDate = publishDate, !publishDate.isEmpty { dict["publish_date"] = publishDate }
        if let isbn = isbn, !isbn.isEmpty { dict["isbn"] = isbn }
        if let language = language, !language.isEmpty { dict["language"] = language }
        if let genre = genre, !genre.isEmpty { dict["genre"] = genre }
        if let series = series, !series.isEmpty { dict["series"] = series }
        if let seriesNumber = seriesNumber, !seriesNumber.isEmpty { dict["series_number"] = seriesNumber }
        if let edition = edition, !edition.isEmpty { dict["edition"] = edition }
        if let originalTitle = originalTitle, !originalTitle.isEmpty { dict["original_title"] = originalTitle }
        if let originalLanguage = originalLanguage, !originalLanguage.isEmpty { dict["original_language"] = originalLanguage }
        if let originalDate = originalDate, !originalDate.isEmpty { dict["original_date"] = originalDate }
        if let contentType = contentType, contentType.hasSpecialContent {
            dict["content_type"] = contentType.primaryType.rawValue
        }
        if let chapters = chaptersDetected, chapters > 0 { dict["chapters"] = chapters }
        if let hasParts = hasParts, hasParts { dict["has_parts"] = hasParts }
        
        // Manual JSON formatting for mixed types
        var jsonLines: [String] = ["{"]
        let sortedKeys = dict.keys.sorted()
        for (index, key) in sortedKeys.enumerated() {
            let value = dict[key]!
            let valueString: String
            if let stringValue = value as? String {
                valueString = "\"\(escapeJSONString(stringValue))\""
            } else if let intValue = value as? Int {
                valueString = "\(intValue)"
            } else if let boolValue = value as? Bool {
                valueString = boolValue ? "true" : "false"
            } else {
                valueString = "\"\(value)\""
            }
            let comma = index < sortedKeys.count - 1 ? "," : ""
            jsonLines.append("  \"\(key)\": \(valueString)\(comma)")
        }
        jsonLines.append("}")
        
        return jsonLines.joined(separator: "\n")
    }
    
    /// Generate Markdown representation.
    func toMarkdown() -> String {
        var lines: [String] = []
        
        lines.append("**Title:** \(title)")
        
        if let subtitle = subtitle, !subtitle.isEmpty {
            lines.append("**Subtitle:** \(subtitle)")
        }
        if let author = author, !author.isEmpty {
            lines.append("**Author:** \(author)")
        }
        if let translator = translator, !translator.isEmpty {
            lines.append("**Translator:** \(translator)")
        }
        if let editor = editor, !editor.isEmpty {
            lines.append("**Editor:** \(editor)")
        }
        if let publisher = publisher, !publisher.isEmpty {
            lines.append("**Publisher:** \(publisher)")
        }
        if let publishDate = publishDate, !publishDate.isEmpty {
            lines.append("**Published:** \(publishDate)")
        }
        if let genre = genre, !genre.isEmpty {
            lines.append("**Genre:** \(genre)")
        }
        if let series = series, !series.isEmpty {
            var seriesText = series
            if let number = seriesNumber, !number.isEmpty {
                seriesText += " #\(number)"
            }
            lines.append("**Series:** \(seriesText)")
        }
        if let edition = edition, !edition.isEmpty {
            lines.append("**Edition:** \(edition)")
        }
        if let isbn = isbn, !isbn.isEmpty {
            lines.append("**ISBN:** \(isbn)")
        }
        
        // Original work info for translations
        if isTranslation {
            lines.append("")
            lines.append("*Originally published as:*")
            if let originalTitle = originalTitle, !originalTitle.isEmpty {
                lines.append("**Original Title:** \(originalTitle)")
            }
            if let originalLanguage = originalLanguage, !originalLanguage.isEmpty {
                lines.append("**Original Language:** \(originalLanguage)")
            }
            if let originalDate = originalDate, !originalDate.isEmpty {
                lines.append("**Original Date:** \(originalDate)")
            }
        }
        
        return lines.joined(separator: "  \n")
    }
    
    // MARK: - Header Generation
    
    /// Generate the title header line.
    /// - Parameters:
    ///   - includeSubtitle: Whether to include subtitle (default: true)
    ///   - includeDate: Whether to include publication date (default: false)
    ///   - uppercase: Whether to uppercase the title (default: true)
    func generateTitleHeader(
        includeSubtitle: Bool = true,
        includeDate: Bool = false,
        uppercase: Bool = true
    ) -> String {
        var titlePart = uppercase ? title.uppercased() : title
        
        // Add subtitle if present and requested
        if includeSubtitle, let subtitle = subtitle, !subtitle.isEmpty {
            let subtitlePart = uppercase ? subtitle.uppercased() : subtitle
            titlePart += ": \(subtitlePart)"
        }
        
        // Build header
        var header = "# \(titlePart)"
        
        // Add author if present
        if let author = author, !author.isEmpty {
            let authorPart = uppercase ? author.uppercased() : author
            header += " (\(authorPart))"
        }
        
        // Add date if requested
        if includeDate, let date = publishDate, !date.isEmpty {
            header += " [\(date)]"
        }
        
        return header
    }
    
    /// Generate the end marker.
    /// - Parameter style: The end marker style to use
    func generateEndMarker(style: EndMarkerStyle = .standard) -> String {
        style.formatMarker(title: title, author: author)
    }
    
    // MARK: - Private Helpers
    
    /// Escape special characters for YAML values.
    private func escapeYAMLValue(_ value: String) -> String {
        // If value contains special characters, quote it
        let needsQuoting = value.contains(":") ||
                          value.contains("#") ||
                          value.contains("'") ||
                          value.contains("\"") ||
                          value.contains("\n") ||
                          value.contains("[") ||
                          value.contains("]") ||
                          value.contains("{") ||
                          value.contains("}") ||
                          value.contains(",") ||
                          value.contains("&") ||
                          value.contains("*") ||
                          value.contains("!") ||
                          value.contains("|") ||
                          value.contains(">") ||
                          value.contains("%") ||
                          value.contains("@") ||
                          value.contains("`") ||
                          value.hasPrefix(" ") ||
                          value.hasSuffix(" ") ||
                          value.hasPrefix("-") ||
                          value.hasPrefix("?")
        
        if needsQuoting {
            // Use double quotes and escape internal double quotes and backslashes
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        
        return value
    }
    
    /// Escape special characters for JSON strings.
    private func escapeJSONString(_ value: String) -> String {
        var result = value
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r")
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        return result
    }
}

// MARK: - DocumentMetadata + Computed Properties

extension DocumentMetadata {
    
    /// Whether this is a translated work.
    var isTranslation: Bool {
        translator != nil ||
        originalLanguage != nil ||
        originalTitle != nil ||
        originalDate != nil
    }
    
    /// Whether this is part of a series.
    var isPartOfSeries: Bool {
        series != nil && !series!.isEmpty
    }
    
    /// Whether this is an edited volume.
    var isEditedVolume: Bool {
        editor != nil && !editor!.isEmpty
    }
    
    /// Whether this metadata has meaningful content beyond title.
    var hasExtendedMetadata: Bool {
        author != nil ||
        publisher != nil ||
        publishDate != nil ||
        isbn != nil ||
        genre != nil ||
        series != nil ||
        translator != nil ||
        editor != nil
    }
    
    /// Whether content type was detected.
    var hasContentTypeDetection: Bool {
        contentType != nil
    }
    
    /// Short description for display.
    var shortDescription: String {
        var parts: [String] = [title]
        if let author = author, !author.isEmpty {
            parts.append("by \(author)")
        }
        if let publishDate = publishDate, !publishDate.isEmpty {
            parts.append("(\(publishDate))")
        }
        return parts.joined(separator: " ")
    }
    
    /// Full title with subtitle if present.
    var fullTitle: String {
        if let subtitle = subtitle, !subtitle.isEmpty {
            return "\(title): \(subtitle)"
        }
        return title
    }
    
    /// Attribution string (author or editor).
    var attribution: String? {
        if let author = author, !author.isEmpty {
            return author
        }
        if let editor = editor, !editor.isEmpty {
            return "\(editor) (Ed.)"
        }
        return nil
    }
}

// MARK: - DocumentMetadata + Convenience

extension DocumentMetadata {
    
    /// Create metadata from a document filename.
    static func fromFilename(_ filename: String) -> DocumentMetadata {
        // Remove extension
        var name = filename
        if let dotIndex = name.lastIndex(of: ".") {
            name = String(name[..<dotIndex])
        }
        
        // Clean up common patterns
        name = name.replacingOccurrences(of: "_", with: " ")
        name = name.replacingOccurrences(of: "-", with: " ")
        
        // Trim whitespace
        name = name.trimmingCharacters(in: .whitespaces)
        
        // Handle empty case
        if name.isEmpty {
            name = "Untitled Document"
        }
        
        return DocumentMetadata(title: name)
    }
    
    /// Create a fallback metadata when extraction fails.
    static func fallback(filename: String? = nil) -> DocumentMetadata {
        if let filename = filename {
            return fromFilename(filename)
        }
        return DocumentMetadata(title: "Untitled Document")
    }
    
    /// Merge with another metadata, preferring non-nil values from other.
    func merging(with other: DocumentMetadata) -> DocumentMetadata {
        DocumentMetadata(
            title: other.title.isEmpty ? title : other.title,
            subtitle: other.subtitle ?? subtitle,
            author: other.author ?? author,
            translator: other.translator ?? translator,
            editor: other.editor ?? editor,
            publisher: other.publisher ?? publisher,
            publishDate: other.publishDate ?? publishDate,
            isbn: other.isbn ?? isbn,
            language: other.language ?? language,
            genre: other.genre ?? genre,
            series: other.series ?? series,
            seriesNumber: other.seriesNumber ?? seriesNumber,
            edition: other.edition ?? edition,
            originalDate: other.originalDate ?? originalDate,
            originalLanguage: other.originalLanguage ?? originalLanguage,
            originalTitle: other.originalTitle ?? originalTitle,
            contentType: other.contentType ?? contentType,
            chaptersDetected: other.chaptersDetected ?? chaptersDetected,
            chapterMarkerStyle: other.chapterMarkerStyle ?? chapterMarkerStyle,
            hasParts: other.hasParts ?? hasParts
        )
    }
}

// MARK: - CodingKeys

extension DocumentMetadata {
    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case author
        case translator
        case editor
        case publisher
        case publishDate = "publish_date"
        case isbn
        case language
        case genre
        case series
        case seriesNumber = "series_number"
        case edition
        case originalDate = "original_date"
        case originalLanguage = "original_language"
        case originalTitle = "original_title"
        case contentType = "content_type"
        case chaptersDetected = "chapters_detected"
        case chapterMarkerStyle = "chapter_marker_style"
        case hasParts = "has_parts"
    }
}
