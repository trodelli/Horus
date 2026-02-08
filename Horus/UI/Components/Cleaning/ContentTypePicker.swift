//
//  ContentTypePicker.swift
//  Horus
//
//  Created by Claude on 2026-02-04.
//  Part of V3 Pipeline Integration
//
//  Purpose: Content type selection picker for the evolved cleaning pipeline.
//

import SwiftUI

/// Picker for selecting content type for the V3 cleaning pipeline.
///
/// Allows users to select a content type or use auto-detection.
struct ContentTypePicker: View {
    @Binding var selection: ContentType
    
    var body: some View {
        Menu {
            ForEach(ContentType.allCases) { contentType in
                Button {
                    selection = contentType
                } label: {
                    Label(contentType.displayName, systemImage: contentType.symbolName)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selection.symbolName)
                    .foregroundColor(selection == .autoDetect ? .secondary : .purple)
                Text(selection == .autoDetect ? "Auto" : selection.displayName)
                    .lineLimit(1)
            }
            .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .help("Content Type: \(selection.description)")
    }
}

// MARK: - Compact Variant

/// Compact version for toolbar use.
struct CompactContentTypePicker: View {
    @Binding var selection: ContentType
    
    var body: some View {
        Picker("", selection: $selection) {
            ForEach(ContentType.allCases) { contentType in
                Label(contentType.displayName, systemImage: contentType.symbolName)
                    .tag(contentType)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 140)
    }
}

// MARK: - Preview

#Preview("Content Type Picker") {
    VStack(spacing: 20) {
        ContentTypePicker(selection: .constant(.autoDetect))
        ContentTypePicker(selection: .constant(.academic))
        ContentTypePicker(selection: .constant(.poetry))
        
        Divider()
        
        CompactContentTypePicker(selection: .constant(.autoDetect))
    }
    .padding()
    .frame(width: 300)
}
