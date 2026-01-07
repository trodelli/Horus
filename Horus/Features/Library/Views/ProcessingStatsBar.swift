//
//  ProcessingStatsBar.swift
//  Horus
//
//  Created on 07/01/2026.
//

import SwiftUI

/// Compact horizontal bar displaying OCR result statistics.
/// Designed to appear above the preview content in Library view.
struct ProcessingStatsBar: View {
    
    // MARK: - Properties
    
    /// The OCR result to display statistics for
    let result: OCRResult
    
    /// Optional file size to display (from original document)
    var fileSize: Int64?
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            // Processing Time
            statItem(
                icon: "clock",
                value: result.formattedDuration,
                label: nil
            )
            
            statDivider
            
            // Page Count
            statItem(
                icon: "doc.text",
                value: "\(result.pageCount)",
                label: result.pageCount == 1 ? "page" : "pages"
            )
            
            statDivider
            
            // Word Count
            statItem(
                icon: "textformat",
                value: result.wordCount.formatted(),
                label: "words"
            )
            
            statDivider
            
            // Token Count
            statItem(
                icon: "number",
                value: result.formattedTokenCount,
                label: "tokens"
            )
            
            statDivider
            
            // Cost
            statItem(
                icon: "dollarsign.circle",
                value: result.formattedCost,
                label: nil
            )
            
            Spacer()
            
            // File size (if available)
            if let fileSize = fileSize {
                statItem(
                    icon: "doc.zipper",
                    value: formattedFileSize(fileSize),
                    label: nil
                )
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    // MARK: - Subviews
    
    private func statItem(icon: String, value: String, label: String?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
            
            if let label = label {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }
    
    private var statDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: 14)
    }
    
    // MARK: - Helpers
    
    private func formattedFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Compact Variant

/// A more compact version of the stats bar for tighter spaces.
struct ProcessingStatsBarCompact: View {
    
    let result: OCRResult
    
    var body: some View {
        HStack(spacing: 12) {
            Label(result.formattedDuration, systemImage: "clock")
            Label("\(result.pageCount) pg", systemImage: "doc.text")
            Label(result.formattedTokenCount, systemImage: "number")
            Label(result.formattedCost, systemImage: "dollarsign.circle")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }
}

// MARK: - Preview

#Preview("Full Stats Bar") {
    let mockResult = OCRResult(
        documentId: UUID(),
        pages: [
            OCRPage(index: 0, markdown: "# Test Page 1\n\nThis is some sample content for testing the statistics bar. It contains multiple sentences to generate a reasonable word count."),
            OCRPage(index: 1, markdown: "## Test Page 2\n\nMore content here with additional words and sentences to make the preview more realistic.")
        ],
        model: "mistral-ocr-latest",
        cost: Decimal(string: "0.012")!,
        processingDuration: 3.2
    )
    
    return VStack(spacing: 20) {
        ProcessingStatsBar(result: mockResult, fileSize: 2_450_000)
        ProcessingStatsBar(result: mockResult)
        ProcessingStatsBarCompact(result: mockResult)
    }
    .frame(width: 600)
    .padding()
}

#Preview("Single Page Document") {
    let mockResult = OCRResult(
        documentId: UUID(),
        pages: [
            OCRPage(index: 0, markdown: "# Single Page\n\nJust one page of content.")
        ],
        model: "mistral-ocr-latest",
        cost: Decimal(string: "0.001")!,
        processingDuration: 0.8
    )
    
    return ProcessingStatsBar(result: mockResult, fileSize: 150_000)
        .frame(width: 500)
        .padding()
}
