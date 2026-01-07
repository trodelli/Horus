//
//  QuickProcessingOptionsView.swift
//  Horus
//
//  Created on 07/01/2026.
//

import SwiftUI

/// Collapsible panel for quick access to OCR processing options.
/// Appears in Queue view above the document list, allowing users to
/// adjust settings without navigating to the Settings tab.
struct QuickProcessingOptionsView: View {
    
    // MARK: - Environment
    
    @Environment(AppState.self) private var appState
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var state = appState
        
        DisclosureGroup(
            isExpanded: $state.preferences.showQuickProcessingOptions
        ) {
            optionsContent
                .padding(.top, 8)
                .padding(.bottom, 4)
        } label: {
            Label("Processing Options", systemImage: "slider.horizontal.3")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
    
    // MARK: - Options Content
    
    private var optionsContent: some View {
        @Bindable var state = appState
        
        return Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
            // Row 1: Images and Table Format
            GridRow {
                Toggle("Extract Images", isOn: $state.preferences.includeImagesInOCR)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .help("Include extracted images in OCR results (increases processing time)")
                
                HStack(spacing: 8) {
                    Text("Table Format:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: $state.preferences.tableFormat) {
                        ForEach(TableFormatPreference.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .help("Format for extracted tables in the output")
                }
            }
            
            // Row 2: Headers and Footers
            GridRow {
                Toggle("Extract Headers", isOn: $state.preferences.extractHeaders)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .help("Extract page headers separately from main content")
                
                Toggle("Extract Footers", isOn: $state.preferences.extractFooters)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .help("Extract page footers separately from main content")
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Compact Variant

/// A more compact, inline version of processing options.
/// Useful for tighter spaces or when fewer options are needed.
struct QuickProcessingOptionsCompact: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        HStack(spacing: 16) {
            Toggle("Images", isOn: $state.preferences.includeImagesInOCR)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            
            Divider().frame(height: 14)
            
            HStack(spacing: 4) {
                Text("Tables:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $state.preferences.tableFormat) {
                    ForEach(TableFormatPreference.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 90)
            }
        }
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
}

// MARK: - Preview

#Preview("Quick Options Panel") {
    VStack(spacing: 20) {
        QuickProcessingOptionsView()
            .environment(AppState())
        
        Divider()
        
        QuickProcessingOptionsCompact()
            .environment(AppState())
            .padding()
    }
    .frame(width: 400)
}

#Preview("Expanded State") {
    let state = AppState()
    state.preferences.showQuickProcessingOptions = true
    
    return QuickProcessingOptionsView()
        .environment(state)
        .frame(width: 400)
}
