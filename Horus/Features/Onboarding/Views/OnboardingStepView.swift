//
//  OnboardingStepView.swift
//  Horus
//
//  Created on 28/01/2026.
//
//  Reusable view component for rendering a single onboarding step.
//  Handles the visual layout: icon, title, body content with subtle animations.
//

import SwiftUI

// MARK: - OnboardingStepView

/// Renders a single step in the onboarding wizard.
/// Displays the icon, title, subtitle, and body content with consistent styling.
struct OnboardingStepView: View {
    
    let step: OnboardingStep
    
    // MARK: - Animation State
    
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: CGFloat = 0
    @State private var contentOpacity: CGFloat = 0
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 16)
            
            // Icon
            stepIcon
            
            // Title & Subtitle
            titleSection
            
            // Body Content
            bodySection
            
            Spacer(minLength: 24)
        }
        .padding(.horizontal, 32)
        .onAppear {
            animateIn()
        }
    }
    
    // MARK: - Icon
    
    private var stepIcon: some View {
        Image(systemName: step.iconName)
            .font(.system(size: 72, weight: .light))
            .foregroundStyle(step.accentColor)
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(step.title)
                .font(.system(size: 24, weight: .semibold))
                .multilineTextAlignment(.center)
            
            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(contentOpacity)
    }
    
    // MARK: - Body Section
    
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(step.bodyLines) { line in
                bodyLineView(for: line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(contentOpacity)
    }
    
    // MARK: - Body Line Views
    
    @ViewBuilder
    private func bodyLineView(for line: OnboardingBodyLine) -> some View {
        switch line {
        case .paragraph(let text):
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
        case .bullet(let text):
            HStack(alignment: .top, spacing: 10) {
                Text("•")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(step.accentColor)
                
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
        case .spacer:
            Color.clear
                .frame(height: 4)
            
        case .costInfo(let cost, let detail):
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
                
                Text("Cost: ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                +
                Text(cost)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
                +
                Text(" (\(detail))")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            
        case .presetHeader(let text):
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.top, 4)
            
        case .preset(let name, let description):
            HStack(alignment: .top, spacing: 10) {
                Text("•")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(step.accentColor)
                
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                +
                Text(" — \(description)")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
        case .apiRequirement(let name, let purpose):
            HStack(spacing: 10) {
                Image(systemName: name == "Mistral API" ? "doc.text.viewfinder" : "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(name == "Mistral API" ? .orange : .purple)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text(purpose)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Animation
    
    private func animateIn() {
        // Reset state
        iconScale = 0.8
        iconOpacity = 0
        contentOpacity = 0
        
        // Animate icon
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.05)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Animate content
        withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
            contentOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Welcome Step") {
    ScrollView {
        OnboardingStepView(step: .welcome)
    }
    .frame(width: 540, height: 400)
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Import Step") {
    ScrollView {
        OnboardingStepView(step: .importDocuments)
    }
    .frame(width: 540, height: 400)
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("OCR Step") {
    ScrollView {
        OnboardingStepView(step: .ocrProcessing)
    }
    .frame(width: 540, height: 400)
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Cleaning Step") {
    ScrollView {
        OnboardingStepView(step: .intelligentCleaning)
    }
    .frame(width: 540, height: 400)
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Library Step") {
    ScrollView {
        OnboardingStepView(step: .libraryExport)
    }
    .frame(width: 540, height: 400)
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Get Started Step") {
    ScrollView {
        OnboardingStepView(step: .getStarted)
    }
    .frame(width: 540, height: 400)
    .background(Color(nsColor: .windowBackgroundColor))
}
