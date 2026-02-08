//
//  IssueReporterView.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: Quick issue reporting for V3 cleaning pipeline.
//

import SwiftUI
import OSLog

// MARK: - Report Issue Category

enum ReportIssueCategory: String, CaseIterable {
    case quality = "Quality Issue"
    case performance = "Performance"
    case crash = "Crash/Error"
    case ui = "UI Problem"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .quality: return "doc.badge.ellipsis"
        case .performance: return "speedometer"
        case .crash: return "exclamationmark.triangle"
        case .ui: return "rectangle.stack"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Issue Reporter View

/// Quick issue reporting interface.
struct IssueReporterView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: ReportIssueCategory = .quality
    @State private var description: String = ""
    @State private var includeContext: Bool = true
    @State private var submitted: Bool = false
    
    let context: IssueContext?
    var onSubmit: ((ReportIssueCategory, String, IssueContext?) -> Void)?
    
    private let logger = Logger(subsystem: "com.horus.app", category: "IssueReporter")
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Report Issue")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if submitted {
                // Success state
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("Issue Reported")
                        .font(.headline)
                    Text("Thank you for helping improve Horus!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else {
                // Category picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.subheadline.bold())
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ReportIssueCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.subheadline.bold())
                    
                    TextEditor(text: $description)
                        .frame(height: 80)
                        .font(.subheadline)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Context toggle
                Toggle(isOn: $includeContext) {
                    VStack(alignment: .leading) {
                        Text("Include context")
                            .font(.subheadline)
                        Text("Phase, confidence, and warnings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Submit
                Button {
                    submitIssue()
                } label: {
                    Text("Submit Issue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 340)
    }
    
    private func submitIssue() {
        let contextToInclude = includeContext ? context : nil
        logger.info("Issue reported: \(selectedCategory.rawValue) - \(description.prefix(50))...")
        
        onSubmit?(selectedCategory, description, contextToInclude)
        
        // Record telemetry
        PipelineTelemetryService.shared.record(
            eventType: .issueReported,
            data: ["category": selectedCategory.rawValue]
        )
        
        withAnimation {
            submitted = true
        }
    }
}

// MARK: - Issue Context

/// Context data for issue reports.
struct IssueContext: Sendable {
    let currentPhase: EvolvedPipelinePhase?
    let confidence: Double?
    let warnings: [String]
}

// MARK: - Preview

#Preview {
    IssueReporterView(context: nil)
}

