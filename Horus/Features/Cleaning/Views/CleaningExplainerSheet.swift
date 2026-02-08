//
//  CleaningExplainerSheet.swift
//  Horus
//
//  Created on 27/01/2026.
//
//  Modal sheet explaining what each cleaning step does.
//  Simple, educational content about the pipeline steps.
//

import SwiftUI

// MARK: - Cleaning Explainer Sheet

/// Modal sheet that explains what each cleaning step does.
/// Provides educational context to help users understand the pipeline.
struct CleaningExplainerSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    
    /// Tracks which phases are expanded (all expanded by default)
    @State private var expandedPhases: Set<Int> = Set(1...6)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader
            
            Divider()
            
            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.lg) {
                    // Introduction
                    introductionSection
                    
                    // Phase sections
                    ForEach(CleaningExplainerContent.phases) { phase in
                        PhaseSection(
                            phase: phase,
                            isExpanded: expandedPhases.contains(phase.id)
                        ) {
                            togglePhase(phase.id)
                        }
                    }
                    
                    // Bottom padding
                    Spacer()
                        .frame(height: DesignConstants.Spacing.xl)
                }
                .padding(DesignConstants.Spacing.lg)
            }
            
            Divider()
            
            // Footer with close button
            sheetFooter
        }
        .frame(width: 600, height: 800)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.purple)
                    
                    Text(CleaningExplainerContent.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            // Close button
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
    
    // MARK: - Introduction
    
    private var introductionSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            Text(CleaningExplainerContent.introduction)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            
            // Method legend
            HStack(spacing: DesignConstants.Spacing.lg) {
                MethodLegendItem(method: "AI", color: .purple)
                MethodLegendItem(method: "Hybrid", color: .blue)
                MethodLegendItem(method: "Code", color: .green)
            }
            .padding(.top, DesignConstants.Spacing.xs)
        }
        .padding(DesignConstants.Spacing.md)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(DesignConstants.CornerRadius.md)
    }
    
    // MARK: - Footer
    
    private var sheetFooter: some View {
        HStack {
            Spacer()
            
            Text("Press ")
                .foregroundStyle(.tertiary)
            + Text("Esc")
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            + Text(" to close")
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .padding(DesignConstants.Spacing.lg)
    }
    
    // MARK: - Actions
    
    private func togglePhase(_ phaseId: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedPhases.contains(phaseId) {
                expandedPhases.remove(phaseId)
            } else {
                expandedPhases.insert(phaseId)
            }
        }
    }
}

// MARK: - Method Legend Item

/// Small legend item showing what each method badge means.
private struct MethodLegendItem: View {
    let method: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Text(method)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color)
                .cornerRadius(4)
            
            Text(methodHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    private var methodHint: String {
        switch method {
        case "AI": return "API calls"
        case "Hybrid": return "AI + Code"
        case "Code": return "Local only"
        default: return ""
        }
    }
}

// MARK: - Phase Section

/// Collapsible section for a pipeline phase containing steps.
private struct PhaseSection: View {
    let phase: PhaseExplanation
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Phase header (clickable)
            Button(action: onToggle) {
                HStack(spacing: DesignConstants.Spacing.sm) {
                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    
                    // Phase number (simple text)
                    Text("\(phase.id).")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.purple)
                    
                    // Phase name
                    Text(phase.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    // Step count badge
                    Text("\(phase.steps.count) step\(phase.steps.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(DesignConstants.CornerRadius.xs)
                    
                    Spacer()
                }
                .padding(.vertical, DesignConstants.Spacing.sm)
            }
            .buttonStyle(.plain)
            
            // Phase description and steps (when expanded)
            if isExpanded {
                Text(phase.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 38)
                    .padding(.bottom, DesignConstants.Spacing.sm)
                
                VStack(spacing: DesignConstants.Spacing.md) {
                    ForEach(phase.steps) { step in
                        StepExplanationCard(step: step)
                    }
                }
                .padding(.leading, 38)
            }
        }
    }
}

// MARK: - Step Explanation Card

/// Card displaying detailed explanation for a single cleaning step.
private struct StepExplanationCard: View {
    let step: StepExplanation
    
    /// Tracks whether the example is expanded
    @State private var showExample: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            // Step header
            HStack(spacing: DesignConstants.Spacing.sm) {
                // Step number (simple text)
                Text("\(step.id).")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                // Step name
                Text(step.name)
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                // Method badge
                MethodBadge(method: step.method)
            }
            
            // Description
            Text(step.description)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // Example (collapsible)
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showExample.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showExample ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                        Text("Example")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                if showExample {
                    Text(step.example)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(DesignConstants.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .cornerRadius(DesignConstants.CornerRadius.sm)
                }
            }
            
            // Tip
            HStack(alignment: .top, spacing: DesignConstants.Spacing.xs) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                
                Text(step.tip)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignConstants.Spacing.sm)
            .background(Color.yellow.opacity(0.08))
            .cornerRadius(DesignConstants.CornerRadius.sm)
        }
        .padding(DesignConstants.Spacing.md)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(DesignConstants.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.md)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Method Badge

/// Badge showing the processing method for a step.
private struct MethodBadge: View {
    let method: String
    
    var body: some View {
        Text(method)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor)
            .cornerRadius(4)
    }
    
    private var badgeColor: Color {
        switch method {
        case "AI": return .purple
        case "Hybrid": return .blue
        case "Code": return .green
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview("Cleaning Explainer Sheet") {
    CleaningExplainerSheet()
}
