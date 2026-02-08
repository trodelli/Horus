//
//  VirtualizedTextView.swift
//  Horus
//
//  Created on 23/01/2026.
//

import SwiftUI

/// A virtualized text view that efficiently renders large documents.
/// Chunks content into paragraphs and uses LazyVStack for on-demand rendering.
/// This prevents SwiftUI from trying to render 70K+ pixel tall layers.
struct VirtualizedTextView: View {
    
    let content: String
    
    /// Maximum characters per chunk to prevent massive text blocks
    private let maxChunkSize: Int = 2000
    
    /// Cached chunks for efficient re-rendering
    private var chunks: [TextDisplayChunk] {
        createChunks(from: content)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(chunks) { chunk in
                    Text(chunk.text)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(chunk.id)
                }
            }
            .padding(20)
        }
    }
    
    /// Split content into manageable chunks by paragraph boundaries
    private func createChunks(from text: String) -> [TextDisplayChunk] {
        guard !text.isEmpty else {
            return []
        }
        
        // Split by double newlines (paragraph breaks) first
        let paragraphs = text.components(separatedBy: "\n\n")
        
        var chunks: [TextDisplayChunk] = []
        var currentChunk = ""
        var chunkIndex = 0
        
        for paragraph in paragraphs {
            let paragraphWithBreak = paragraph + "\n\n"
            
            // If adding this paragraph would exceed chunk size, save current and start new
            if currentChunk.count + paragraphWithBreak.count > maxChunkSize && !currentChunk.isEmpty {
                chunks.append(TextDisplayChunk(id: chunkIndex, text: currentChunk.trimmingCharacters(in: .whitespacesAndNewlines)))
                chunkIndex += 1
                currentChunk = ""
            }
            
            currentChunk += paragraphWithBreak
            
            // If single paragraph exceeds max size, split by lines
            if currentChunk.count > maxChunkSize {
                let lines = currentChunk.components(separatedBy: "\n")
                currentChunk = ""
                
                for line in lines {
                    if currentChunk.count + line.count + 1 > maxChunkSize && !currentChunk.isEmpty {
                        chunks.append(TextDisplayChunk(id: chunkIndex, text: currentChunk.trimmingCharacters(in: .whitespacesAndNewlines)))
                        chunkIndex += 1
                        currentChunk = ""
                    }
                    currentChunk += line + "\n"
                }
            }
        }
        
        // Don't forget the last chunk
        if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(TextDisplayChunk(id: chunkIndex, text: currentChunk.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        return chunks
    }
}

/// A chunk of text with a stable identifier for SwiftUI display
struct TextDisplayChunk: Identifiable {
    let id: Int
    let text: String
}

#Preview {
    VirtualizedTextView(content: """
    # Sample Document
    
    This is a sample document with multiple paragraphs to demonstrate the virtualized text view.
    
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    
    Another paragraph here with more content to show how the chunking works across multiple sections of text.
    
    ## Section Two
    
    More content in section two. This demonstrates how headers and formatting are preserved within the chunks.
    """)
    .frame(width: 600, height: 400)
}
