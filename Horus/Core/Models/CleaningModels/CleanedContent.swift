//
//  CleanedContent.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//
//  Result of the cleaning pipeline.
//  Contains the cleaned content and metadata about the cleaning operation.
//
//  Document History:
//  - 2026-01-22: Initial creation with core tracking fields
//  - 2026-01-27: V2 Expansion — Added tracking for new steps
//    • Added auxiliary list removal statistics (Step 4)
//    • Added citation removal statistics (Step 9)
//    • Added footnote removal statistics (Step 10)
//    • Added chapter detection statistics (Step 14)
//    • Added content type detection tracking
//    • Updated cost calculations for expanded pipeline
//  - 2026-01-29: Word Count Accuracy Fix — Industry-standard reduction metrics
//    • wordCount now uses normalizedForCounting (strips markdown formatting only)
//    • cleanedPlainText preserved for export (still removes metadata/markers)
//    • Ensures apples-to-apples comparison with originalWordCount
//    • Fixes bug where reduction % showed ~50% for metadata-only cleaning
//

import Foundation

// MARK: - CleanedContent

/// Result of the cleaning pipeline.
///
/// Contains the cleaned content and comprehensive metadata about the
/// cleaning operation including statistics, costs, and configuration used.
///
/// **V2 Additions:**
/// - Tracking for auxiliary lists removed (Step 4)
/// - Tracking for citations removed (Step 9)
/// - Tracking for footnotes/endnotes removed (Step 10)
/// - Chapter detection statistics (Step 14)
/// - Content type flags from Step 1
struct CleanedContent: Codable, Equatable, Identifiable, Sendable {
    
    // MARK: - Identity
    
    /// Unique identifier.
    let id: UUID
    
    /// The document this cleaning belongs to.
    let documentId: UUID
    
    /// The OCR result ID that was cleaned.
    let ocrResultId: UUID
    
    // MARK: - Content
    
    /// Extracted metadata.
    let metadata: DocumentMetadata
    
    /// Cleaned markdown content.
    let cleanedMarkdown: String
    
    // MARK: - Configuration
    
    /// Configuration used for cleaning.
    let configuration: CleaningConfiguration
    
    /// Patterns that were detected and applied.
    let detectedPatterns: DetectedPatterns
    
    // MARK: - Timing
    
    /// When cleaning started.
    let startedAt: Date
    
    /// When cleaning completed.
    let completedAt: Date
    
    // MARK: - API Usage
    
    /// Number of Claude API calls made.
    let apiCallCount: Int
    
    /// Total tokens used (input + output).
    let tokensUsed: Int
    
    /// Input tokens used (for cost calculation).
    let inputTokens: Int
    
    /// Output tokens used (for cost calculation).
    let outputTokens: Int
    
    // MARK: - Step Execution
    
    /// Steps that were executed.
    let executedSteps: [CleaningStep]
    
    /// Original word count (before cleaning).
    let originalWordCount: Int
    
    // MARK: - Statistics: Auxiliary Lists (Step 4)
    
    /// Number of auxiliary lists removed.
    var auxiliaryListsRemoved: Int?
    
    /// Types of auxiliary lists that were removed.
    var auxiliaryListTypesRemoved: [AuxiliaryListType]?
    
    /// Lines removed by auxiliary list removal.
    var auxiliaryListLinesRemoved: Int?
    
    // MARK: - Statistics: Citations (Step 9)
    
    /// Number of citations removed.
    var citationsRemoved: Int?
    
    /// Citation style that was detected and removed.
    var citationStyleRemoved: CitationStyle?
    
    /// Characters removed by citation removal.
    var citationCharactersRemoved: Int?
    
    // MARK: - Statistics: Footnotes (Step 10)
    
    /// Number of footnote markers removed.
    var footnoteMarkersRemoved: Int?
    
    /// Number of footnote/endnote sections removed.
    var footnoteSectionsRemoved: Int?
    
    /// Lines removed by footnote section removal.
    var footnoteLinesRemoved: Int?
    
    /// Footnote marker style that was detected.
    var footnoteMarkerStyleRemoved: FootnoteMarkerStyle?
    
    // MARK: - Statistics: Chapters (Step 14)
    
    /// Number of chapters detected.
    var chaptersDetected: Int?
    
    /// Whether document has parts.
    var hasParts: Bool?
    
    /// Chapter marker style used.
    var chapterMarkerStyleUsed: ChapterMarkerStyle?
    
    // MARK: - Statistics: Content Type
    
    /// Content type flags detected in Step 1.
    var contentTypeFlags: ContentTypeFlags?
    
    // MARK: - Audit Data (for Export Report)
    
    /// Preset applied by user (e.g. "Aggressive", "Academic").
    var appliedPreset: String?
    
    /// Content type selection by user (nil = Auto-detect).
    var userContentType: String?
    
    /// Per-phase execution results with status and confidence.
    var phaseResults: [PhaseResult]?
    
    /// Quality issues detected during final review.
    var qualityIssues: [QualityIssue]?
    
    /// Pipeline warnings from execution.
    var pipelineWarnings: [String]?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        documentId: UUID,
        ocrResultId: UUID,
        metadata: DocumentMetadata,
        cleanedMarkdown: String,
        configuration: CleaningConfiguration,
        detectedPatterns: DetectedPatterns,
        startedAt: Date,
        completedAt: Date = Date(),
        apiCallCount: Int,
        tokensUsed: Int,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        executedSteps: [CleaningStep],
        originalWordCount: Int,
        auxiliaryListsRemoved: Int? = nil,
        auxiliaryListTypesRemoved: [AuxiliaryListType]? = nil,
        auxiliaryListLinesRemoved: Int? = nil,
        citationsRemoved: Int? = nil,
        citationStyleRemoved: CitationStyle? = nil,
        citationCharactersRemoved: Int? = nil,
        footnoteMarkersRemoved: Int? = nil,
        footnoteSectionsRemoved: Int? = nil,
        footnoteLinesRemoved: Int? = nil,
        footnoteMarkerStyleRemoved: FootnoteMarkerStyle? = nil,
        chaptersDetected: Int? = nil,
        hasParts: Bool? = nil,
        chapterMarkerStyleUsed: ChapterMarkerStyle? = nil,
        contentTypeFlags: ContentTypeFlags? = nil,
        appliedPreset: String? = nil,
        userContentType: String? = nil,
        phaseResults: [PhaseResult]? = nil,
        qualityIssues: [QualityIssue]? = nil,
        pipelineWarnings: [String]? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.ocrResultId = ocrResultId
        self.metadata = metadata
        self.cleanedMarkdown = cleanedMarkdown
        self.configuration = configuration
        self.detectedPatterns = detectedPatterns
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.apiCallCount = apiCallCount
        self.tokensUsed = tokensUsed
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.executedSteps = executedSteps
        self.originalWordCount = originalWordCount
        self.auxiliaryListsRemoved = auxiliaryListsRemoved
        self.auxiliaryListTypesRemoved = auxiliaryListTypesRemoved
        self.auxiliaryListLinesRemoved = auxiliaryListLinesRemoved
        self.citationsRemoved = citationsRemoved
        self.citationStyleRemoved = citationStyleRemoved
        self.citationCharactersRemoved = citationCharactersRemoved
        self.footnoteMarkersRemoved = footnoteMarkersRemoved
        self.footnoteSectionsRemoved = footnoteSectionsRemoved
        self.footnoteLinesRemoved = footnoteLinesRemoved
        self.footnoteMarkerStyleRemoved = footnoteMarkerStyleRemoved
        self.chaptersDetected = chaptersDetected
        self.hasParts = hasParts
        self.chapterMarkerStyleUsed = chapterMarkerStyleUsed
        self.contentTypeFlags = contentTypeFlags
        self.appliedPreset = appliedPreset
        self.userContentType = userContentType
        self.phaseResults = phaseResults
        self.qualityIssues = qualityIssues
        self.pipelineWarnings = pipelineWarnings
    }
    
    // MARK: - Computed Properties: Content
    
    /// Cleaned plain text (markdown formatting stripped).
    var cleanedPlainText: String {
        var text = cleanedMarkdown
        
        // Remove headers
        text = text.replacingOccurrences(
            of: #"^#{1,6}\s+"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove bold
        text = text.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove italics
        text = text.replacingOccurrences(
            of: #"\*([^*]+)\*"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove links, keep text
        text = text.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove metadata block
        text = text.replacingOccurrences(
            of: #"---\n[\s\S]*?\n---\n?"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove end marker
        text = text.replacingOccurrences(
            of: #"\*\*\*\s*<!--.*?-->"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove chapter markers (token style)
        text = text.replacingOccurrences(
            of: #"<CHAPTER>.*?</CHAPTER>"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove chapter markers (HTML comment style)
        text = text.replacingOccurrences(
            of: #"<!--\s*CHAPTER:.*?-->"#,
            with: "",
            options: .regularExpression
        )
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Word count of cleaned content.
    /// Uses semantic word counting (normalizes markdown) for accurate comparison with originalWordCount.
    /// Note: Does NOT strip the metadata block/markers that were added by cleaning,
    /// as this ensures apples-to-apples comparison with the original word count.
    var wordCount: Int {
        normalizedForCounting
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }
    
    /// Normalized content for word counting (strips markdown formatting only).
    /// This matches the normalization applied to the original content.
    /// Unlike cleanedPlainText, this does NOT remove metadata blocks or markers
    /// because those were ADDED by the cleaning pipeline, not part of the original.
    private var normalizedForCounting: String {
        var text = cleanedMarkdown
        
        // Remove markdown headers (keep the text) - with multiline matching via (?m)
        text = text.replacingOccurrences(
            of: #"(?m)^#{1,6}\s+"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove bold markers: **text** → text
        text = text.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove bold with underscores: __text__ → text
        text = text.replacingOccurrences(
            of: #"__([^_]+)__"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove italics: *text* → text
        text = text.replacingOccurrences(
            of: #"(?<![*\n])\*([^*\n]+)\*(?!\*)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove italics with underscores: _text_ → text
        text = text.replacingOccurrences(
            of: #"(?<![_\n])_([^_\n]+)_(?!_)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove links, keep text: [text](url) → text
        text = text.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove image markdown entirely: ![alt](src) → empty
        text = text.replacingOccurrences(
            of: #"!\[.*?\]\(.*?\)"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove inline code backticks: `code` → code
        text = text.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Clean up multiple spaces
        text = text.replacingOccurrences(
            of: "  +",
            with: " ",
            options: .regularExpression
        )
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Character count of cleaned content.
    var characterCount: Int {
        cleanedPlainText.count
    }
    
    /// Estimated token count for LLM use (rough estimate: ~4 chars per token).
    var estimatedTokenCount: Int {
        characterCount / 4
    }
    
    // MARK: - Computed Properties: Cost
    
    /// Total cost of the cleaning operation (Claude API pricing).
    /// Claude 3.5 Sonnet: $3/M input, $15/M output.
    /// If separate tokens not available, estimates 40% input, 60% output.
    var totalCost: Decimal {
        let inputCostPerToken = Decimal(string: "0.000003") ?? Decimal.zero  // $3 per million
        let outputCostPerToken = Decimal(string: "0.000015") ?? Decimal.zero // $15 per million
        
        // Use separate counts if available, otherwise estimate from total
        let actualInputTokens = inputTokens > 0 ? inputTokens : Int(Double(tokensUsed) * 0.4)
        let actualOutputTokens = outputTokens > 0 ? outputTokens : Int(Double(tokensUsed) * 0.6)
        
        let inputCost = Decimal(actualInputTokens) * inputCostPerToken
        let outputCost = Decimal(actualOutputTokens) * outputCostPerToken
        
        return inputCost + outputCost
    }
    
    /// Formatted total cost with 2 decimal places.
    var formattedTotalCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: totalCost as NSDecimalNumber) ?? "$0.00"
    }
    
    // MARK: - Computed Properties: Timing
    
    /// Cleaning duration in seconds.
    var cleaningDuration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
    
    /// Formatted duration string.
    var formattedDuration: String {
        if cleaningDuration < 60 {
            return String(format: "%.1fs", cleaningDuration)
        } else if cleaningDuration < 3600 {
            let minutes = Int(cleaningDuration) / 60
            let seconds = Int(cleaningDuration) % 60
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(cleaningDuration) / 3600
            let minutes = (Int(cleaningDuration) % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
    
    // MARK: - Computed Properties: Reduction
    
    /// Word reduction from cleaning (can be negative if content expanded).
    var wordReduction: Int {
        originalWordCount - wordCount
    }
    
    /// Word reduction as percentage.
    var wordReductionPercentage: Double {
        guard originalWordCount > 0 else { return 0 }
        return Double(wordReduction) / Double(originalWordCount) * 100
    }
    
    /// Formatted word reduction.
    var formattedWordReduction: String {
        if wordReduction >= 0 {
            return "-\(wordReduction.formatted()) words (\(String(format: "%.1f", wordReductionPercentage))%)"
        } else {
            return "+\(abs(wordReduction).formatted()) words"
        }
    }
    
    // MARK: - Computed Properties: Steps
    
    /// Number of steps executed.
    var stepCount: Int {
        executedSteps.count
    }
    
    /// Pattern detection confidence.
    var patternConfidence: ConfidenceLevel {
        detectedPatterns.confidenceLevel
    }
    
    /// Whether scholarly apparatus was removed.
    var hasScholarlyApparatusRemoved: Bool {
        (citationsRemoved ?? 0) > 0 ||
        (footnoteMarkersRemoved ?? 0) > 0 ||
        (footnoteSectionsRemoved ?? 0) > 0
    }
    
    /// Whether auxiliary content was removed.
    var hasAuxiliaryContentRemoved: Bool {
        (auxiliaryListsRemoved ?? 0) > 0
    }
    
    // MARK: - Computed Properties: V2 Statistics Summary
    
    /// Summary of what was removed by new V2 steps.
    var v2RemovalSummary: String? {
        var parts: [String] = []
        
        if let lists = auxiliaryListsRemoved, lists > 0 {
            parts.append("\(lists) auxiliary list(s)")
        }
        if let citations = citationsRemoved, citations > 0 {
            parts.append("\(citations) citation(s)")
        }
        if let markers = footnoteMarkersRemoved, markers > 0 {
            parts.append("\(markers) footnote marker(s)")
        }
        if let sections = footnoteSectionsRemoved, sections > 0 {
            parts.append("\(sections) footnote section(s)")
        }
        
        return parts.isEmpty ? nil : "Removed: " + parts.joined(separator: ", ")
    }
    
    /// Total lines removed by V2 steps.
    var v2LinesRemoved: Int {
        (auxiliaryListLinesRemoved ?? 0) + (footnoteLinesRemoved ?? 0)
    }
    
    // MARK: - Summary
    
    /// Summary of the cleaning for display.
    var summary: String {
        var lines = [
            "\(stepCount) steps executed",
            "\(apiCallCount) API calls",
            "\(tokensUsed.formatted()) tokens used",
            "Duration: \(formattedDuration)",
            "Words: \(wordCount.formatted()) (\(formattedWordReduction))"
        ]
        
        if let v2Summary = v2RemovalSummary {
            lines.append(v2Summary)
        }
        
        if let chapters = chaptersDetected, chapters > 0 {
            lines.append("\(chapters) chapter(s) detected")
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Short summary for list display.
    var shortSummary: String {
        "\(wordCount.formatted()) words • \(formattedDuration)"
    }
}

// MARK: - CleanedContent + Export

extension CleanedContent {
    
    /// Content formatted for export.
    func contentForExport(includeMetadata: Bool = true) -> String {
        if includeMetadata {
            return cleanedMarkdown
        } else {
            // Remove the metadata header and block
            var content = cleanedMarkdown
            
            // Remove title header
            content = content.replacingOccurrences(
                of: #"^#\s+.+\n+"#,
                with: "",
                options: .regularExpression
            )
            
            // Remove YAML block
            content = content.replacingOccurrences(
                of: #"---\n[\s\S]*?\n---\n+"#,
                with: "",
                options: .regularExpression
            )
            
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// Plain text content for export.
    var plainTextForExport: String {
        cleanedPlainText
    }
    
    /// JSON representation of cleaned content with metadata.
    func toJSON(prettyPrint: Bool = true) -> String? {
        let encoder = JSONEncoder()
        if prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        encoder.dateEncodingStrategy = .iso8601
        
        // Create export structure
        struct ExportData: Encodable {
            let metadata: DocumentMetadata
            let content: String
            let wordCount: Int
            let characterCount: Int
            let cleanedAt: Date
            let contentType: String?
            let chaptersDetected: Int?
            let citationsRemoved: Int?
            let footnotesRemoved: Int?
        }
        
        let exportData = ExportData(
            metadata: metadata,
            content: cleanedPlainText,
            wordCount: wordCount,
            characterCount: characterCount,
            cleanedAt: completedAt,
            contentType: contentTypeFlags?.primaryType.rawValue,
            chaptersDetected: chaptersDetected,
            citationsRemoved: citationsRemoved,
            footnotesRemoved: (footnoteMarkersRemoved ?? 0) + (footnoteSectionsRemoved ?? 0)
        )
        
        guard let data = try? encoder.encode(exportData),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return json
    }
}

// MARK: - CleanedContent + Comparison

extension CleanedContent {
    
    /// Statistics comparing cleaned to original content.
    struct ComparisonStats: Equatable, Sendable {
        let originalWords: Int
        let cleanedWords: Int
        let wordsRemoved: Int
        let reductionPercentage: Double
        let stepsApplied: Int
        let duration: TimeInterval
        let tokensUsed: Int
        
        // V2 statistics
        let auxiliaryListsRemoved: Int
        let citationsRemoved: Int
        let footnotesRemoved: Int
        let chaptersDetected: Int
    }
    
    /// Generate comparison statistics.
    var comparisonStats: ComparisonStats {
        ComparisonStats(
            originalWords: originalWordCount,
            cleanedWords: wordCount,
            wordsRemoved: wordReduction,
            reductionPercentage: wordReductionPercentage,
            stepsApplied: stepCount,
            duration: cleaningDuration,
            tokensUsed: tokensUsed,
            auxiliaryListsRemoved: auxiliaryListsRemoved ?? 0,
            citationsRemoved: citationsRemoved ?? 0,
            footnotesRemoved: (footnoteMarkersRemoved ?? 0) + (footnoteSectionsRemoved ?? 0),
            chaptersDetected: chaptersDetected ?? 0
        )
    }
}

// MARK: - CleanedContent + CodingKeys

extension CleanedContent {
    enum CodingKeys: String, CodingKey {
        case id
        case documentId = "document_id"
        case ocrResultId = "ocr_result_id"
        case metadata
        case cleanedMarkdown = "cleaned_markdown"
        case configuration
        case detectedPatterns = "detected_patterns"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case apiCallCount = "api_call_count"
        case tokensUsed = "tokens_used"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case executedSteps = "executed_steps"
        case originalWordCount = "original_word_count"
        case auxiliaryListsRemoved = "auxiliary_lists_removed"
        case auxiliaryListTypesRemoved = "auxiliary_list_types_removed"
        case auxiliaryListLinesRemoved = "auxiliary_list_lines_removed"
        case citationsRemoved = "citations_removed"
        case citationStyleRemoved = "citation_style_removed"
        case citationCharactersRemoved = "citation_characters_removed"
        case footnoteMarkersRemoved = "footnote_markers_removed"
        case footnoteSectionsRemoved = "footnote_sections_removed"
        case footnoteLinesRemoved = "footnote_lines_removed"
        case footnoteMarkerStyleRemoved = "footnote_marker_style_removed"
        case chaptersDetected = "chapters_detected"
        case hasParts = "has_parts"
        case chapterMarkerStyleUsed = "chapter_marker_style_used"
        case contentTypeFlags = "content_type_flags"
        case appliedPreset = "applied_preset"
        case userContentType = "user_content_type"
        case phaseResults = "phase_results"
        case qualityIssues = "quality_issues"
        case pipelineWarnings = "pipeline_warnings"
    }
}

// MARK: - Phase Result

/// Result of a single pipeline phase execution.
struct PhaseResult: Codable, Equatable, Sendable {
    /// Phase name (e.g. "Content Analysis").
    let name: String
    
    /// Step number in the pipeline (1-16).
    let stepNumber: Int
    
    /// Whether the phase completed successfully.
    let completed: Bool
    
    /// Confidence score (0.0-1.0), nil if not applicable.
    let confidence: Double?
    
    /// Execution method: "AI", "Hybrid", or "Code".
    let method: String
}

// MARK: - Quality Issue

/// Issue detected during final quality review.
struct QualityIssue: Codable, Equatable, Sendable {
    /// Severity level: "critical", "warning", "info".
    let severity: String
    
    /// Issue category.
    let category: String
    
    /// Human-readable description.
    let description: String
    
    /// Location in document (optional).
    let location: String?
}
