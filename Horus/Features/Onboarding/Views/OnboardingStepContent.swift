//
//  OnboardingStepContent.swift
//  Horus
//
//  Created on 28/01/2026.
//
//  Defines the content for each step in the onboarding wizard.
//  Each step has an icon, color accent, title, subtitle, and body content.
//

import SwiftUI

// MARK: - OnboardingStep

/// Represents a single step in the onboarding wizard.
/// Each step explains a key capability of Horus.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case importDocuments = 1
    case ocrProcessing = 2
    case intelligentCleaning = 3
    case libraryExport = 4
    case getStarted = 5
    
    var id: Int { rawValue }
    
    // MARK: - Display Properties
    
    /// SF Symbol name for the step
    var iconName: String {
        switch self {
        case .welcome: return "eye"
        case .importDocuments: return "doc.badge.plus"
        case .ocrProcessing: return "text.viewfinder"
        case .intelligentCleaning: return "sparkles"
        case .libraryExport: return "books.vertical"
        case .getStarted: return "arrow.right.circle.fill"
        }
    }
    
    /// Accent color for the step
    var accentColor: Color {
        switch self {
        case .welcome: return .purple
        case .importDocuments: return .blue
        case .ocrProcessing: return .blue
        case .intelligentCleaning: return .purple
        case .libraryExport: return .green
        case .getStarted: return .orange
        }
    }
    
    /// Main headline for the step
    var title: String {
        switch self {
        case .welcome: return "Welcome to Horus"
        case .importDocuments: return "Import Your Documents"
        case .ocrProcessing: return "Extract Text with Mistral AI"
        case .intelligentCleaning: return "Clean with Claude AI"
        case .libraryExport: return "Review & Export"
        case .getStarted: return "You're Ready to Begin"
        }
    }
    
    /// Subheadline for the step (optional, shown below title)
    var subtitle: String? {
        switch self {
        case .welcome: return "Transform Documents into AI Training Data"
        case .importDocuments: return nil
        case .ocrProcessing: return nil
        case .intelligentCleaning: return nil
        case .libraryExport: return nil
        case .getStarted: return nil
        }
    }
    
    /// Body content lines for the step
    var bodyLines: [OnboardingBodyLine] {
        switch self {
        case .welcome:
            return [
                .paragraph("Horus helps you convert PDFs, images, and text files into clean, structured content optimized for LLM training and RAG systems."),
                .paragraph("Named after the Egyptian god of vision and perception, Horus sees through your documents and transforms them into something more useful.")
            ]
            
        case .importDocuments:
            return [
                .bullet("Drag and drop files directly into Horus"),
                .bullet("Support for PDF, PNG, JPEG, TIFF, Markdown, JSON, and text files"),
                .bullet("Process up to 50 documents in a single session"),
                .bullet("Works with scanned documents, photos, and digital PDFs")
            ]
            
        case .ocrProcessing:
            return [
                .paragraph("Horus uses Mistral's state-of-the-art OCR to extract text from your documents while preserving structure — headings, paragraphs, tables, and formatting are all recognized."),
                .spacer,
                .costInfo("$0.001 per page", detail: "$1 per 1,000 pages"),
                .paragraph("You'll always see estimated costs before processing begins.")
            ]
            
        case .intelligentCleaning:
            return [
                .paragraph("Raw OCR outputs contain artifacts including page numbers, headers, footers, and broken paragraphs. Horus's customizable 14-step cleaning pipeline uses Claude AI to intelligently remove artifacts and noise to optimize your content for AI usage."),
                .spacer,
                .costInfo("~$0.01–0.05 per document", detail: "varies by length"),
                .spacer,
                .presetHeader("Choose from 4 presets:"),
                .preset("Default", description: "Balanced cleaning for most documents"),
                .preset("Training", description: "Aggressive cleaning for LLM data"),
                .preset("Minimal", description: "Light touch, preserve structure"),
                .preset("Scholarly", description: "Academic documents with citations")
            ]
            
        case .libraryExport:
            return [
                .paragraph("Your processed documents live in the Library where you can:"),
                .spacer,
                .bullet("Preview original OCR and cleaned versions side-by-side"),
                .bullet("Export to Markdown, JSON, or plain text"),
                .bullet("Batch export entire collections"),
                .bullet("Copy directly to clipboard"),
                .spacer,
                .paragraph("Perfect for feeding into your AI training pipelines.")
            ]
            
        case .getStarted:
            return [
                .paragraph("To use Horus, you'll need API keys for the AI services:"),
                .spacer,
                .apiRequirement("Mistral API", purpose: "Required for OCR processing"),
                .apiRequirement("Claude API", purpose: "Required for intelligent cleaning"),
                .spacer,
                .paragraph("You can configure these in Settings at any time.")
            ]
        }
    }
    
    /// Whether this is the final step
    var isFinalStep: Bool {
        self == .getStarted
    }
    
    /// Whether this is the first step
    var isFirstStep: Bool {
        self == .welcome
    }
    
    /// Total number of steps
    static var totalSteps: Int {
        allCases.count
    }
    
    /// Next step, if any
    var nextStep: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
    
    /// Previous step, if any
    var previousStep: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

// MARK: - OnboardingBodyLine

/// Represents a line of content in the onboarding step body.
/// Different types render with different styling.
enum OnboardingBodyLine: Identifiable {
    case paragraph(String)
    case bullet(String)
    case spacer
    case costInfo(String, detail: String)
    case presetHeader(String)
    case preset(String, description: String)
    case apiRequirement(String, purpose: String)
    
    var id: String {
        switch self {
        case .paragraph(let text): return "p-\(text.prefix(20))"
        case .bullet(let text): return "b-\(text.prefix(20))"
        case .spacer: return "spacer-\(UUID().uuidString)"
        case .costInfo(let cost, _): return "cost-\(cost)"
        case .presetHeader(let text): return "ph-\(text)"
        case .preset(let name, _): return "preset-\(name)"
        case .apiRequirement(let name, _): return "api-\(name)"
        }
    }
}
