//
//  InspectorComponents.swift
//  Horus
//
//  Created on 25/01/2026.
//
//  Shared components for inspector panels across all tabs.
//  These components ensure visual consistency and reduce code duplication.
//

import SwiftUI

// MARK: - Inspector Card Container

/// A card container for inspector sections with subtle background and rounded corners.
/// Used across all tab inspectors for consistent visual grouping.
struct InspectorCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignConstants.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(DesignConstants.CornerRadius.lg)
    }
}

// MARK: - Inspector Row

/// A key-value row for the inspector panel.
/// Displays a label on the left and value on the right.
struct InspectorRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(DesignConstants.Typography.inspectorLabel)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(DesignConstants.Typography.inspectorValue)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Inspector Section Header

/// A consistent section header for inspector cards.
struct InspectorSectionHeader: View {
    let title: String
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: DesignConstants.Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
            }
            Text(title)
        }
        .font(DesignConstants.Typography.inspectorHeader)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Inspector Badge Row

/// A row with an icon and text, used for status indicators like "Contains images".
struct InspectorBadgeRow: View {
    let icon: String
    let text: String
    var color: Color = .secondary
    
    var body: some View {
        HStack(spacing: DesignConstants.Spacing.xs) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(color)
    }
}

// MARK: - Not Applied Indicator

/// A minimal indicator showing that a pipeline step was not applied.
/// Used when OCR or Cleaning wasn't performed for a document.
/// Follows macOS convention of secondary-colored text for unavailable states.
struct NotAppliedIndicator: View {
    var text: String = "Not applied"
    
    var body: some View {
        Text(text)
            .font(DesignConstants.Typography.inspectorValue)
            .foregroundStyle(.secondary)
    }
}

// MARK: - OCR Results Section

/// Displays OCR processing results in a standardized format.
/// Used across Input, OCR, and Library tab inspectors for consistency.
///
/// Shows: Pages, Words, Characters, Tokens, Duration, Cost
/// Plus optional content badges (Contains Tables, Contains Images)
struct OCRResultsSection: View {
    let result: OCRResult
    
    /// Whether to include the section header. Default true.
    /// Set to false when embedding within another section.
    var includeHeader: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            if includeHeader {
                InspectorSectionHeader(title: "OCR Results", icon: "doc.text.viewfinder")
            }
            
            // Metrics rows
            VStack(spacing: DesignConstants.Spacing.xs) {
                InspectorRow(label: "Pages", value: "\(result.pageCount)")
                InspectorRow(label: "Words", value: result.wordCount.formatted())
                InspectorRow(label: "Characters", value: result.characterCount.formatted())
                InspectorRow(label: "Tokens", value: result.formattedTokenCount)
                InspectorRow(label: "Duration", value: result.formattedDuration)
                InspectorRow(label: "Cost", value: result.formattedCost)
            }
            
            // Content badges (if applicable)
            if result.containsTables || result.containsImages {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                    if result.containsTables {
                        InspectorBadgeRow(icon: "tablecells", text: "Contains tables", color: .blue)
                    }
                    
                    if result.containsImages {
                        InspectorBadgeRow(icon: "photo", text: "Contains images", color: .blue)
                    }
                }
                .padding(.top, DesignConstants.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Cleaning Results Section

/// Displays cleaning results metrics in a unified visual style.
/// Used in CleaningInspectorView, InspectorView, and LibraryView for consistency.
///
/// Shows two metric containers:
/// 1. Output metrics: Words, Chars, Reduction, Time (purple background)
/// 2. API metrics: Tokens Used, Total Cost (purple background)
struct CleaningResultsSection: View {
    let content: CleanedContent
    
    /// Whether to include the section header. Default true.
    /// Set to false when embedding within another section.
    var includeHeader: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            if includeHeader {
                InspectorSectionHeader(title: "Cleaning Results", icon: "sparkles")
            }
            
            // Container 1: Output & Efficiency metrics
            HStack(spacing: 0) {
                metricCell(value: content.wordCount.formatted(), label: "Words")
                metricCell(value: content.characterCount.formatted(), label: "Chars")
                metricCell(
                    value: formatReduction(content.wordReductionPercentage),
                    label: "Reduction",
                    valueColor: content.wordReductionPercentage > 0 ? .green : .primary
                )
                metricCell(value: content.formattedDuration, label: "Time")
            }
            .padding(DesignConstants.Spacing.md)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(DesignConstants.CornerRadius.md)
            
            // Container 2: API/Financial metrics
            HStack(spacing: 0) {
                metricCell(
                    value: content.tokensUsed.formatted(),
                    label: "Tokens Used"
                )
                metricCell(
                    value: formatCost(content.totalCost),
                    label: "Total Cost"
                )
            }
            .padding(DesignConstants.Spacing.md)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(DesignConstants.CornerRadius.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Private Helpers
    
    private func metricCell(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: DesignConstants.Spacing.xs) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatReduction(_ percentage: Double) -> String {
        if percentage > 0 {
            return String(format: "-%.1f%%", percentage)
        } else if percentage < 0 {
            return String(format: "+%.1f%%", abs(percentage))
        }
        return "0%"
    }
    
    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
    }
}

// MARK: - Total Cost Section

/// Displays an itemized cost breakdown for completed processing.
/// Shows OCR cost, Cleaning cost, and Total cost with clear visual separation.
/// Used in Input (complete), Library, and Clean (complete) tab inspectors.
///
/// Supports two display modes:
/// - Itemized (default): Shows OCR Cost, Cleaning Cost, divider, and Total
/// - Compact: Shows only the relevant cost (use when only one cost type applies, e.g., Clean tab)
struct TotalCostSection: View {
    /// OCR processing cost (nil if OCR was not performed)
    let ocrCost: Decimal?
    
    /// Cleaning processing cost (nil if cleaning was not performed)
    let cleaningCost: Decimal?
    
    /// Whether to include the section header. Default true.
    var includeHeader: Bool = true
    
    /// Whether to show itemized breakdown (OCR + Cleaning) or just the relevant cost.
    /// Use compact mode (false) when only one cost type is relevant (e.g., Clean tab).
    var showItemizedBreakdown: Bool = true
    
    /// Computed total of all costs
    private var totalCost: Decimal {
        (ocrCost ?? 0) + (cleaningCost ?? 0)
    }
    
    /// Whether there's any cost to display
    private var hasCosts: Bool {
        totalCost > 0
    }
    
    /// Whether we have costs from both OCR and Cleaning
    private var hasBothCosts: Bool {
        (ocrCost ?? 0) > 0 && (cleaningCost ?? 0) > 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            if includeHeader {
                InspectorSectionHeader(title: "Total Cost", icon: "dollarsign.circle")
            }
            
            if showItemizedBreakdown {
                itemizedView
            } else {
                compactView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Itemized View
    
    private var itemizedView: some View {
        VStack(spacing: DesignConstants.Spacing.xs) {
            // OCR Cost row
            if let ocr = ocrCost, ocr > 0 {
                InspectorRow(label: "OCR Cost", value: formatCost(ocr), valueColor: .secondary)
            } else if ocrCost == nil {
                InspectorRow(label: "OCR Cost", value: "—", valueColor: .secondary)
            } else {
                InspectorRow(label: "OCR Cost", value: formatCost(0), valueColor: .secondary)
            }
            
            // Cleaning Cost row
            if let cleaning = cleaningCost, cleaning > 0 {
                InspectorRow(label: "Cleaning Cost", value: formatCost(cleaning), valueColor: .secondary)
            } else if cleaningCost == nil {
                InspectorRow(label: "Cleaning Cost", value: "—", valueColor: .secondary)
            } else {
                InspectorRow(label: "Cleaning Cost", value: formatCost(0), valueColor: .secondary)
            }
            
            // Divider before total
            Divider()
                .padding(.vertical, DesignConstants.Spacing.xs)
            
            // Total row (emphasized)
            totalRow
        }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        VStack(spacing: DesignConstants.Spacing.xs) {
            // Show individual cost if only one type exists
            if let cleaning = cleaningCost, cleaning > 0, (ocrCost ?? 0) == 0 {
                InspectorRow(label: "Cleaning Cost", value: formatCost(cleaning))
            } else if let ocr = ocrCost, ocr > 0, (cleaningCost ?? 0) == 0 {
                InspectorRow(label: "OCR Cost", value: formatCost(ocr))
            } else {
                // If both exist or neither, show total
                totalRow
            }
        }
    }
    
    // MARK: - Shared Components
    
    private var totalRow: some View {
        HStack {
            Text("Total")
                .font(DesignConstants.Typography.inspectorLabel)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(formatCost(totalCost))
                .font(DesignConstants.Typography.inspectorValue)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Private Helpers
    
    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
    }
}

// MARK: - Estimated Cost Section

/// Displays an estimated cost before processing completes.
/// Used in Clean tab (pre-completion) and potentially Input tab for OCR estimates.
struct EstimatedCostSection: View {
    /// The estimated cost string (e.g., "~$0.09", "< $0.01")
    let estimatedCost: String
    
    /// Optional explanatory text
    var explanation: String? = "Based on document size and enabled steps"
    
    /// Whether to include the section header. Default true.
    var includeHeader: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            if includeHeader {
                InspectorSectionHeader(title: "Estimated Cost", icon: "dollarsign.circle")
            }
            
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                InspectorRow(label: "Est. Cost", value: estimatedCost)
                
                if let explanation = explanation {
                    Text(explanation)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Inspector Components") {
    ScrollView {
        VStack(spacing: DesignConstants.Spacing.md) {
            // Basic components
            InspectorCard {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
                    InspectorSectionHeader(title: "File Information", icon: "info.circle")
                    InspectorRow(label: "Size", value: "14 MB")
                    InspectorRow(label: "Type", value: "PDF Document")
                    InspectorRow(label: "Pages", value: "24")
                }
            }
            
            // Not Applied Indicator
            InspectorCard {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
                    InspectorSectionHeader(title: "OCR Results", icon: "doc.text.viewfinder")
                    NotAppliedIndicator()
                }
            }
            
            // Total Cost Section
            InspectorCard {
                TotalCostSection(
                    ocrCost: Decimal(string: "0.014"),
                    cleaningCost: Decimal(string: "0.0153")
                )
            }
            
            // Total Cost with no cleaning
            InspectorCard {
                TotalCostSection(
                    ocrCost: Decimal(string: "0.01"),
                    cleaningCost: nil
                )
            }
            
            // Estimated Cost
            InspectorCard {
                EstimatedCostSection(estimatedCost: "~$0.09")
            }
            
            // Total Cost Compact Mode (for Clean tab)
            InspectorCard {
                TotalCostSection(
                    ocrCost: nil,
                    cleaningCost: Decimal(string: "0.0153"),
                    showItemizedBreakdown: false
                )
            }
        }
        .padding()
    }
    .frame(width: 320, height: 700)
    .background(Color(nsColor: .underPageBackgroundColor))
}

#Preview("OCR Results Section") {
    let mockResult = OCRResult(
        documentId: UUID(),
        pages: [
            OCRPage(index: 0, markdown: "Sample content", tables: [], images: []),
            OCRPage(index: 1, markdown: "More content", tables: [
                ExtractedTable(id: "t1", markdown: "| A | B |")
            ], images: [
                ExtractedImage(id: "i1", topLeftX: 0, topLeftY: 0, bottomRightX: 100, bottomRightY: 100, imageBase64: nil)
            ])
        ],
        model: "mistral-ocr-latest",
        cost: Decimal(string: "0.014") ?? 0,
        processingDuration: 7.2
    )
    
    return InspectorCard {
        OCRResultsSection(result: mockResult)
    }
    .padding()
    .frame(width: 320)
    .background(Color(nsColor: .underPageBackgroundColor))
}
