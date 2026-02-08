//
//  EvolvedPipelineReleaseNotes.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: What's New summary for evolved pipeline GA.
//

import SwiftUI

// MARK: - Evolved Pipeline Release Notes

/// What's New view for evolved pipeline GA.
struct EvolvedPipelineReleaseNotes: View {
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)
                
                Text("What's New in Cleaning")
                    .font(.title.bold())
                
                Text("Evolved Pipeline is Now Default")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureHighlight(
                    icon: "brain",
                    title: "AI-Powered Reconnaissance",
                    description: "Automatically analyzes document structure before cleaning"
                )
                
                FeatureHighlight(
                    icon: "text.book.closed",
                    title: "Smart Boundary Detection",
                    description: "Identifies and handles front/back matter intelligently"
                )
                
                FeatureHighlight(
                    icon: "sparkles",
                    title: "Paragraph Optimization",
                    description: "Reflows and optimizes paragraph lengths for readability"
                )
                
                FeatureHighlight(
                    icon: "checkmark.seal",
                    title: "Quality Review",
                    description: "Automatic quality assessment with confidence scores"
                )
                
                FeatureHighlight(
                    icon: "arrow.uturn.backward.circle",
                    title: "Graceful Fallbacks",
                    description: "Heuristic backup ensures cleaning always succeeds"
                )
            }
            .padding(.horizontal)
            
            Button("Got It") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(32)
        .frame(width: 480)
    }
}

// MARK: - Feature Highlight

private struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EvolvedPipelineReleaseNotes()
}
