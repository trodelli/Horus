//
//  CleaningExplainerContent.swift
//  Horus
//
//  Created on 27/01/2026.
//  Updated on 04/02/2026 for V3 Evolved Pipeline.
//
//  Static content for the Cleaning Explainer Sheet.
//  Provides plain-language descriptions of the V3 Evolved Pipeline phases
//  and the configurable cleaning steps.
//

import Foundation

// MARK: - Step Explanation Model

/// Content for explaining a single cleaning step.
struct StepExplanation: Identifiable {
    let id: Int  // Display order number (1-16 in V3)
    let name: String
    let method: String  // "AI", "Hybrid", or "Code"
    let methodDescription: String  // Explains what the method means
    let description: String  // Plain language description (2-3 sentences)
    let example: String  // Concrete example of what gets removed/changed
    let tip: String  // Actionable guidance
}

// MARK: - Phase Explanation Model

/// Content for explaining a pipeline phase (group of steps).
struct PhaseExplanation: Identifiable {
    let id: Int  // Phase number
    let name: String
    let description: String  // Brief description of the phase's purpose
    let steps: [StepExplanation]
}

// MARK: - Explainer Content

/// Static content for the Cleaning Explainer Sheet.
/// Provides plain-language descriptions of each cleaning step.
enum CleaningExplainerContent {
    
    // MARK: - Introduction
    
    static let title = "Understanding the Cleaning Pipeline"
    
    static let introduction = """
    Horus uses a 16-step pipeline to transform raw OCR output into clean, structured text. Each step targets specific artifacts and formatting issues that typically appear in scanned documents. Steps marked **AI** use Claude to analyze content intelligently, **Hybrid** steps combine AI detection with code-based removal, and **Code** steps run locally without API calls.
    
    Content Analysis and Final Quality Review are always-on steps that analyze structure and assess output quality. You can enable or disable other steps to customize cleaning for your needs.
    """
    
    // MARK: - Method Descriptions
    
    static let methodDescriptions: [String: String] = [
        "AI": "Uses Claude AI to analyze and process content. Incurs API costs but provides intelligent, context-aware results.",
        "Hybrid": "Claude detects patterns and boundaries, then code efficiently removes the content. Balances intelligence with speed.",
        "Code": "Runs entirely on your device with no API calls. Fast and free, using pattern matching and templates."
    ]
    
    // MARK: - V3 Phase Content
    
    static let phases: [PhaseExplanation] = [
        reconnaissancePhase,
        extractionAnalysisPhase,
        structuralRemovalPhase,
        contentPipelinePhase,
        scholarlyContentPhase,
        backMatterRemovalPhase,
        optimizationAssemblyPhase,
        finalReviewPhase
    ]
    
    // MARK: - Phase 0: Content Analysis (V3 New)
    
    static let reconnaissancePhase = PhaseExplanation(
        id: 0,
        name: "Content Analysis",
        description: "Analyzes document structure to guide downstream phases with intelligent hints.",
        steps: [
            StepExplanation(
                id: 1,
                name: "Content Analysis",
                method: "AI",
                methodDescription: methodDescriptions["AI"]!,
                description: "Analyzes your document structure before cleaning begins. Detects front matter, table of contents, core content boundaries, back matter, and other structural elements. Produces hints that guide all subsequent cleaning steps.",
                example: """
                Detects:
                • Front matter ends at line 45
                • Core content spans lines 46-892
                • Index begins at line 893
                • Content type: Academic prose
                • Citation style: APA format
                """,
                tip: "This step is always enabled. It provides essential context for accurate boundary detection in all downstream steps. Without it, cleaning steps must make assumptions."
            )
        ]
    )
    
    // MARK: - Phase 1: Metadata Extraction
    
    static let extractionAnalysisPhase = PhaseExplanation(
        id: 1,
        name: "Metadata Extraction",
        description: "Extracts bibliographic metadata and content type information.",
        steps: [
            StepExplanation(
                id: 2,
                name: "Extract Metadata",
                method: "AI",
                methodDescription: methodDescriptions["AI"]!,
                description: "Extracts bibliographic information such as title, author, publisher, and publication date. Also refines content type detection from the reconnaissance phase.",
                example: """
                From a scanned book, extracts:
                • Title: "Pride and Prejudice"
                • Author: "Jane Austen"
                • Publisher: "T. Egerton"
                • Year: "1813"
                • Content Type: "Prose with Dialogue"
                """,
                tip: "This step informs all other steps about your document. Disabling it means other steps won't have metadata context, and the final output won't include a structured header."
            )
        ]
    )
    
    // MARK: - Phase 2: Structural Removal
    
    static let structuralRemovalPhase = PhaseExplanation(
        id: 2,
        name: "Structural Removal",
        description: "Removes navigational and administrative content that served a purpose in print but adds noise to digital text.",
        steps: [
            StepExplanation(
                id: 2,
                name: "Remove Front Matter",
                method: "Hybrid",
                methodDescription: methodDescriptions["Hybrid"]!,
                description: "Removes copyright notices, Library of Congress cataloging data, publisher information, and other boilerplate that typically appears at the beginning of books before the actual content starts.",
                example: """
                Removes content like:
                "© 2020 Publisher Inc. All rights reserved.
                ISBN 978-0-123456-78-9
                Library of Congress Control Number: 2020123456
                Printed in the United States of America
                First Edition: January 2020"
                """,
                tip: "Keep this enabled for most documents. Disable it only if your front matter contains content you want to preserve, such as a meaningful dedication or preface that's mixed with copyright info."
            ),
            StepExplanation(
                id: 3,
                name: "Remove Table of Contents",
                method: "Hybrid",
                methodDescription: methodDescriptions["Hybrid"]!,
                description: "Identifies and removes the table of contents section. While useful for navigation in print, TOCs add redundant text since the actual chapters appear in the document itself.",
                example: """
                Removes sections like:
                "CONTENTS
                Chapter 1: The Beginning .......... 1
                Chapter 2: The Journey ........... 45
                Chapter 3: The Return ............ 89
                Epilogue ........................ 120"
                """,
                tip: "Safe to enable for most books. Disable if your document has a very short or unusual TOC that might be confused with actual content."
            ),
            StepExplanation(
                id: 4,
                name: "Remove Page Numbers",
                method: "Hybrid",
                methodDescription: methodDescriptions["Hybrid"]!,
                description: "Removes standalone page numbers and page markers that appear as OCR artifacts. These are remnants of the original page layout that serve no purpose in flowing digital text.",
                example: """
                Removes patterns like:
                • "42" (standalone number on its own line)
                • "— 42 —"
                • "Page 42"
                • "[42]"
                """,
                tip: "Almost always keep this enabled. Page numbers are rarely meaningful in cleaned text. Disable only if your document uses numbers in unusual ways that might be misidentified."
            ),
            StepExplanation(
                id: 5,
                name: "Remove Headers & Footers",
                method: "Hybrid",
                methodDescription: methodDescriptions["Hybrid"]!,
                description: "Removes running headers and footers that repeat on every page. These typically contain the book title, chapter name, or author name and appear as interruptions in the flowing text.",
                example: """
                Removes repeated text like:
                • "PRIDE AND PREJUDICE" (header on every page)
                • "Jane Austen" (footer on every page)
                • "Chapter 3: The Journey" (chapter header repeated)
                """,
                tip: "Keep enabled for most scanned books. These repetitions break up paragraphs and add significant noise. Disable only if headers/footers contain unique content on each page."
            )
        ]
    )
    
    // MARK: - Phase 3: Content Cleaning
    
    static let contentPipelinePhase = PhaseExplanation(
        id: 3,
        name: "Content Cleaning",
        description: "Repairs and normalizes the actual text content, fixing issues introduced by the scanning and OCR process.",
        steps: [
            StepExplanation(
                id: 6,
                name: "Reflow Paragraphs",
                method: "AI",
                methodDescription: methodDescriptions["AI"]!,
                description: "Merges paragraphs that were split across page breaks back into complete paragraphs. OCR often treats each page as separate, breaking sentences and paragraphs mid-thought. This step intelligently reconnects them.",
                example: """
                Before:
                "The quick brown fox jumped over the
                
                lazy dog and continued running through
                the forest."
                
                After:
                "The quick brown fox jumped over the lazy dog and continued running through the forest."
                """,
                tip: "Essential for most scanned documents. The AI preserves intentional breaks in poetry, code blocks, and dialogue while fixing unintentional page-break splits."
            ),
            StepExplanation(
                id: 7,
                name: "Clean Special Characters",
                method: "Code",
                methodDescription: methodDescriptions["Code"]!,
                description: "Removes Markdown artifacts, expands ligatures (like ﬁ → fi), removes invisible Unicode characters, and normalizes quotation marks. Also cleans common OCR errors like broken words and misread characters.",
                example: """
                Fixes:
                • "ﬁnished" → "finished" (ligature expansion)
                • "don't" → "don't" (smart quote normalization)
                • "Hello\\u200BWorld" → "HelloWorld" (invisible chars)
                • "re-\\ncognize" → "recognize" (broken hyphenation)
                """,
                tip: "Safe for all documents. Runs locally with no API cost. Only disable if you specifically need to preserve special Unicode characters or unconventional formatting."
            )
        ]
    )
    
    // MARK: - Phase 4: Scholarly Content
    
    static let scholarlyContentPhase = PhaseExplanation(
        id: 4,
        name: "Scholarly Content",
        description: "Handles academic apparatus like citations and footnotes. These steps are off by default—enable them when preparing documents for AI training where references add noise rather than value.",
        steps: [
            StepExplanation(
                id: 8,
                name: "Remove Auxiliary Lists",
                method: "Hybrid",
                methodDescription: methodDescriptions["Hybrid"]!,
                description: "Removes supplementary lists that appear near the table of contents, such as List of Figures, List of Tables, List of Abbreviations, List of Contributors, and similar reference lists.",
                example: """
                Removes sections like:
                "LIST OF FIGURES
                Figure 1.1: Market Growth ......... 24
                Figure 2.3: User Demographics ..... 67
                
                LIST OF TABLES
                Table 1: Survey Results ........... 31"
                """,
                tip: "Enable for AI training data preparation. Keep disabled if you're preserving a document for academic reference where these lists provide useful navigation."
            ),
            StepExplanation(
                id: 9,
                name: "Remove Citations",
                method: "Hybrid",
                methodDescription: methodDescriptions["Hybrid"]!,
                description: "Removes inline academic citations in various formats including APA, MLA, IEEE, Chicago, Harvard, and legal citations. These reference markers point to bibliographies but don't contribute to the core content.",
                example: """
                Removes patterns like:
                • "(Smith, 2020)"
                • "(Smith & Jones, 2019, p. 42)"
                • "[1]" or "[1, 2, 5-7]"
                • "(Author et al., 2021)"
                • "Smith (2020) argues..."
                """,
                tip: "Enable when preparing training data—citations add noise for language models. Keep disabled for academic documents where attribution matters, or when you need to preserve the scholarly record."
            ),
            StepExplanation(
                id: 10,
                name: "Remove Footnotes & Endnotes",
                method: "Hybrid",
                methodDescription: methodDescriptions["Hybrid"]!,
                description: "Removes footnote markers (superscript numbers, asterisks, daggers) from the text and removes the corresponding footnote or endnote content sections. Works in two phases: first removes inline markers, then removes note sections.",
                example: """
                Before:
                "The experiment yielded significant results¹ that
                contradicted earlier findings.²
                
                _______________
                ¹ See methodology section for details.
                ² Compare with Smith (2019)."
                
                After:
                "The experiment yielded significant results that
                contradicted earlier findings."
                """,
                tip: "Enable for AI training where footnotes are distracting commentary. Keep disabled for academic work, historical documents, or any text where notes contain valuable supplementary information."
            )
        ]
    )
    
    // MARK: - Phase 5: Back Matter Removal
    
    static let backMatterRemovalPhase = PhaseExplanation(
        id: 5,
        name: "Back Matter Removal",
        description: "Removes reference sections and supplementary content that appears after the main text.",
        steps: [
            StepExplanation(
                id: 11,
                name: "Remove Index",
                method: "Hybrid",
                methodDescription: methodDescriptions["Hybrid"]!,
                description: "Identifies and removes the alphabetical index section typically found at the end of non-fiction books. Indexes are navigational aids for print that become noise in digital text.",
                example: """
                Removes sections like:
                "INDEX
                
                A
                Algorithms, 45-67, 102
                Arrays, 23, 89-91
                
                B
                Binary search, 56-58
                Boolean logic, 12, 34"
                """,
                tip: "Keep enabled for most non-fiction books. Disable if your document doesn't have an index or if the index section might be confused with other alphabetically-organized content."
            ),
            StepExplanation(
                id: 12,
                name: "Remove Back Matter",
                method: "Hybrid",
                methodDescription: methodDescriptions["Hybrid"]!,
                description: "Removes appendices, 'About the Author' sections, acknowledgments, and similar supplementary content. Intelligently preserves epilogues and authored narrative content that concludes the main text.",
                example: """
                Removes:
                • "ABOUT THE AUTHOR
                   John Smith is a professor at..."
                • "ACKNOWLEDGMENTS
                   I would like to thank..."
                • "APPENDIX A: Survey Questions"
                
                Preserves:
                • Epilogues (narrative conclusions)
                • Afterwords by the author
                """,
                tip: "The Training preset enables this aggressively. Default preserves epilogues. Disable entirely if appendices contain content essential to understanding the main text."
            )
        ]
    )
    
    // MARK: - Phase 6: Optimization & Assembly
    
    static let optimizationAssemblyPhase = PhaseExplanation(
        id: 6,
        name: "Optimization & Assembly",
        description: "Prepares the final output by optimizing text structure and adding consistent formatting.",
        steps: [
            StepExplanation(
                id: 13,
                name: "Optimize Paragraph Length",
                method: "AI",
                methodDescription: methodDescriptions["AI"]!,
                description: "Splits very long paragraphs at natural semantic boundaries to improve readability and RAG (Retrieval-Augmented Generation) performance. Respects content type—never splits poetry stanzas, code blocks, or dialogue exchanges.",
                example: """
                A 500-word paragraph might be split into two ~250-word
                paragraphs at a natural transition point:
                
                "...and that concluded the first phase of the experiment.
                
                The second phase began with a new hypothesis..."
                """,
                tip: "The default limit is 250 words. Academic documents use 300 words (longer paragraphs are normal). Children's content automatically uses 150 words. Disable for poetry or when preserving original paragraph structure matters."
            ),
            StepExplanation(
                id: 14,
                name: "Add Document Structure",
                method: "Code",
                methodDescription: methodDescriptions["Code"]!,
                description: "Assembles the final document with a formatted title header, structured metadata block (in YAML, JSON, or Markdown format), optional chapter markers, and an end-of-document marker for reliable parsing.",
                example: """
                Produces:
                "# Pride and Prejudice
                
                ---
                title: Pride and Prejudice
                author: Jane Austen
                publisher: T. Egerton
                year: 1813
                ---
                
                <!-- CHAPTER: 1 -->
                It is a truth universally acknowledged...
                
                ...
                
                --- END OF DOCUMENT ---"
                """,
                tip: "This step creates consistent, parseable output. Choose YAML for most uses, JSON for programmatic processing, or Markdown for human reading. Chapter markers help with long document navigation."
            )
        ]
    )
    
    // MARK: - Phase 8: Final Review (V3 New)
    
    static let finalReviewPhase = PhaseExplanation(
        id: 8,
        name: "Final Quality Review",
        description: "AI-powered quality assessment of the cleaned document.",
        steps: [
            StepExplanation(
                id: 16,
                name: "Final Quality Review",
                method: "AI",
                methodDescription: methodDescriptions["AI"]!,
                description: "Performs AI-powered quality assessment comparing the original and cleaned documents. Detects content loss, formatting issues, and boundary errors. Produces a quality score and recommendations for manual review.",
                example: """
                Quality Assessment:
                • Quality Score: 92%
                • Confidence: High
                • Issues Found: 1 (minor formatting)
                • Recommendation: "Review chapter breaks"
                """,
                tip: "This step is always enabled. It provides confidence that your cleaned document maintains content integrity. High quality scores (90%+) indicate successful cleaning."
            )
        ]
    )
}
