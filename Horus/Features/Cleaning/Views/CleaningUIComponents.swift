//
//  CleaningUIComponents.swift
//  Horus
//
//  Created on 27/01/2026.
//  Updated 2026-02-04: V3 Evolution - Use PipelinePhase for display, remove legacy DisplayPhase
//

import SwiftUI

// MARK: - CleaningStep Display Order Extension

extension CleaningStep {
    
    /// Display order for visual numbering (1-16 based on V3 execution order).
    /// In V3, display order matches execution order (rawValue).
    ///
    /// **V3 Display Order:**
    /// 1. Content Analysis (Reconnaissance)
    /// 2. Extract Metadata
    /// 3. Remove Page Numbers (Semantic)
    /// 4. Remove Headers & Footers (Semantic)
    /// 5. Remove Front Matter (Structural)
    /// 6. Remove Table of Contents (Structural)
    /// 7. Remove Back Matter (Structural)
    /// 8. Remove Index (Structural)
    /// 9. Remove Auxiliary Lists (Reference)
    /// 10. Remove Citations (Reference)
    /// 11. Remove Footnotes & Endnotes (Reference)
    /// 12. Clean Special Characters (Finishing)
    /// 13. Reflow Paragraphs (Optimization)
    /// 14. Optimize Paragraph Length (Optimization)
    /// 15. Add Document Structure (Assembly)
    /// 16. Final Quality Review
    static func displayOrder(for step: CleaningStep) -> Int {
        step.rawValue
    }
    
    /// Display order number for this step.
    var displayOrderNumber: Int {
        rawValue
    }
    
    /// Display phase for this step (uses PipelinePhase).
    var displayPhase: PipelinePhase {
        pipelinePhase
    }
}

// MARK: - PipelinePhase UI Extensions

extension PipelinePhase {
    
    /// Step range string for display.
    var stepRange: String {
        let phaseSteps = containsSteps
        guard let first = phaseSteps.first, let last = phaseSteps.last else { return "" }
        if first == last || phaseSteps.isEmpty {
            if phaseSteps.isEmpty {
                // New phases (recon, final review) with no additional steps
                switch self {
                case .reconnaissance:
                    return "Step 1-2"
                case .finalReview:
                    return "Step 16"
                default:
                    return ""
                }
            }
            return "Step \(first.stepNumber)"
        }
        return "Steps \(first.stepNumber)-\(last.stepNumber)"
    }
}

// MARK: - Preset Selector View

/// Enhanced preset selector with icons, descriptions, and suggested preset indication.
/// Shows the current preset and allows selection from all available presets.
struct PresetSelectorView: View {
    @Bindable var viewModel: CleaningViewModel
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            // Current preset display with expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignConstants.Spacing.sm) {
                    // Preset icon
                    Image(systemName: viewModel.currentPreset.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.purple)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.currentPreset.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Text(viewModel.currentPreset.shortDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Modified indicator
                    if viewModel.configurationModifiedFromPreset {
                        Text("Modified")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(DesignConstants.CornerRadius.xs)
                    }
                    
                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(DesignConstants.Spacing.sm)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(DesignConstants.CornerRadius.md)
                // Fix #4.2: Ensure entire container is tappable
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
            
            // Expanded preset list
            if isExpanded {
                VStack(spacing: DesignConstants.Spacing.xs) {
                    ForEach(PresetType.allCases) { preset in
                        PresetOptionRow(
                            preset: preset,
                            isSelected: viewModel.currentPreset == preset,
                            isSuggested: viewModel.suggestedPreset == preset,
                            isDisabled: viewModel.isProcessing
                        ) {
                            viewModel.applyPreset(preset)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }
                    }
                }
                .padding(.top, DesignConstants.Spacing.xs)
            }
            
            // Suggested preset notification
            if let suggested = viewModel.suggestedPreset,
               suggested != viewModel.currentPreset,
               !isExpanded {
                SuggestedPresetBanner(
                    suggestedPreset: suggested,
                    reason: viewModel.suggestedPresetReason
                ) {
                    viewModel.applySuggestedPreset()
                }
            }
        }
    }
}

// MARK: - Preset Option Row

/// A single preset option in the expanded preset selector.
struct PresetOptionRow: View {
    let preset: PresetType
    let isSelected: Bool
    let isSuggested: Bool
    let isDisabled: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignConstants.Spacing.sm) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .purple : .secondary)
                    .frame(width: 16)
                
                // Preset icon
                Image(systemName: preset.symbolName)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .purple : .secondary)
                    .frame(width: 16)
                
                // Preset info
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(preset.displayName)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                        
                        if isSuggested {
                            Text("Suggested")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green)
                                .cornerRadius(3)
                        }
                    }
                    
                    Text(preset.shortDescription)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, DesignConstants.Spacing.sm)
            .background(isSelected ? Color.purple.opacity(0.1) : Color.clear)
            .cornerRadius(DesignConstants.CornerRadius.sm)
            // Fix #4.2: Ensure entire container is tappable
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Suggested Preset Banner

/// Banner suggesting a better preset based on detected content type.
struct SuggestedPresetBanner: View {
    let suggestedPreset: PresetType
    let reason: String?
    let onApply: () -> Void
    
    var body: some View {
        HStack(spacing: DesignConstants.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Suggested: \(suggestedPreset.displayName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                
                if let reason = reason {
                    Text(reason)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button("Apply", action: onApply)
                .font(.system(size: 10, weight: .medium))
                .buttonStyle(.bordered)
                .controlSize(.mini)
        }
        .padding(DesignConstants.Spacing.sm)
        .background(Color.green.opacity(0.1))
        .cornerRadius(DesignConstants.CornerRadius.sm)
    }
}

// MARK: - Content Type Badge View

/// Badge displaying the detected content type with icon and confidence.
struct ContentTypeBadgeView: View {
    let contentType: ContentTypeFlags
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: contentType.primaryType.symbolName)
                .font(.system(size: 10))
                .foregroundStyle(badgeColor)
            
            Text(contentType.primaryType.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(badgeColor)
            
            if contentType.confidence >= 0.7 {
                // High confidence indicator
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.12))
        .cornerRadius(DesignConstants.CornerRadius.sm)
    }
    
    private var badgeColor: Color {
        switch contentType.primaryType {
        case .prose: return .blue
        case .poetry: return .purple
        case .dialogue: return .orange
        case .technical: return .green
        case .academic: return .indigo
        case .legal: return .brown
        case .childrens: return .pink
        case .religious: return .teal
        case .mixed: return .gray
        }
    }
}

// MARK: - Content Type Detail View

/// Expanded view showing all content type flags.
struct ContentTypeDetailView: View {
    let contentType: ContentTypeFlags
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            // Primary type with confidence
            HStack {
                ContentTypeBadgeView(contentType: contentType)
                
                Spacer()
                
                Text("\(Int(contentType.confidence * 100))% confidence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // Additional flags
            let activeFlags = getActiveFlags()
            if !activeFlags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(activeFlags, id: \.self) { flag in
                        Text(flag)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(DesignConstants.CornerRadius.xs)
                    }
                }
            }
            
            // Notes if present
            if let notes = contentType.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
    }
    
    private func getActiveFlags() -> [String] {
        var flags: [String] = []
        if contentType.hasPoetry { flags.append("Poetry") }
        if contentType.hasDialogue { flags.append("Dialogue") }
        if contentType.hasCode { flags.append("Code") }
        if contentType.isAcademic { flags.append("Academic") }
        if contentType.isLegal { flags.append("Legal") }
        if contentType.isChildrens { flags.append("Children's") }
        if contentType.hasReligiousVerses { flags.append("Religious") }
        if contentType.hasTabularData { flags.append("Tables") }
        if contentType.hasMathematical { flags.append("Math") }
        return flags
    }
}

// MARK: - Pipeline Phase Steps Group

/// Collapsible group of steps for a pipeline phase (V3 UI grouping).
/// Uses step rawValue for display order (V3 order = display order).
struct PipelinePhaseStepsGroup: View {
    let phase: PipelinePhase
    @Bindable var viewModel: CleaningViewModel
    
    @State private var isExpanded = true
    
    /// Steps in this phase (sorted by step number)
    private var phaseSteps: [CleaningStep] {
        CleaningStep.allCases.filter { $0.pipelinePhase == phase }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Phase header (no icon, just text)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignConstants.Spacing.xs) {
                    Text(phase.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    // Enabled count for this phase
                    let enabledInPhase = phaseSteps.filter { viewModel.isStepEnabled($0) }.count
                    Text("\(enabledInPhase)/\(phaseSteps.count)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, DesignConstants.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Steps in this phase
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(phaseSteps, id: \.self) { step in
                        PipelineStepRow(
                            step: step,
                            displayNumber: step.stepNumber,
                            isEnabled: viewModel.isStepEnabled(step),
                            status: viewModel.statusForStep(step),
                            isProcessing: viewModel.isProcessing
                        ) {
                            viewModel.toggleStep(step)
                        }
                    }
                }
                .padding(.leading, DesignConstants.Spacing.sm)
            }
            
            Divider()
                .padding(.vertical, 2)
        }
    }
}

// MARK: - Pipeline Steps Selector View

/// Collapsible container for all pipeline steps, matching the expand/collapse pattern
/// used by `ContentTypeSelectorView` and `PresetSelectorView`.
/// Self-contained view with its own `@State` for smooth animation.
struct PipelineStepsSelectorView: View {
    @Bindable var viewModel: CleaningViewModel
    
    /// Binding to parent's sheet state for "What's New"
    @Binding var showingWhatsNewSheet: Bool
    /// Binding to parent's sheet state for "Learn about Cleaning"
    @Binding var showingExplainerSheet: Bool
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            // Collapsible header button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignConstants.Spacing.sm) {
                    // Section icon
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.purple)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pipeline Steps")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Text("\(viewModel.enabledStepCount) of \(CleaningStep.totalSteps) steps enabled")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Step count badge
                    Text("\(viewModel.enabledStepCount)/\(CleaningStep.totalSteps)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(DesignConstants.CornerRadius.xs)
                    
                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(DesignConstants.Spacing.sm)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(DesignConstants.CornerRadius.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
            
            // Expanded content — uses height-clipping instead of conditional
            // insertion so SwiftUI can smoothly animate the frame height,
            // preventing the abrupt jump of sibling cards below.
            VStack(spacing: DesignConstants.Spacing.xs) {
                // All steps organized by PipelinePhase (V3 visual grouping)
                VStack(spacing: 0) {
                    ForEach(PipelinePhase.allCases) { phase in
                        PipelinePhaseStepsGroup(phase: phase, viewModel: viewModel)
                    }
                }
                
                // Learn about Cleaning buttons
                HStack {
                    Button {
                        showingWhatsNewSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                            Text("What's New")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        showingExplainerSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                            Text("Learn about Cleaning")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, DesignConstants.Spacing.sm)
            }
            .padding(.top, DesignConstants.Spacing.xs)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
        }
    }
}

// MARK: - Legacy Compatibility Typealias
/// Temporary alias for transition period
typealias DisplayPhaseStepsGroup = PipelinePhaseStepsGroup

// MARK: - Pipeline Step Row

/// A toggle row for pipeline steps with step icon, display number, method badge, and toggle.
/// Updated typography: 14pt font, increased spacing.
/// Always-on steps display muted toggles to indicate they cannot be disabled.
struct PipelineStepRow: View {
    let step: CleaningStep
    let displayNumber: Int
    let isEnabled: Bool
    let status: CleaningStepStatus
    let isProcessing: Bool
    let onToggle: () -> Void
    
    /// Whether this step is always on (non-modifiable)
    private var isAlwaysOn: Bool {
        step.isAlwaysEnabled
    }
    
    var body: some View {
        HStack(spacing: DesignConstants.Spacing.sm) {
            // Status indicator (step icon or progress)
            statusIndicator
                .frame(width: 16)
            
            // Display number badge
            Text("\(displayNumber)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 16)
            
            // Step name (13pt for compact display)
            Text(step.displayName)
                .font(.system(size: 13))
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .lineLimit(1)
            
            Spacer()
            
            // Method badge (AI / Hybrid / Code)
            if isEnabled {
                Text(step.processingMethod.shortDisplayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(DesignConstants.CornerRadius.xs)
            }
            
            // Toggle switch - muted for always-on steps
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .disabled(isProcessing || isAlwaysOn)
            .opacity(isAlwaysOn ? 0.5 : 1.0)
        }
        .padding(.vertical, 4)  // Increased from 2pt to 4pt for better spacing
        .padding(.horizontal, DesignConstants.Spacing.xs)
        .background(status == .processing ? Color.purple.opacity(0.1) : Color.clear)
        .cornerRadius(DesignConstants.CornerRadius.sm)
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .pending:
            Image(systemName: step.symbolName)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        case .processing:
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.7)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
        case .skipped:
            Image(systemName: "minus.circle")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        case .cancelled:
            Image(systemName: "stop.circle")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Flow Layout

/// A simple flow layout for arranging items that wrap to new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                let position = result.positions[index]
                subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
            }
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }
        
        return (CGSize(width: totalWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Previews

#Preview("Preset Selector") {
    let vm = CleaningViewModel.preview
    return VStack {
        PresetSelectorView(viewModel: vm)
            .padding()
    }
    .frame(width: 300)
}

#Preview("Content Type Badge") {
    VStack(spacing: 16) {
        ContentTypeBadgeView(contentType: ContentTypeFlags(
            hasPoetry: false,
            hasDialogue: false,
            hasCode: false,
            isAcademic: true,
            isLegal: false,
            isChildrens: false,
            hasReligiousVerses: false,
            hasTabularData: false,
            hasMathematical: false,
            primaryType: .academic,
            confidence: 0.85,
            notes: nil
        ))
        
        ContentTypeBadgeView(contentType: ContentTypeFlags(
            hasPoetry: true,
            hasDialogue: false,
            hasCode: false,
            isAcademic: false,
            isLegal: false,
            isChildrens: false,
            hasReligiousVerses: false,
            hasTabularData: false,
            hasMathematical: false,
            primaryType: .poetry,
            confidence: 0.72,
            notes: nil
        ))
    }
    .padding()
}

#Preview("Pipeline Steps") {
    let vm = CleaningViewModel.preview
    return ScrollView {
        VStack(spacing: 0) {
            ForEach(PipelinePhase.allCases) { phase in
                PipelinePhaseStepsGroup(phase: phase, viewModel: vm)
            }
        }
        .padding()
    }
    .frame(width: 340, height: 600)
}
