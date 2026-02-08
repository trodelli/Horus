//
//  PhaseAwareProgressView.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: Progress indicator showing evolved pipeline phases
//  with current phase highlighting and confidence display.
//

import SwiftUI

// MARK: - Phase Aware Progress View

/// Progress view showing evolved pipeline phases.
struct PhaseAwareProgressView: View {
    
    let currentPhase: EvolvedPipelinePhase
    let completedPhases: Set<EvolvedPipelinePhase>
    let phaseConfidences: [EvolvedPipelinePhase: Double]
    
    private let phases: [EvolvedPipelinePhase] = [
        .reconnaissance,
        .boundaryDetection,
        .cleaning,
        .optimization,
        .finalReview,
        .complete
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Pipeline Progress")
                    .font(.headline)
                Spacer()
                if currentPhase != .complete {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            // Phase list
            ForEach(phases.dropLast(), id: \.self) { phase in
                PhaseRowView(
                    phase: phase,
                    isCurrent: phase == currentPhase,
                    isCompleted: completedPhases.contains(phase),
                    confidence: phaseConfidences[phase]
                )
            }
            
            // Completion indicator
            if currentPhase == .complete {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Pipeline Complete")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Phase Row View

private struct PhaseRowView: View {
    let phase: EvolvedPipelinePhase
    let isCurrent: Bool
    let isCompleted: Bool
    let confidence: Double?
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .frame(width: 20, height: 20)
            
            // Phase name
            Text(phase.rawValue)
                .font(.subheadline)
                .foregroundColor(isCurrent ? .primary : .secondary)
                .fontWeight(isCurrent ? .semibold : .regular)
            
            Spacer()
            
            // Confidence badge
            if let confidence = confidence, isCompleted {
                ConfidenceBadge(confidence: confidence)
            }
            
            // Current indicator
            if isCurrent {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isCurrent ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if isCurrent {
            Image(systemName: "circle.dotted")
                .foregroundColor(.accentColor)
        } else {
            Image(systemName: "circle")
                .foregroundColor(.secondary.opacity(0.5))
        }
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let confidence: Double
    
    private var color: Color {
        switch confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    PhaseAwareProgressView(
        currentPhase: .cleaning,
        completedPhases: [.reconnaissance, .boundaryDetection],
        phaseConfidences: [
            .reconnaissance: 0.85,
            .boundaryDetection: 0.72
        ]
    )
    .frame(width: 300)
    .padding()
}
