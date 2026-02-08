//
//  CleanedExportSheetView.swift
//  Horus
//
//  Created on 23/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Sheet for exporting cleaned document content with format options.
/// Design matches the OCR ExportSheetView for consistency.
struct CleanedExportSheetView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @Bindable var viewModel: CleaningViewModel
    let document: Document
    
    // MARK: - State
    
    @State private var selectedFormats: Set<CleanedExportFormat> = [.markdown]
    // (showPreview removed - preview feature removed for cleaner UX)
    @State private var isExporting: Bool = false
    
    // Export options
    @State private var includeMetadata: Bool = true
    @State private var includeCost: Bool = true
    @State private var includeProcessingTime: Bool = true
    @State private var includeFrontMatter: Bool = true
    @State private var prettyPrintJSON: Bool = true
    @State private var includeCleaningReport: Bool = true
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Document info
                    documentInfoSection
                    
                    Divider()
                    
                    // Format selection
                    formatSection
                    
                    Divider()
                    
                    // Options
                    optionsSection
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer with buttons
            footer
        }
        .frame(width: 480, height: 540)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundStyle(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Export Document")
                    .font(.headline)
                
                Text(document.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Document Info Section
    
    private var documentInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Document Details", systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                CleanedInfoPill(
                    label: "Pages",
                    value: "\(document.result?.pageCount ?? 1)"
                )
                CleanedInfoPill(
                    label: "Words",
                    value: formatNumber(viewModel.cleanedContent?.wordCount ?? viewModel.originalWordCount)
                )
                CleanedInfoPill(
                    label: "Cost",
                    value: formatCost(viewModel.cleanedContent?.totalCost)
                )
            }
        }
    }
    
    // MARK: - Format Section
    
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export Format", systemImage: "doc.badge.gearshape")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text("Select one or more formats to export")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                ForEach(CleanedExportFormat.allCases) { format in
                    CleanedFormatCheckboxRow(
                        format: format,
                        isSelected: selectedFormats.contains(format)
                    ) {
                        if selectedFormats.contains(format) {
                            selectedFormats.remove(format)
                        } else {
                            selectedFormats.insert(format)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Options", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Include metadata", isOn: $includeMetadata)
                Toggle("Include processing cost", isOn: $includeCost)
                    .disabled(!includeMetadata)
                Toggle("Include processing time", isOn: $includeProcessingTime)
                    .disabled(!includeMetadata)
                
                // Cleaning report toggle - always relevant for cleaned documents
                Toggle("Include cleaning report", isOn: $includeCleaningReport)
                    .help("Appends detailed pipeline metrics to exported file")
                
                if selectedFormats.contains(.markdown) {
                    Toggle("Include YAML front matter", isOn: $includeFrontMatter)
                        .disabled(!includeMetadata)
                }
                
                if selectedFormats.contains(.json) {
                    Toggle("Pretty-print JSON", isOn: $prettyPrintJSON)
                }
            }
            .toggleStyle(.checkbox)
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Button("Export...") {
                exportContent()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(isExporting || selectedFormats.isEmpty || viewModel.cleanedContent == nil)
        }
        .padding(16)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Export Action
    
    private func exportContent() {
        guard let content = viewModel.cleanedContent else { return }
        
        isExporting = true
        
        // If single format, use save panel
        if selectedFormats.count == 1, let format = selectedFormats.first {
            exportSingleFormat(content: content, format: format)
        } else {
            // Multiple formats - use folder picker
            exportMultipleFormats(content: content)
        }
    }
    
    private func exportSingleFormat(content: CleanedContent, format: CleanedExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(document.displayName)_cleaned.\(format.fileExtension)"
        panel.message = "Export cleaned document as \(format.displayName)"
        
        panel.begin { response in
            defer { isExporting = false }
            
            guard response == .OK, let url = panel.url else { return }
            
            do {
                let exportText = prepareExportContent(content: content, format: format)
                try exportText.write(to: url, atomically: true, encoding: .utf8)
                dismiss()
            } catch {
                print("Export failed: \(error)")
            }
        }
    }
    
    private func exportMultipleFormats(content: CleanedContent) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to save exported files"
        panel.prompt = "Export Here"
        
        panel.begin { response in
            defer { isExporting = false }
            
            guard response == .OK, let folderURL = panel.url else { return }
            
            do {
                for format in selectedFormats {
                    let fileName = "\(document.displayName)_cleaned.\(format.fileExtension)"
                    let fileURL = folderURL.appendingPathComponent(fileName)
                    let exportText = prepareExportContent(content: content, format: format)
                    try exportText.write(to: fileURL, atomically: true, encoding: .utf8)
                }
                dismiss()
            } catch {
                print("Export failed: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Prepare export content with options applied
    private func prepareExportContent(content: CleanedContent, format: CleanedExportFormat) -> String {
        var exportText = format.exportContent(from: content)
        
        // Add metadata if requested
        if includeMetadata {
            let metadata = buildMetadata(content: content, format: format)
            
            switch format {
            case .markdown:
                if includeFrontMatter {
                    // Add YAML front matter
                    exportText = "---\n\(metadata)---\n\n\(exportText)"
                } else {
                    // Add as comment block
                    exportText = "<!-- \(metadata) -->\n\n\(exportText)"
                }
            case .plainText:
                // Add as header comment
                exportText = "# \(metadata)\n\n\(exportText)"
            case .json:
                // Metadata is already in JSON structure, just control formatting
                if !prettyPrintJSON {
                    // Minify JSON (content.toJSON() is already pretty by default)
                    if let data = exportText.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data),
                       let minified = try? JSONSerialization.data(withJSONObject: json, options: []),
                       let minifiedString = String(data: minified, encoding: .utf8) {
                        exportText = minifiedString
                    }
                }
            }
        }
        
        // Add cleaning report if enabled
        if includeCleaningReport {
            switch format {
            case .markdown, .plainText:
                exportText += "\n\n"
                exportText += buildCleaningReportBlock(content: content)
            case .json:
                // Inject cleaningReport into JSON
                exportText = injectCleaningReportIntoJSON(exportText, content: content)
            }
        }
        
        return exportText
    }
    
    /// Build metadata string based on options
    private func buildMetadata(content: CleanedContent, format: CleanedExportFormat) -> String {
        var lines: [String] = []
        
        // Document name
        lines.append("document: \(document.displayName)")
        
        // Word count
        lines.append("words: \(content.wordCount)")
        
        // Processing cost
        if includeCost {
            lines.append("cost: \(formatCost(content.totalCost))")
        }
        
        // Processing time
        if includeProcessingTime {
            let duration = content.completedAt.timeIntervalSince(content.startedAt)
            let formattedTime = String(format: "%.1fs", duration)
            lines.append("processing_time: \(formattedTime)")
        }
        
        // Cleaning configuration
        lines.append("cleaned: true")
        lines.append("steps: \(content.executedSteps.count)")
        
        return lines.joined(separator: "\n")
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatCost(_ cost: Decimal?) -> String {
        guard let cost = cost else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
    }
    
    // MARK: - Cleaning Report Helpers
    
    /// Build comprehensive cleaning report as HTML comment block
    private func buildCleaningReportBlock(content: CleanedContent) -> String {
        let divider = "═══════════════════════════════════════════════════════════════════"
        let subDivider = "─────────────────────────────────────────────────────────────────"
        
        var report = "<!-- \n"
        report += "\(divider)\n"
        report += "HORUS CLEANING REPORT\n"
        report += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n"
        report += "Pipeline: V3 Evolved (\(content.stepCount) Steps)\n"
        report += "\(divider)\n\n"
        
        // User Configuration
        report += "USER CONFIGURATION\n"
        report += "\(subDivider)\n"
        if let preset = content.appliedPreset {
            report += formatReportRow("Preset Applied", preset)
        } else {
            report += formatReportRow("Preset Applied", "Default")
        }
        if let contentType = content.userContentType {
            report += formatReportRow("Content Type", "\(contentType) (User Override)")
        } else if let detected = content.contentTypeFlags?.primaryType {
            report += formatReportRow("Content Type", "\(detected.displayName) (Auto-detected)")
        } else {
            report += formatReportRow("Content Type", "Auto-detected")
        }
        report += "\n"
        
        // Document Metrics
        report += "DOCUMENT METRICS\n"
        report += "\(subDivider)\n"
        report += formatReportRow("Original Words", "\(content.originalWordCount.formatted())")
        
        let reductionSign = content.wordReduction >= 0 ? "−" : "+"
        let reductionPct = String(format: "%.1f", abs(content.wordReductionPercentage))
        report += formatReportRow("Cleaned Words", "\(content.wordCount.formatted())    (\(reductionSign)\(reductionPct)%)")
        report += formatReportRow("Characters", "\(content.characterCount.formatted())")
        report += formatReportRow("Est. Tokens", "~\(content.estimatedTokenCount.formatted())")
        report += "\n"
        
        // Processing Metrics
        report += "PROCESSING METRICS\n"
        report += "\(subDivider)\n"
        report += formatReportRow("Steps Executed", "\(content.stepCount)")
        report += formatReportRow("API Calls", "\(content.apiCallCount)")
        report += formatReportRow("Tokens Used", "\(content.tokensUsed.formatted())")
        report += formatReportRow("Est. Cost", content.formattedTotalCost)
        report += formatReportRow("Duration", content.formattedDuration)
        report += "\n"
        
        // Pipeline Confidence
        if let confidence = content.overallConfidence {
            report += "PIPELINE CONFIDENCE\n"
            report += "\(subDivider)\n"
            
            let confidencePercentage = Int(confidence * 100)
            let rating = confidenceRatingForReport(confidence)
            let assessment = confidenceAssessmentForReport(rating)
            
            report += formatReportRow("Score", "\(confidencePercentage)%")
            report += formatReportRow("Level", rating)
            report += formatReportRow("Assessment", assessment)
            report += "\n"
        }
        
        // Phase Execution
        if let phases = content.phaseResults, !phases.isEmpty {
            report += "PHASE EXECUTION\n"
            report += "\(subDivider)\n"
            report += "Confidence scores indicate the pipeline's certainty that each\n"
            report += "phase was executed correctly and content was processed accurately.\n\n"
            
            for phase in phases {
                let status = phase.completed ? "✓" : "—"
                let confidenceStr: String
                if let conf = phase.confidence {
                    confidenceStr = String(format: "%3d%%", Int(conf * 100))
                } else if phase.completed {
                    confidenceStr = "—"
                } else {
                    confidenceStr = "N/A"
                }
                let methodPad = phase.method.padding(toLength: 6, withPad: " ", startingAt: 0)
                let namePad = phase.name.padding(toLength: 25, withPad: " ", startingAt: 0)
                report += "  \(namePad) \(status) \(methodPad) \(confidenceStr)\n"
            }
            report += "\n"
        }
        
        // Executed Steps
        report += "EXECUTED STEPS\n"
        report += "\(subDivider)\n"
        
        let allSteps = CleaningStep.allCases
        for step in allSteps {
            let stepNumber = String(format: "%2d", step.rawValue)
            let statusLabel: String
            
            if content.configuration.isStepEnabled(step) {
                statusLabel = "Success"
            } else {
                statusLabel = "Skipped"
            }
            
            let namePad = step.displayName.padding(toLength: 28, withPad: " ", startingAt: 0)
            let statusPad = statusLabel.padding(toLength: 8, withPad: " ", startingAt: 0)
            report += "  Step \(stepNumber): \(namePad) \(statusPad)\n"
        }
        report += "\n"
        
        // Issues
        if let issues = content.qualityIssues, !issues.isEmpty {
            report += "ISSUES (\(issues.count))\n"
            report += "\(subDivider)\n"
            for issue in issues {
                let icon: String
                switch issue.severity.lowercased() {
                case "critical": icon = "✗"
                case "warning": icon = "⚠"
                default: icon = "ℹ"
                }
                report += "\(icon) \(issue.severity.uppercased()): \(issue.description)\n"
                report += "   Category: \(issue.category)\n"
                if let location = issue.location, !location.isEmpty {
                    report += "   Location: \(location)\n"
                }
                report += "\n"
            }
        }
        
        // Warnings
        if let warnings = content.pipelineWarnings, !warnings.isEmpty {
            report += "WARNINGS (\(warnings.count))\n"
            report += "\(subDivider)\n"
            for warning in warnings {
                report += "• \(warning)\n"
            }
            report += "\n"
        }
        
        // Quality
        report += "QUALITY\n"
        report += "\(subDivider)\n"
        report += formatReportRow("Pattern Confidence", content.patternConfidence.displayName)
        
        report += "\n\(divider)\n"
        report += "-->\n"
        
        return report
    }
    
    /// Get confidence rating string
    private func confidenceRatingForReport(_ confidence: Double) -> String {
        switch confidence {
        case 0.9...: return "Very High"
        case 0.75..<0.9: return "High"
        case 0.6..<0.75: return "Moderate"
        case 0.4..<0.6: return "Low"
        default: return "Very Low"
        }
    }
    
    /// Get confidence assessment text
    private func confidenceAssessmentForReport(_ rating: String) -> String {
        switch rating {
        case "Very High":
            return "Excellent quality. All phases completed successfully."
        case "High":
            return "Good quality. Most phases completed with high confidence."
        case "Moderate":
            return "Acceptable quality. Review recommended."
        case "Low":
            return "Below expectations. Manual review needed."
        case "Very Low":
            return "Quality concerns. Careful review required."
        default:
            return "Unknown quality level."
        }
    }
    
    /// Format a metric row with consistent alignment
    private func formatReportRow(_ label: String, _ value: String) -> String {
        let paddedLabel = label.padding(toLength: 19, withPad: " ", startingAt: 0)
        return "\(paddedLabel)\(value)\n"
    }
    
    /// Inject cleaning report into JSON structure
    private func injectCleaningReportIntoJSON(_ jsonString: String, content: CleanedContent) -> String {
        guard var data = jsonString.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return jsonString
        }
        
        // Build cleaning report dictionary
        var cleaningReport: [String: Any] = [
            "appliedPreset": content.appliedPreset as Any,
            "userContentType": content.userContentType as Any,
            "originalWordCount": content.originalWordCount,
            "cleanedWordCount": content.wordCount,
            "wordReductionPercent": content.wordReductionPercentage,
            "characterCount": content.characterCount,
            "stepsExecuted": content.stepCount,
            "apiCalls": content.apiCallCount,
            "tokensUsed": content.tokensUsed,
            "estimatedCost": content.formattedTotalCost,
            "durationSeconds": content.cleaningDuration,
            "patternConfidence": content.patternConfidence.displayName,
            "executedStepNames": content.executedSteps.map { $0.displayName }
        ]
        
        // Add phases if available
        if let phases = content.phaseResults {
            cleaningReport["phases"] = phases.map { phase in
                [
                    "name": phase.name,
                    "stepNumber": phase.stepNumber,
                    "completed": phase.completed,
                    "confidence": phase.confidence as Any,
                    "method": phase.method
                ]
            }
        }
        
        // Add issues if available
        if let issues = content.qualityIssues {
            cleaningReport["issues"] = issues.map { issue in
                [
                    "severity": issue.severity,
                    "category": issue.category,
                    "description": issue.description,
                    "location": issue.location as Any
                ]
            }
        }
        
        // Add warnings if available
        if let warnings = content.pipelineWarnings {
            cleaningReport["warnings"] = warnings
        }
        
        json["cleaningReport"] = cleaningReport
        
        // Re-encode
        let options: JSONSerialization.WritingOptions = prettyPrintJSON ? [.prettyPrinted, .sortedKeys] : []
        guard let updatedData = try? JSONSerialization.data(withJSONObject: json, options: options),
              let updatedString = String(data: updatedData, encoding: .utf8) else {
            return jsonString
        }
        
        return updatedString
    }
}

// MARK: - Cleaned Export Format

enum CleanedExportFormat: String, CaseIterable, Identifiable {
    case markdown = "markdown"
    case plainText = "plainText"
    case json = "json"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .plainText: return "Plain Text"
        case .json: return "JSON"
        }
    }
    
    var description: String {
        switch self {
        case .markdown:
            return "Preserves formatting with headers, lists, and tables. Best for LLM fine-tuning."
        case .plainText:
            return "Clean text without markup. Best for simple tokenization."
        case .json:
            return "Full structured data with page-level access. Best for data pipelines."
        }
    }
    
    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .json: return "json"
        }
    }
    
    var symbolName: String {
        switch self {
        case .markdown: return "text.badge.checkmark"
        case .plainText: return "doc.plaintext"
        case .json: return "curlybraces"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .markdown: return .plainText
        case .plainText: return .plainText
        case .json: return .json
        }
    }
    
    func exportContent(from content: CleanedContent) -> String {
        switch self {
        case .markdown:
            return content.cleanedMarkdown
        case .plainText:
            return content.cleanedPlainText
        case .json:
            return content.toJSON() ?? "{}"
        }
    }
}

// MARK: - Format Checkbox Row

struct CleanedFormatCheckboxRow: View {
    let format: CleanedExportFormat
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? .purple : .secondary)
                    .font(.title3)
                
                Image(systemName: format.symbolName)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .purple : .primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(format.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(format.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(".\(format.fileExtension)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.quaternaryLabelColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(10)
            .background(isSelected ? Color.purple.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple.opacity(0.5) : Color(.separatorColor), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Pill

struct CleanedInfoPill: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    CleanedExportSheetView(
        viewModel: .preview,
        document: Document(
            sourceURL: URL(fileURLWithPath: "/test/sample.md"),
            contentType: .plainText,
            fileSize: 75_000,
            estimatedPageCount: 1,
            status: .completed
        )
    )
}
