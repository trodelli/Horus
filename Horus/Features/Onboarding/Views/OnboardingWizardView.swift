//
//  OnboardingWizardView.swift
//  Horus
//
//  Created on 28/01/2026.
//
//  Main container for the onboarding wizard.
//  Manages step navigation, progress indicators, and skip/done actions.
//

import SwiftUI

// MARK: - OnboardingWizardView

/// The main onboarding wizard container.
/// Presents a 6-step introduction to Horus capabilities.
struct OnboardingWizardView: View {
    
    // MARK: - Environment
    
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// Callback when onboarding is completed (either finished or skipped)
    var onComplete: (() -> Void)?
    
    /// Whether this is being shown from Settings/About (vs first launch)
    var isRevisit: Bool = false
    
    // MARK: - State
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var isTransitioning: Bool = false
    
    // MARK: - Constants
    
    private let windowWidth: CGFloat = 540
    private let windowHeight: CGFloat = 620
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section: Skip button (fixed height)
            topBar
            
            // Middle section: Scrollable step content (flexible)
            scrollableContent
            
            // Bottom section: Progress dots + Navigation buttons (fixed height)
            bottomSection
        }
        .frame(width: windowWidth, height: windowHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Top Bar (Skip Button)
    
    private var topBar: some View {
        HStack {
            Spacer()
            
            if !currentStep.isFinalStep {
                Button("Skip") {
                    completeOnboarding()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.trailing, 24)
            }
        }
        .frame(height: 44)
    }
    
    // MARK: - Scrollable Content
    
    private var scrollableContent: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                OnboardingStepView(step: currentStep)
                    .id(currentStep) // Force view recreation for animations
                    .frame(minHeight: geometry.size.height)
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Progress dots
            progressDots
            
            // Navigation buttons
            navigationButtons
        }
        .padding(.top, 16)
        .padding(.bottom, 28)
    }
    
    // MARK: - Progress Dots
    
    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases) { step in
                Circle()
                    .fill(step == currentStep ? currentStep.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep.rawValue + 1) of \(OnboardingStep.totalSteps)")
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            // Back button (or placeholder)
            if !currentStep.isFirstStep {
                Button("Back") {
                    goToPreviousStep()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                // Invisible placeholder to maintain layout
                Button("Back") { }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .hidden()
            }
            
            Spacer()
            
            // Next/Done buttons
            if currentStep.isFinalStep {
                finalStepButtons
            } else {
                Button("Next") {
                    goToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(currentStep.accentColor)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Final Step Buttons
    
    private var finalStepButtons: some View {
        HStack(spacing: 12) {
            Button("Configure API Keys") {
                completeOnboarding()
                // Navigate to settings after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.selectedTab = .settings
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Button("Start Using Horus") {
                completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
        }
    }
    
    // MARK: - Navigation Actions
    
    private func goToNextStep() {
        guard !isTransitioning, let nextStep = currentStep.nextStep else { return }
        
        isTransitioning = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = nextStep
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTransitioning = false
        }
    }
    
    private func goToPreviousStep() {
        guard !isTransitioning, let previousStep = currentStep.previousStep else { return }
        
        isTransitioning = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = previousStep
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTransitioning = false
        }
    }
    
    private func completeOnboarding() {
        // Only mark as completed if this is first launch (not a revisit from Settings/About)
        if !isRevisit {
            onComplete?()
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview("Onboarding Wizard - Welcome") {
    OnboardingWizardView()
        .environment(AppState(keychainService: MockKeychainService()))
}

#Preview("Onboarding Wizard - Revisit") {
    OnboardingWizardView(isRevisit: true)
        .environment(AppState(keychainService: MockKeychainService()))
}
