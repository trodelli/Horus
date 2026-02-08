//
//  BetaFeedbackView.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: Collect user feedback during evolved pipeline beta.
//

import SwiftUI
import OSLog

// MARK: - Beta Feedback View

/// Collects feedback after using the evolved pipeline.
struct BetaFeedbackView: View {
    
    @State private var rating: Int = 0
    @State private var comments: String = ""
    @State private var submitted = false
    
    var onSubmit: ((Int, String) -> Void)?
    var onDismiss: (() -> Void)?
    
    private let logger = Logger(subsystem: "com.horus.app", category: "BetaFeedback")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("Evolved Pipeline Feedback")
                    .font(.headline)
                Spacer()
                
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if submitted {
                // Success state
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("Thank you for your feedback!")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Rating
                VStack(alignment: .leading, spacing: 8) {
                    Text("How was your experience?")
                        .font(.subheadline)
                    
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(star <= rating ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Comments
                VStack(alignment: .leading, spacing: 4) {
                    Text("Comments (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $comments)
                        .frame(height: 60)
                        .font(.subheadline)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Submit
                Button {
                    submitFeedback()
                } label: {
                    Text("Submit Feedback")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(rating == 0)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func submitFeedback() {
        logger.info("Beta feedback submitted: rating=\(rating), comments=\(comments.prefix(50))...")
        onSubmit?(rating, comments)
        
        withAnimation {
            submitted = true
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        BetaFeedbackView()
        BetaFeedbackView()
    }
    .frame(width: 350)
    .padding()
}
