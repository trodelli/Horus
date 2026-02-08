//
//  DetailedResultsView.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//  Updated: Feb 2026 - Merged Summary tab, 8-phase model, improved readability.
//
//  Purpose: Complete audit trail of pipeline execution showing
//  phase-by-phase breakdown, confidence scores, and issues.
//

import SwiftUI

// MARK: - Detailed Results View

/// Complete audit trail of evolved pipeline execution.
struct DetailedResultsView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let result: EvolvedCleaningResult
    let pipelineConfidence: PipelineConfidence
    
    @State private var selectedSection: ResultSection = .summary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with title and close button
            headerSection
            
            Divider()
            
            // Section picker (Summary | Issues | Warnings)
            Picker("Section", selection: $selectedSection) {
                ForEach(ResultSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignConstants.Spacing.lg)
            .padding(.vertical, DesignConstants.Spacing.md)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.lg) {
                    switch selectedSection {
                    case .summary:
                        summarySection
                    case .issues:
                        issuesSection
                    case .warnings:
                        warningsSection
                    }
                }
                .padding(DesignConstants.Spacing.lg)
            }
        }
        .frame(width: 650, height: 750)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundStyle(.purple)
                
                Text("Detailed Results")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(DesignConstants.Spacing.lg)
    }
    
    // MARK: - Summary Section (Merged Overview + Phases)
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.lg) {
            // Confidence Card
            confidenceCard
            
            // Pipeline Statistics (4-column grid)
            statisticsCard
            
            // Phase Breakdown (8 phases)
            phaseBreakdownCard
        }
    }
    
    // MARK: - Confidence Card
    
    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            Text("CONFIDENCE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pipelineConfidence.overallRating.rawValue)
                        .font(.system(size: 20, weight: .bold))
                    
                    Text(confidenceExplanation)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Large percentage badge
                Text("\(Int(pipelineConfidence.overallConfidence * 100))%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(confidenceColor)
            }
            .padding(DesignConstants.Spacing.md)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(DesignConstants.CornerRadius.md)
        }
    }
    
    private var confidenceExplanation: String {
        switch pipelineConfidence.overallRating {
        case .veryHigh:
            return "Excellent quality. All phases completed successfully with high confidence."
        case .high:
            return "Good quality. Most phases completed with high confidence scores."
        case .moderate:
            return "Acceptable quality. Some phases had reduced confidence. Review recommended."
        case .low:
            return "Below expectations. Multiple phases had issues. Manual review needed."
        case .veryLow:
            return "Quality concerns. Significant issues detected. Careful review required."
        }
    }
    
    private var confidenceColor: Color {
        switch pipelineConfidence.overallRating {
        case .veryHigh, .high: return .green
        case .moderate: return .orange
        case .low, .veryLow: return .red
        }
    }
    
    // MARK: - Statistics Card (4-column)
    
    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            Text("PIPELINE STATISTICS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 0) {
                StatCell(label: "Phases", value: "\(completedPhaseCount)/8")
                Divider().frame(height: 40)
                StatCell(label: "Fallbacks", value: "\(pipelineConfidence.fallbacksUsed)")
                Divider().frame(height: 40)
                StatCell(label: "Time", value: String(format: "%.1fs", result.totalTime))
                Divider().frame(height: 40)
                StatCell(label: "Warnings", value: "\(pipelineConfidence.warnings.count)")
            }
            .padding(.vertical, DesignConstants.Spacing.sm)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(DesignConstants.CornerRadius.md)
        }
    }
    
    /// Number of completed phases (based on what ran)
    private var completedPhaseCount: Int {
        // Count phases that actually ran
        var count = 0
        if result.structureHints != nil { count += 1 }  // Content Analysis
        if result.boundaryDetection != nil { count += 1 }  // Metadata + Structural
        count += 4  // Core cleaning phases always run (Structural, Content, Scholarly, Back Matter)
        count += 1  // Optimization
        if result.finalReview != nil { count += 1 }  // Final Review
        return min(count, 8)
    }
    
    // MARK: - Phase Breakdown Card
    
    private var phaseBreakdownCard: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            Text("PHASE BREAKDOWN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 1) {
                ForEach(phaseDisplayData, id: \.name) { phase in
                    PhaseRow(phase: phase)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(DesignConstants.CornerRadius.md)
        }
    }
    
    /// Generate display data for all 8 phases
    private var phaseDisplayData: [PhaseDisplayData] {
        [
            PhaseDisplayData(
                number: 1,
                name: "Content Analysis",
                method: "AI",
                executed: result.structureHints != nil,
                confidence: result.structureHints?.overallConfidence
            ),
            PhaseDisplayData(
                number: 2,
                name: "Metadata Extraction",
                method: "AI",
                executed: result.boundaryDetection != nil,
                confidence: result.boundaryDetection?.confidence
            ),
            PhaseDisplayData(
                number: 3,
                name: "Structural Removal",
                method: "Hybrid",
                // Phase is executed if we have confidence data for it
                executed: result.phaseConfidences[3] != nil,
                confidence: result.phaseConfidences[3]
            ),
            PhaseDisplayData(
                number: 4,
                name: "Content Cleaning",
                method: "AI",
                executed: result.phaseConfidences[4] != nil,
                confidence: result.phaseConfidences[4]
            ),
            PhaseDisplayData(
                number: 5,
                name: "Scholarly Content",
                method: "Hybrid",
                executed: result.phaseConfidences[5] != nil,
                confidence: result.phaseConfidences[5]
            ),
            PhaseDisplayData(
                number: 6,
                name: "Back Matter Removal",
                method: "Hybrid",
                executed: result.phaseConfidences[6] != nil,
                confidence: result.phaseConfidences[6]
            ),
            PhaseDisplayData(
                number: 7,
                name: "Optimization & Assembly",
                method: "AI",
                executed: result.phaseConfidences[7] != nil,
                confidence: result.phaseConfidences[7]
            ),
            PhaseDisplayData(
                number: 8,
                name: "Final Quality Review",
                method: "AI",
                executed: result.finalReview != nil,
                confidence: result.finalReview?.qualityScore
            )
        ]
    }
    
    // MARK: - Issues Section
    
    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            if let review = result.finalReview, !review.issues.isEmpty {
                ForEach(review.issues.indices, id: \.self) { index in
                    let issue = review.issues[index]
                    IssueCard(issue: issue)
                }
            } else {
                ContentUnavailableView(
                    "No Issues Detected",
                    systemImage: "checkmark.circle.fill",
                    description: Text("The cleaning pipeline completed successfully without detecting any content issues.")
                )
            }
        }
    }
    
    // MARK: - Warnings Section
    
    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            if pipelineConfidence.warnings.isEmpty {
                ContentUnavailableView(
                    "No Warnings",
                    systemImage: "checkmark.circle.fill",
                    description: Text("Pipeline completed without any warnings.")
                )
            } else {
                ForEach(pipelineConfidence.warnings.indices, id: \.self) { index in
                    WarningCard(message: pipelineConfidence.warnings[index])
                }
            }
        }
    }
}

// MARK: - Result Section Enum

private enum ResultSection: String, CaseIterable {
    case summary = "Summary"
    case issues = "Issues"
    case warnings = "Warnings"
}

// MARK: - Phase Display Data

private struct PhaseDisplayData {
    let number: Int
    let name: String
    let method: String  // "AI", "Hybrid", or "Code"
    let executed: Bool  // Whether the phase was executed (false = skipped)
    let confidence: Double?  // nil = Unknown (if executed) or N/A (if skipped)
    
    /// Display status for the phase
    var displayStatus: PhaseStatus {
        if !executed {
            return .skipped
        } else if let conf = confidence {
            return .completed(confidence: conf)
        } else {
            return .unknown
        }
    }
}

/// Status of a phase for display purposes
private enum PhaseStatus {
    case completed(confidence: Double)
    case unknown
    case skipped
}

// MARK: - Supporting Views

private struct StatCell: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PhaseRow: View {
    let phase: PhaseDisplayData
    
    var body: some View {
        HStack {
            // Phase number
            Text("\(phase.number).")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.purple)
                .frame(width: 24, alignment: .trailing)
            
            // Phase name
            Text(phase.name)
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            // Method badge (dimmed if skipped)
            Text(phase.method)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(phase.executed ? methodColor(phase.method) : .gray.opacity(0.5))
                .cornerRadius(4)
            
            // Status/confidence display
            statusView
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, DesignConstants.Spacing.md)
        .padding(.vertical, DesignConstants.Spacing.sm)
        .opacity(phase.executed ? 1.0 : 0.6)
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch phase.displayStatus {
        case .completed(let confidence):
            Text("\(Int(confidence * 100))%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(confidence >= 0.7 ? .green : .orange)
        case .unknown:
            Text("Unknown")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        case .skipped:
            Text("Skipped")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
    
    private func methodColor(_ method: String) -> Color {
        switch method {
        case "AI": return .purple
        case "Hybrid": return .blue
        case "Code": return .green
        default: return .gray
        }
    }
}

private struct IssueCard: View {
    let issue: ReviewIssue
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignConstants.Spacing.md) {
            Image(systemName: severityIcon)
                .font(.system(size: 16))
                .foregroundColor(severityColor)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(issue.description)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 8) {
                    Text(issue.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let location = issue.location {
                        Text("• \(location)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(DesignConstants.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(severityColor.opacity(0.1))
        .cornerRadius(DesignConstants.CornerRadius.md)
    }
    
    private var severityIcon: String {
        switch issue.severity {
        case .critical: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    private var severityColor: Color {
        switch issue.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

private struct WarningCard: View {
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignConstants.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignConstants.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(DesignConstants.CornerRadius.md)
    }
}

// MARK: - Preview

#Preview {
    Text("DetailedResultsView requires EvolvedCleaningResult")
        .frame(width: 400, height: 500)
}
