//
//  ContentTypeSelectorView.swift
//  Horus
//
//  Created by Claude on 2026-02-03.
//  Updated on 2026-02-04 to match PresetSelectorView pattern.
//
//  Purpose: Content type selector for V3 pipeline.
//  Styled to exactly match PresetSelectorView.
//

import SwiftUI

// MARK: - Content Type Selector View

/// Content type selector styled to match PresetSelectorView.
/// Shows the current content type and allows selection from all available types.
struct ContentTypeSelectorView: View {
    @Bindable var viewModel: CleaningViewModel
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            // Current content type display with expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignConstants.Spacing.sm) {
                    // Content type icon
                    Image(systemName: currentContentType.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.purple)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentContentType.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Text(currentContentType.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Detected indicator (when auto-detect has results)
                    if currentContentType == .autoDetect,
                       let detected = viewModel.detectedContentType {
                        Text("→ \(detected.primaryType.displayName)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
            
            // Expanded content type list
            if isExpanded {
                VStack(spacing: DesignConstants.Spacing.xs) {
                    ForEach(ContentType.allCases) { contentType in
                        ContentTypeOptionRow(
                            contentType: contentType,
                            isSelected: currentContentType == contentType,
                            detectedType: viewModel.detectedContentType,
                            isDisabled: viewModel.isProcessing
                        ) {
                            viewModel.selectedContentType = (contentType == .autoDetect) ? nil : contentType
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }
                    }
                }
                .padding(.top, DesignConstants.Spacing.xs)
            }
        }
    }
    
    private var currentContentType: ContentType {
        viewModel.selectedContentType ?? .autoDetect
    }
}

// MARK: - Content Type Option Row

/// A single content type option in the expanded selector.
/// Styled to match PresetOptionRow.
struct ContentTypeOptionRow: View {
    let contentType: ContentType
    let isSelected: Bool
    let detectedType: ContentTypeFlags?
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
                
                // Content type icon
                Image(systemName: contentType.symbolName)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .purple : .secondary)
                    .frame(width: 16)
                
                // Content type info
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(contentType.displayName)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                        
                        // Show detected badge for auto-detect
                        if contentType == .autoDetect, let detected = detectedType {
                            Text("→ \(detected.primaryType.displayName)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green)
                                .cornerRadius(3)
                        }
                    }
                    
                    Text(contentType.description)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Preview

#Preview("Content Type Selector") {
    ContentTypeSelectorView(viewModel: CleaningViewModel())
        .padding()
        .frame(width: 300)
}
