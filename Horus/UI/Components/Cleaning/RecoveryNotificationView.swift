//
//  RecoveryNotificationView.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: Displays when fallback/recovery occurred during pipeline.
//

import SwiftUI

// MARK: - Recovery Notification View

/// Notification banner showing when AI fallback was used.
struct RecoveryNotificationView: View {
    
    let fallbackPhases: [EvolvedPipelinePhase]
    let reason: String?
    var onRetry: (() -> Void)?
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("Fallback Used")
                    .font(.subheadline.bold())
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Summary
            Text("\(fallbackPhases.count) phase(s) used heuristic fallback")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    
                    ForEach(fallbackPhases, id: \.self) { phase in
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(phase.rawValue)
                                .font(.caption)
                        }
                    }
                    
                    if let reason = reason {
                        Text("Reason: \(reason)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    
                    if let onRetry = onRetry {
                        Button(action: onRetry) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry with AI")
                            }
                            .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        RecoveryNotificationView(
            fallbackPhases: [.boundaryDetection],
            reason: "AI service unavailable",
            onRetry: {}
        )
        
        RecoveryNotificationView(
            fallbackPhases: [.reconnaissance, .finalReview],
            reason: nil,
            onRetry: nil
        )
    }
    .frame(width: 300)
    .padding()
}
