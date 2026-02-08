# Horus Cleaning Pipeline Evolution

## Part 4: Integration & Implementation

> *"Vision without execution is hallucination."*
> — Thomas Edison

---

**Document Version:** 1.0  
**Created:** 3 February 2026  
**Status:** Definition Phase  
**Scope:** Prompt Architecture, UI Specifications, Test Corpus, Success Metrics, Migration Path

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Prompt Architecture](#2-prompt-architecture)
3. [User Interface Specifications](#3-user-interface-specifications)
4. [Test Corpus Strategy](#4-test-corpus-strategy)
5. [Success Metrics](#5-success-metrics)
6. [Migration Path](#6-migration-path)
7. [Risk Management](#7-risk-management)
8. [Implementation Timeline](#8-implementation-timeline)
9. [Summary & Next Steps](#9-summary--next-steps)

---

## 1. Introduction

### 1.1 Purpose

This document completes the Cleaning Pipeline Evolution specification by defining:

1. **Prompt Architecture** — The AI prompts that power reconnaissance, cleaning, and review phases
2. **User Interface Specifications** — How the evolved pipeline presents itself to users
3. **Test Corpus Strategy** — Documents that validate the implementation
4. **Success Metrics** — How we measure whether the evolution achieved its goals
5. **Migration Path** — The sequence for implementing changes without disrupting existing functionality

This is the bridge from design to implementation—the document that answers "how do we actually build this?"

### 1.2 Implementation Philosophy

**Parallel Construction**
Build the evolved pipeline alongside the existing one. No modifications to working code until the new system proves itself. Users can opt into the new pipeline when ready; the classic pipeline remains available as fallback.

**Incremental Validation**
Each component is validated independently before integration. Prompts are tested in isolation. UI changes are previewed. The test corpus validates behavior before release.

**Reversibility**
Every migration step can be reversed. If problems emerge, we roll back to known-good state. The cost of caution is time; the cost of haste is trust.

**Quality Gates**
No component advances without meeting its success criteria. No phase of migration begins until the previous phase validates. The schedule serves quality, not the reverse.

### 1.3 Document Relationships

This document builds on:
- **Part 1**: Content type taxonomy and phase structure
- **Part 2**: Data schemas (StructureHints, AccumulatedContext)
- **Part 3**: Checkpoint criteria, confidence model, fallback strategies

Together, these four documents form the complete specification for the evolved cleaning pipeline.

---

## 2. Prompt Architecture

### 2.1 Prompt Design Principles

**Structured Output**
All prompts request JSON output with defined schemas. This enables reliable parsing and validation. Prose responses are reserved for user-facing explanations only.

**Constrained Scope**
Each prompt has a single, well-defined purpose. Complex operations decompose into multiple focused prompts rather than monolithic requests.

**Defensive Instructions**
Prompts include explicit constraints against common failure modes: hallucination, over-removal, boundary confusion. The prompt itself is a first line of defense.

**Context Efficiency**
Prompts include only the context necessary for the task. Large documents are chunked strategically. Token budgets are respected.

**Graceful Uncertainty**
Prompts instruct the model to express uncertainty rather than guess. A low-confidence response is more useful than a confident wrong answer.

### 2.2 Reconnaissance Prompts

#### 2.2.1 Structure Analysis Prompt

**Purpose:** Analyze document structure and produce StructureHints.

**Input:**
- Document text (first 5000 tokens for initial analysis)
- User-selected content type (if not auto-detect)

**Output:** JSON conforming to StructureHints schema (partial—regions and patterns)

```
You are a document structure analyst. Your task is to analyze the structure of a document and identify its regions, patterns, and characteristics.

## Your Task

Analyze the following document and identify:
1. Structural regions (front matter, table of contents, core content, bibliography, index, etc.)
2. Patterns (page numbers, headers, footers, citations, footnotes)
3. Content characteristics (dialogue, code blocks, equations, verse structure)

## Document Context

{if user_selected_content_type}
The user has indicated this is a {content_type} document. Use this as guidance but verify against the actual content.
{else}
The content type has not been specified. Detect the most likely type based on content characteristics.
{/if}

## Critical Instructions

1. **Be conservative with boundaries.** If uncertain where a region ends, report a narrower range with lower confidence rather than a wider range that might include core content.

2. **Express uncertainty honestly.** Use confidence scores to indicate reliability. A 0.6 confidence is more useful than a false 0.95.

3. **Look for evidence.** Every region detection should cite specific evidence (header text, formatting patterns, keyword presence).

4. **Protect core content.** When in doubt about whether something is peripheral or core content, assume it's core content.

5. **Report what you observe.** Don't infer regions that aren't evidenced in the text. "Not detected" is a valid answer.

## Output Format

Respond with a JSON object containing:
- `detectedContentType`: The content type you've identified
- `contentTypeConfidence`: Your confidence in that identification (0.0-1.0)
- `regions`: Array of detected regions with type, lineRange, confidence, and evidence
- `patterns`: Object containing detected patterns for page numbers, headers, citations, footnotes
- `contentCharacteristics`: Object describing content properties
- `overallConfidence`: Your overall confidence in this analysis (0.0-1.0)
- `warnings`: Array of any concerns or ambiguities

## Document to Analyze

<document>
{document_text}
</document>

Respond only with the JSON object. No preamble or explanation.
```

#### 2.2.2 Content Type Detection Prompt

**Purpose:** Identify the content type of a document when auto-detect is selected.

**Input:** Document sample (first 2000 tokens)

**Output:** Content type with confidence

```
You are a document classifier. Analyze the following document sample and identify its content type.

## Content Type Categories

1. **proseNonFiction** - Biographies, histories, essays, memoirs, journalism
   - Indicators: Factual tone, real-world references, informative purpose

2. **proseFiction** - Novels, short stories, creative fiction
   - Indicators: Narrative voice, character dialogue, scene descriptions

3. **poetry** - Verse, poems, song lyrics
   - Indicators: Line breaks as content, stanza structure, meter/rhythm

4. **academic** - Scholarly papers, dissertations, research articles
   - Indicators: Abstract, citations, methodology sections, formal tone

5. **scientificTechnical** - Technical documentation, specifications, manuals
   - Indicators: Code blocks, equations, technical terminology, procedures

6. **legal** - Contracts, legal opinions, legislation
   - Indicators: Numbered provisions, defined terms, formal legal language

7. **religiousSacred** - Scripture, religious commentary, spiritual texts
   - Indicators: Verse numbering, traditional language, scriptural references

8. **childrens** - Children's books, educational materials
   - Indicators: Simple vocabulary, short paragraphs, educational focus

9. **dramaScreenplay** - Plays, screenplays, scripts
   - Indicators: Character names followed by dialogue, stage directions

10. **mixed** - Documents that don't fit clearly into one category
    - Use this when multiple types are present or classification is unclear

## Document Sample

<document>
{document_sample}
</document>

## Output Format

Respond with a JSON object:
```json
{
  "contentType": "academic",
  "confidence": 0.85,
  "reasoning": "Brief explanation of classification",
  "alternativeTypes": [
    {"type": "scientificTechnical", "confidence": 0.12}
  ]
}
```

Respond only with the JSON object.
```

#### 2.2.3 Pattern Detection Prompt

**Purpose:** Identify specific patterns (page numbers, citations, footnotes) in the document.

**Input:** Document sample with suspected pattern occurrences highlighted

**Output:** Pattern specifications with regex suggestions

```
You are a pattern analyst. Examine the following document excerpts and identify the patterns used for page numbers, citations, and footnotes.

## Pattern Types to Identify

### Page Numbers
Look for recurring patterns that indicate page numbers:
- Standalone numbers on lines by themselves
- Numbers with decorations (- 1 -, — 2 —, [1], etc.)
- Numbers with prefixes (Page 1, p. 1)

### Citations
Look for in-text reference patterns:
- Author-year: (Smith, 2020), (Smith & Jones, 2019)
- Numbered: [1], [2, 3], (1), (2-4)
- Superscript references: ¹, ², ³

### Footnote Markers
Look for footnote indicator patterns:
- Superscript numbers in running text
- Bracketed numbers: [1], (1)
- Symbols: *, †, ‡

## Document Excerpts

The following excerpts contain suspected pattern instances marked with «brackets»:

<excerpts>
{pattern_excerpts}
</excerpts>

## Output Format

Respond with a JSON object:
```json
{
  "pageNumbers": {
    "detected": true,
    "style": "decoratedArabic",
    "pattern": "^\\s*-\\s*(\\d+)\\s*-\\s*$",
    "confidence": 0.92,
    "samples": ["- 1 -", "- 25 -"]
  },
  "citations": {
    "detected": true,
    "style": "authorYear",
    "pattern": "\\([A-Z][a-z]+,\\s*\\d{4}\\)",
    "confidence": 0.88,
    "samples": ["(Smith, 2020)", "(Jones, 2019)"]
  },
  "footnoteMarkers": {
    "detected": true,
    "style": "superscriptNumber",
    "pattern": null,
    "confidence": 0.75,
    "samples": ["¹", "²"]
  }
}
```

If a pattern is not detected, set `detected: false` and omit other fields.

Respond only with the JSON object.
```

### 2.3 Boundary Detection Prompts

#### 2.3.1 Front Matter Boundary Prompt

**Purpose:** Identify where front matter ends and core content begins.

**Input:** 
- First portion of document (up to 3000 tokens)
- Structure hints (if available)
- Content type

**Output:** Boundary line with confidence

```
You are a document boundary analyst. Your task is to identify where the front matter ends and the core content begins.

## Context

Content Type: {content_type}
Total Document Lines: {total_lines}

{if structure_hints}
## Structure Hints (from prior analysis)

Suggested front matter region: lines {hint_start} to {hint_end}
Hint confidence: {hint_confidence}%

Use these hints as guidance, but verify against the actual content.
{/if}

## What Constitutes Front Matter

Front matter typically includes:
- Title page
- Copyright/publication information
- Dedication
- Epigraph (opening quotation)
- Table of contents
- List of figures/tables
- Preface, foreword, acknowledgments
- Introduction (sometimes—depends on whether it's substantive content)

## What Constitutes Core Content

Core content is the main body of the work:
- For fiction: The narrative begins
- For non-fiction: The substantive argument or exposition begins
- For academic: The first numbered section (often "1. Introduction" that contains actual research content)

## Critical Instructions

1. **When uncertain, be conservative.** If you're not sure whether a section is front matter or core content, assume it's core content.

2. **Look for clear transitions.** A table of contents is clearly front matter. Chapter 1 is clearly core content. The boundary is where these meet.

3. **Distinguish procedural introductions from substantive ones.** A preface describing the book's genesis is front matter. A "Chapter 1: Introduction" that begins the actual argument is core content.

4. **Report confidence honestly.** If the boundary is ambiguous, say so with a lower confidence score.

## Document Text (Beginning)

<document_start>
{document_beginning}
</document_start>

## Output Format

Respond with a JSON object:
```json
{
  "frontMatterEndLine": 52,
  "coreContentStartLine": 53,
  "confidence": 0.88,
  "boundaryEvidence": "Table of Contents ends at line 52. Line 53 begins 'Chapter 1: The Discovery' which starts the narrative.",
  "boundaryType": "clear",
  "warnings": []
}
```

For `boundaryType`, use:
- "clear" - Unambiguous boundary
- "gradual" - Transition spans several lines
- "ambiguous" - Boundary location is uncertain

Respond only with the JSON object.
```

#### 2.3.2 Back Matter Boundary Prompt

**Purpose:** Identify where core content ends and back matter begins.

**Input:**
- Last portion of document (up to 3000 tokens)
- Structure hints (if available)
- Content type

**Output:** Boundary line with confidence

```
You are a document boundary analyst. Your task is to identify where the core content ends and the back matter begins.

## Context

Content Type: {content_type}
Total Document Lines: {total_lines}

{if structure_hints}
## Structure Hints (from prior analysis)

Suggested core content ends: line {hint_end}
Suggested back matter region: lines {back_start} to {back_end}
Hint confidence: {hint_confidence}%

Use these hints as guidance, but verify against the actual content.
{/if}

## What Constitutes Back Matter

Back matter typically includes:
- Appendices
- Endnotes (collected notes section)
- Bibliography / References / Works Cited
- Glossary
- Index
- About the Author
- Colophon (publication details)

## What Constitutes Core Content

Core content is the main body:
- The final chapter or section of the substantive work
- Conclusion or epilogue (these are typically core content)
- Any final narrative or argumentative content

## Critical Instructions

1. **When uncertain, be conservative.** If you're not sure whether a section is core content or back matter, assume it's core content.

2. **Look for clear markers.** "Bibliography", "References", "Index", "Appendix A" are clear back matter signals.

3. **Conclusions are usually core content.** A "Conclusion" chapter that wraps up arguments is core content. A "Notes" section listing references is back matter.

4. **Report confidence honestly.** If the boundary is ambiguous, say so with a lower confidence score.

5. **Identify specific back matter sections.** If you see bibliography, index, appendix—note each separately.

## Document Text (Ending)

<document_end>
{document_ending}
</document_end>

## Output Format

Respond with a JSON object:
```json
{
  "coreContentEndLine": 1150,
  "backMatterStartLine": 1151,
  "confidence": 0.91,
  "boundaryEvidence": "Chapter 12 concludes at line 1150. Line 1151 begins 'REFERENCES' which is clearly bibliography.",
  "boundaryType": "clear",
  "backMatterSections": [
    {"type": "bibliography", "startLine": 1151, "endLine": 1220},
    {"type": "index", "startLine": 1221, "endLine": 1250}
  ],
  "warnings": []
}
```

Respond only with the JSON object.
```

### 2.4 Cleaning Operation Prompts

#### 2.4.1 Paragraph Reflow Prompt

**Purpose:** Reflow paragraphs to remove artificial line breaks while preserving content exactly.

**Input:**
- Text chunk to reflow
- Content type context
- Chapter boundary information (if applicable)

**Output:** Reflowed text with verification data

```
You are a text reflow specialist. Your task is to remove artificial line breaks within paragraphs while preserving the exact content.

## Your Task

The following text has artificial line breaks inserted (typically from PDF extraction or OCR). Remove these line breaks to create flowing paragraphs, while:

1. **Preserving every word exactly.** Do not add, remove, or change any words.
2. **Preserving paragraph boundaries.** Keep intentional paragraph breaks (usually indicated by blank lines or indentation).
3. **Preserving special structures.** Do not merge: headings, list items, poetry lines, dialogue attribution, or code blocks.

## Content Type Context

This is a {content_type} document.
{if content_type == 'poetry'}
WARNING: Poetry line breaks are meaningful. Only join lines that are clearly broken mid-sentence due to extraction issues. When in doubt, preserve the line break.
{/if}
{if content_type == 'dramaScreenplay'}
WARNING: Drama/screenplay formatting is meaningful. Preserve character names on their own lines, stage directions in their formatting.
{/if}

## Critical Instructions

1. **Word count must remain exactly the same.** If your output has a different word count than the input, you have made an error.

2. **Do not "improve" the text.** Your job is only to fix line breaks, not to edit content.

3. **Preserve all punctuation exactly.**

4. **When uncertain whether a line break is artificial or intentional, preserve it.** False preservation is less harmful than false removal.

{if chapter_boundary}
## Chapter Boundary Warning

A chapter boundary exists at line {boundary_line}. Do NOT merge paragraphs across this boundary.
{/if}

## Text to Reflow

<input_text>
{text_chunk}
</input_text>

## Output Format

Respond with a JSON object:
```json
{
  "reflowedText": "The complete reflowed text...",
  "inputWordCount": 523,
  "outputWordCount": 523,
  "paragraphsInput": 12,
  "paragraphsOutput": 8,
  "lineBreaksRemoved": 45,
  "preservedSpecialStructures": ["heading at line 5", "list items at lines 20-25"],
  "warnings": []
}
```

Respond only with the JSON object.
```

#### 2.4.2 Paragraph Optimization Prompt

**Purpose:** Split overly long paragraphs into coherent smaller units.

**Input:**
- Long paragraph text
- Maximum paragraph length (words)
- Content type context

**Output:** Split paragraphs with verification data

```
You are a paragraph optimization specialist. Your task is to split overly long paragraphs into smaller, coherent units while preserving content exactly.

## Your Task

The following paragraph exceeds the maximum length of {max_words} words. Split it into smaller paragraphs at natural topical boundaries.

## Critical Instructions

1. **Word count must remain exactly the same.** Do not add, remove, or change any words.

2. **Split at natural boundaries.** Look for topic shifts, transitional phrases, or logical divisions.

3. **Do not split mid-sentence.** Paragraphs must begin and end at sentence boundaries.

4. **Maintain coherence.** Each resulting paragraph should be a coherent unit, not an arbitrary fragment.

5. **Prefer fewer splits.** Only split where there's a genuine topical boundary. Don't create many tiny paragraphs.

6. **If no good split point exists, say so.** Some long paragraphs are legitimately unified. Report that you couldn't find a natural split.

## Content Type Context

This is a {content_type} document.
Maximum paragraph length: {max_words} words

## Paragraph to Optimize

<input_paragraph>
{paragraph_text}
</input_paragraph>

Current word count: {current_word_count}

## Output Format

Respond with a JSON object:
```json
{
  "optimizedParagraphs": [
    "First paragraph text...",
    "Second paragraph text..."
  ],
  "inputWordCount": 412,
  "outputWordCount": 412,
  "splitCount": 2,
  "splitRationale": "Split after discussion of methodology, before results analysis.",
  "couldNotSplit": false,
  "warnings": []
}
```

If no good split point exists:
```json
{
  "optimizedParagraphs": ["Original paragraph unchanged..."],
  "inputWordCount": 412,
  "outputWordCount": 412,
  "splitCount": 0,
  "couldNotSplit": true,
  "splitRationale": "Paragraph discusses a single unified topic with no natural division points.",
  "warnings": []
}
```

Respond only with the JSON object.
```

### 2.5 Final Review Prompt

**Purpose:** AI quality assessment of the cleaned document.

**Input:**
- Original document summary (first/last 1000 tokens)
- Cleaned document summary (first/last 1000 tokens)
- Accumulated context summary
- Checkpoint results summary

**Output:** Quality assessment with pass/fail

```
You are a document cleaning quality reviewer. Your task is to assess whether the cleaning process produced a good result.

## Context

### Original Document Summary
- Total words: {original_words}
- Content type: {content_type}
- Structure: {structure_summary}

### Cleaning Operations Performed
{operations_summary}

### Checkpoint Results
{checkpoint_summary}

## Documents to Compare

### Original (Beginning)
<original_beginning>
{original_beginning}
</original_beginning>

### Original (Ending)
<original_ending>
{original_ending}
</original_ending>

### Cleaned (Beginning)
<cleaned_beginning>
{cleaned_beginning}
</cleaned_beginning>

### Cleaned (Ending)
<cleaned_ending>
{cleaned_ending}
</cleaned_ending>

## Assessment Criteria

1. **Content Preservation**: Does the cleaned document retain the substantive content?

2. **Structure Coherence**: Does the cleaned document have logical structure (beginning, middle, end)?

3. **Appropriate Removal**: Were the removed elements (front matter, citations, etc.) appropriate to remove?

4. **No Obvious Errors**: Are there visible problems (truncated sentences, merged chapters, etc.)?

## Output Format

Respond with a JSON object:
```json
{
  "overallPassed": true,
  "contentPreservation": {
    "passed": true,
    "assessment": "Core narrative content is preserved. Removed elements appear to be front/back matter."
  },
  "structureCoherence": {
    "passed": true,
    "assessment": "Document begins with chapter content and ends with final chapter. No orphaned sections."
  },
  "appropriateRemoval": {
    "passed": true,
    "assessment": "Removed table of contents, bibliography, and index—appropriate for the cleaning configuration."
  },
  "noObviousErrors": {
    "passed": true,
    "assessment": "No truncated sentences or visible artifacts detected."
  },
  "summary": "Cleaning appears successful. Document is ready for use.",
  "concerns": [],
  "recommendedAction": "approve"
}
```

For `recommendedAction`, use:
- "approve" - Document is ready
- "review" - User should review before accepting
- "reject" - Significant problems detected

Respond only with the JSON object.
```

### 2.6 Prompt Management

#### 2.6.1 Prompt Versioning

```swift
/// Prompt management with versioning.
struct PromptManager {
    
    /// Prompt identifiers
    enum PromptType: String {
        case structureAnalysis = "structure_analysis_v1"
        case contentTypeDetection = "content_type_v1"
        case patternDetection = "pattern_detection_v1"
        case frontMatterBoundary = "front_matter_boundary_v1"
        case backMatterBoundary = "back_matter_boundary_v1"
        case paragraphReflow = "paragraph_reflow_v1"
        case paragraphOptimization = "paragraph_optimization_v1"
        case finalReview = "final_review_v1"
    }
    
    /// Get prompt template for a given type
    func getPrompt(_ type: PromptType) -> PromptTemplate {
        // Load from embedded resources
        PromptTemplate.load(identifier: type.rawValue)
    }
    
    /// Build prompt with parameters
    func buildPrompt(_ type: PromptType, parameters: [String: Any]) -> String {
        let template = getPrompt(type)
        return template.render(with: parameters)
    }
}

/// Prompt template with variable substitution.
struct PromptTemplate {
    let identifier: String
    let version: String
    let template: String
    let requiredParameters: Set<String>
    let optionalParameters: Set<String>
    
    func render(with parameters: [String: Any]) -> String {
        var result = template
        
        // Substitute required parameters
        for param in requiredParameters {
            guard let value = parameters[param] else {
                fatalError("Missing required parameter: \(param)")
            }
            result = result.replacingOccurrences(of: "{\(param)}", with: String(describing: value))
        }
        
        // Substitute optional parameters
        for param in optionalParameters {
            if let value = parameters[param] {
                result = result.replacingOccurrences(of: "{\(param)}", with: String(describing: value))
            } else {
                // Remove optional blocks
                result = removeOptionalBlock(param, from: result)
            }
        }
        
        return result
    }
}
```

#### 2.6.2 Response Parsing

```swift
/// Parser for AI responses.
struct AIResponseParser {
    
    /// Parse structure hints from AI response
    func parseStructureHints(from response: String) throws -> PartialStructureHints {
        guard let data = response.data(using: .utf8) else {
            throw ParsingError.invalidEncoding
        }
        
        do {
            return try JSONDecoder().decode(PartialStructureHints.self, from: data)
        } catch {
            // Attempt to extract JSON from response if wrapped in other text
            if let extracted = extractJSON(from: response) {
                return try JSONDecoder().decode(PartialStructureHints.self, from: extracted)
            }
            throw ParsingError.invalidJSON(underlying: error)
        }
    }
    
    /// Parse boundary detection from AI response
    func parseBoundaryDetection(from response: String) throws -> BoundaryDetectionResult {
        guard let data = extractJSON(from: response) ?? response.data(using: .utf8) else {
            throw ParsingError.invalidEncoding
        }
        
        return try JSONDecoder().decode(BoundaryDetectionResult.self, from: data)
    }
    
    /// Parse reflow result from AI response
    func parseReflowResult(from response: String) throws -> ReflowResult {
        guard let data = extractJSON(from: response) ?? response.data(using: .utf8) else {
            throw ParsingError.invalidEncoding
        }
        
        return try JSONDecoder().decode(ReflowResult.self, from: data)
    }
    
    /// Extract JSON object from response that may contain surrounding text
    private func extractJSON(from text: String) -> Data? {
        // Find JSON object boundaries
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonString = String(text[start...end])
        return jsonString.data(using: .utf8)
    }
}
```

---

## 3. User Interface Specifications

### 3.1 Content Type Selector

**Location:** Above the cleaning presets in the sidebar

**Purpose:** Allow users to specify or auto-detect content type

```
┌─────────────────────────────────────────────────────────────┐
│  Content Type                                                │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ▼  Auto-Detect                                      │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  ○ Auto-Detect (recommended)                                │
│  ────────────────────────                                   │
│  ○ Prose (Non-Fiction)                                      │
│  ○ Prose (Fiction)                                          │
│  ○ Poetry                                                   │
│  ○ Academic                                                 │
│  ○ Scientific/Technical                                     │
│  ○ Legal                                                    │
│  ○ Religious/Sacred                                         │
│  ○ Children's/Educational                                   │
│  ○ Drama/Screenplay                                         │
│  ○ Mixed Content                                            │
│                                                              │
│  ℹ️ Content type affects which cleaning steps are           │
│     available and how they behave.                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Behavior:**
- Default: Auto-Detect
- When a specific type is selected, presets adjust to show only applicable steps
- Poetry: Disables Reflow Paragraphs, Optimize Paragraph Length
- Drama/Screenplay: Disables Reflow Paragraphs
- Selection persists for the document session

### 3.2 Structure Analysis Results

**Location:** Displayed after reconnaissance, before cleaning begins

**Purpose:** Present confidence assessment and let user decide whether to proceed

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  📊 Document Analysis                                           ✕ Close    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Overall Confidence                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  85%  ████████████████████████████░░░░░░░░                          │   │
│  │        High confidence - cleaning should produce reliable results   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Content Type                                                        │   │
│  │                                                                       │   │
│  │  📚 Academic                                          89% confidence │   │
│  │                                                                       │   │
│  │  ℹ️ Scholarly paper with citations and bibliography                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Document Structure                                                  │   │
│  │                                                                       │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │     1 ┃ █████████  Front Matter (lines 1-35)       92%      │   │   │
│  │  │    36 ┃ ██████     Table of Contents (36-52)       88%      │   │   │
│  │  │    53 ┃ ██████████████████████████████████████████          │   │   │
│  │  │       ┃            Core Content (53-1150)          94%      │   │   │
│  │  │       ┃                                                      │   │   │
│  │  │  1151 ┃ ████████   Bibliography (1151-1220)        91%      │   │   │
│  │  │  1221 ┃ █████ ⚠️   Index (1221-1250)               78%      │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                       │   │
│  │  Total: 1,250 lines • 12,450 words                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Detected Patterns                                                   │   │
│  │                                                                       │   │
│  │  ✓ Page numbers      - N - format                      92%          │   │
│  │  ✓ Citations         Author-Year style (~87)            88%          │   │
│  │  ✓ Footnotes         Superscript numbers (~23)          82%          │   │
│  │  ✓ Chapter headings  Numbered sections                  91%          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ⚠️ Notes                                                            │   │
│  │                                                                       │   │
│  │  • Index region has lower confidence (78%). The boundary at line    │   │
│  │    1221 may not be exact. Review output carefully.                   │   │
│  │                                                                       │   │
│  │  • Document contains 23 footnotes. Current configuration will       │   │
│  │    remove them. Use Scholarly preset to preserve.                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  [ Adjust Settings ]              [ Cancel ]    [ Start Cleaning ]  │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Progress Indicator with Phases

**Location:** Progress window during cleaning

**Purpose:** Show phase-aware progress with confidence tracking

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  🧹 Cleaning Document                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Progress                                                                    │
│  ████████████████████████████████░░░░░░░░░░░░░░░░  68%                      │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Phases                                                              │   │
│  │                                                                       │   │
│  │  ✓ Reconnaissance        Complete               85% confidence      │   │
│  │  ✓ Metadata Extraction   Complete                                    │   │
│  │  ✓ Semantic Cleaning     Complete               88% confidence      │   │
│  │  ► Structural Cleaning   In Progress...                             │   │
│  │    Reference Cleaning    Pending                                     │   │
│  │    Finishing             Pending                                     │   │
│  │    Optimization          Pending                                     │   │
│  │    Assembly              Pending                                     │   │
│  │    Final Review          Pending                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Current Step: Remove Back Matter                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Detecting back matter boundary...                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Running Confidence: 82%  ████████████████░░░░                              │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                       [ Cancel ]                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.4 Recovery Notification

**Location:** Modal overlay when fallback/recovery occurs

**Purpose:** Inform user of recovery action without blocking progress

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ⚠️ Recovery Action                                              ✕ Dismiss │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Phase: Structural Cleaning                                                  │
│  Step: Remove Back Matter                                                    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  What happened                                                       │   │
│  │                                                                       │   │
│  │  AI analysis returned an unexpected boundary position (line 4).      │   │
│  │  This is far from the expected range based on structure analysis.    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Action taken                                                        │   │
│  │                                                                       │   │
│  │  Fell back to heuristic detection, which identified a boundary at    │   │
│  │  line 1151 (consistent with structure analysis).                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Impact                                                              │   │
│  │                                                                       │   │
│  │  • Cleaning continues with heuristic-detected boundary               │   │
│  │  • Confidence reduced from 85% to 78%                                │   │
│  │  • Recommend reviewing output near line 1151                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                              [ Continue ]            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.5 Final Results Summary

**Location:** Displayed when cleaning completes

**Purpose:** Present final confidence and summary of operations

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ✓ Cleaning Complete                                            ✕ Close    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Final Confidence                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  78%  ███████████████████████░░░░░░░░░░░░                           │   │
│  │        Good confidence - output is generally reliable                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Summary                                                             │   │
│  │                                                                       │   │
│  │  Original:    12,450 words  •  1,250 lines                          │   │
│  │  Cleaned:      9,120 words  •    892 lines                          │   │
│  │  Preserved:   73% of content                                         │   │
│  │                                                                       │   │
│  │  ──────────────────────────────────────────────                      │   │
│  │                                                                       │   │
│  │  Removed:                                                            │   │
│  │  • Front matter (35 lines)                                           │   │
│  │  • Table of contents (17 lines)                                      │   │
│  │  • 87 citations                                                      │   │
│  │  • 23 footnotes                                                      │   │
│  │  • Bibliography (70 lines)                                           │   │
│  │  • Index (30 lines)                                                  │   │
│  │  • ~95 page numbers                                                  │   │
│  │                                                                       │   │
│  │  Optimized:                                                          │   │
│  │  • Reflowed paragraphs                                               │   │
│  │  • Split 12 long paragraphs                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ⚠️ Review Notes                                                     │   │
│  │                                                                       │   │
│  │  • 1 recovery action during structural cleaning (heuristic used)     │   │
│  │  • Index boundary had lower confidence - verify lines 890-892        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  [ View Details ]        [ Clean Another ]      [ Done ]            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.6 Detailed Results View

**Purpose:** Expandable view showing all phases, checkpoints, and context

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  📋 Detailed Cleaning Report                                    ✕ Close    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ▼ Phase 0: Reconnaissance                          85% confidence  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Duration: 2.3s                                                      │   │
│  │                                                                       │   │
│  │  Checkpoint: Reconnaissance Quality                                  │   │
│  │  ├─ Structure Detection Confidence     92%  ✓                        │   │
│  │  ├─ Content Type Identification        89%  ✓                        │   │
│  │  ├─ Core Content Region Identified     Yes  ✓                        │   │
│  │  ├─ Structural Boundaries Detected     5    ✓                        │   │
│  │  └─ No Critical Region Conflicts       0    ✓                        │   │
│  │                                                                       │   │
│  │  Result: Passed                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ▶ Phase 1: Metadata Extraction                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ▶ Phase 2: Semantic Cleaning                       88% confidence  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ▼ Phase 3: Structural Cleaning                     78% confidence  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Duration: 4.1s                                                      │   │
│  │                                                                       │   │
│  │  Steps Executed:                                                     │   │
│  │  ├─ Remove Front Matter       35 lines removed     ✓                │   │
│  │  ├─ Remove TOC                17 lines removed     ✓                │   │
│  │  ├─ Remove Index              30 lines removed     ✓                │   │
│  │  └─ Remove Back Matter        70 lines removed     ⚠️ (heuristic)   │   │
│  │                                                                       │   │
│  │  ⚠️ Recovery Event:                                                  │   │
│  │  Step "Remove Back Matter" used heuristic fallback.                  │   │
│  │  AI detection returned invalid boundary (line 4).                    │   │
│  │  Heuristic detected boundary at line 1151.                           │   │
│  │                                                                       │   │
│  │  Checkpoint: Structural Integrity                                    │   │
│  │  ├─ Boundary Positions Valid           4/4  ✓                        │   │
│  │  ├─ Content Verification Passed        90%  ✓                        │   │
│  │  ├─ Core Content Preserved             96%  ✓                        │   │
│  │  ├─ Word Count Change                  -12% ✓                        │   │
│  │  └─ No Chapter Boundaries Crossed      0    ✓                        │   │
│  │                                                                       │   │
│  │  Result: Passed with warnings                                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ▶ Phase 4-8: [collapsed]                                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    [ Export Report ]         [ Close ]              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.7 Helper Sheet Updates

**Updates needed to CleaningStepsHelperView:**

1. **Add Content Type explanations**
2. **Group steps by phase** (with phase headers)
3. **Add confidence indicators** to step descriptions
4. **Document which steps are disabled** for specific content types

---

## 4. Test Corpus Strategy

### 4.1 Corpus Purpose

A well-designed test corpus validates that the evolved pipeline:
- Correctly identifies document structure across content types
- Produces expected cleaning results
- Handles edge cases gracefully
- Maintains or improves on current pipeline quality

### 4.2 Corpus Composition

#### 4.2.1 By Content Type

| Content Type | Document Count | Sources |
|:-------------|:---------------|:--------|
| Prose (Non-Fiction) | 3 | Biography, essay collection, history |
| Prose (Fiction) | 3 | Novel with chapters, short story collection, epistolary |
| Poetry | 2 | Poetry anthology, single long poem |
| Academic | 4 | Journal article, dissertation excerpt, humanities paper, STEM paper |
| Scientific/Technical | 2 | Technical manual, API documentation |
| Legal | 2 | Contract, legal brief |
| Religious/Sacred | 2 | Scripture portion, commentary |
| Children's | 2 | Picture book text, chapter book |
| Drama/Screenplay | 2 | Stage play, screenplay |
| Mixed | 2 | Anthology, textbook with varied content |

**Total: 24 documents**

#### 4.2.2 By Complexity

| Complexity Level | Characteristics | Count |
|:-----------------|:----------------|:------|
| Simple | Clear structure, standard patterns, <5000 words | 6 |
| Moderate | Some ambiguity, mixed patterns, 5000-20000 words | 12 |
| Complex | Ambiguous structure, unusual patterns, >20000 words | 6 |

#### 4.2.3 By Known Challenge

| Challenge Type | Documents Covering |
|:---------------|:-------------------|
| Ambiguous front matter boundary | 3 |
| No clear back matter | 2 |
| Complex citation styles | 4 |
| Mixed footnotes/endnotes | 2 |
| Poetry embedded in prose | 2 |
| Code blocks in narrative | 2 |
| OCR artifacts | 3 |
| Non-standard chapter headings | 2 |

### 4.3 Golden Output Methodology

For each test document:

1. **Human-Verified Golden Output**
   - Manually process document with "correct" results
   - Document every boundary, removal, and transformation decision
   - Create authoritative reference output

2. **Decision Documentation**
   - Why is each boundary where it is?
   - What should be removed vs. preserved?
   - What is the expected word count delta?

3. **Validation Criteria**
   - Structure hints should match documented structure (within tolerance)
   - Final output should match golden output (high similarity)
   - Edge cases should be handled as documented

### 4.4 Test Document Template

```markdown
# Test Document: [Identifier]

## Metadata
- **Filename:** corpus/[content_type]/[identifier].txt
- **Content Type:** [type]
- **Complexity:** [simple/moderate/complex]
- **Word Count:** [count]
- **Line Count:** [count]
- **Source:** [origin]
- **Challenges:** [list of challenges this document tests]

## Expected Structure

### Front Matter
- **Lines:** 1-[n]
- **Contains:** [description]
- **Boundary evidence:** [how we know where it ends]

### Core Content
- **Lines:** [start]-[end]
- **Chapters:** [list with line numbers]
- **Special content:** [code blocks, equations, etc.]

### Back Matter
- **Lines:** [start]-[end]
- **Contains:** [bibliography, index, etc.]
- **Boundary evidence:** [how we know where it starts]

## Expected Patterns

### Page Numbers
- **Style:** [style]
- **Pattern:** [regex]
- **Count:** [estimated]

### Citations
- **Style:** [style]
- **Count:** [estimated]

### Footnotes
- **Style:** [style]
- **Placement:** [inline/endnotes]
- **Count:** [estimated]

## Expected Cleaning Results

### With Standard Preset
- **Words removed:** [count] ([percentage]%)
- **Lines removed:** [count]
- **Regions removed:** [list]
- **Patterns applied:** [list]

### Golden Output
- **File:** corpus/[content_type]/[identifier]_golden.txt
- **Word count:** [count]
- **Key characteristics:** [description]

## Edge Cases / Notes
[Document any special handling required or known challenges]
```

### 4.5 Corpus Maintenance

**Version Control:**
- Corpus files stored in dedicated repository
- Golden outputs versioned alongside source documents
- Changes require review and re-validation

**Evolution:**
- Add documents when new edge cases are discovered
- Update golden outputs when intentional behavior changes
- Retire documents that no longer provide unique testing value

**Automation:**
- Automated comparison between pipeline output and golden output
- Regression detection when outputs diverge
- Metrics tracking over time

---

## 5. Success Metrics

### 5.1 Metric Categories

#### 5.1.1 Quality Metrics

| Metric | Description | Target | Measurement |
|:-------|:------------|:-------|:------------|
| **Structure Detection Accuracy** | Percentage of regions correctly identified | ≥ 85% | Compare detected regions to corpus golden annotations |
| **Boundary Accuracy** | Average distance between detected and actual boundaries | ≤ 5 lines | Line number difference from golden boundaries |
| **False Positive Rate** | Core content incorrectly marked for removal | ≤ 2% | Words flagged for removal that should be preserved |
| **False Negative Rate** | Peripheral content not identified | ≤ 10% | Peripheral content that should have been removed |
| **Pattern Precision** | Patterns match intended content | ≥ 90% | Ratio of correct matches to total matches |
| **Pattern Recall** | Patterns find all intended content | ≥ 85% | Ratio of found instances to actual instances |

#### 5.1.2 Reliability Metrics

| Metric | Description | Target | Measurement |
|:-------|:------------|:-------|:------------|
| **Checkpoint Pass Rate** | Percentage of checkpoints passing without intervention | ≥ 90% | Passed checkpoints / total checkpoints |
| **Fallback Trigger Rate** | Percentage of operations requiring fallback | ≤ 15% | Fallback events / total AI operations |
| **Recovery Success Rate** | Successful recoveries when fallback triggers | ≥ 95% | Successful recoveries / fallback events |
| **Pipeline Completion Rate** | Pipelines completing without halt | ≥ 98% | Completed / initiated |
| **Confidence Calibration** | Correlation between confidence and actual quality | r ≥ 0.7 | Pearson correlation |

#### 5.1.3 Performance Metrics

| Metric | Description | Target | Measurement |
|:-------|:------------|:-------|:------------|
| **Reconnaissance Time** | Time to complete Phase 0 | ≤ 5s for typical document | Wall clock time |
| **Total Pipeline Time** | End-to-end cleaning time | ≤ 2x current pipeline | Wall clock comparison |
| **AI Calls per Document** | Number of AI API calls | ≤ 15 for typical document | Count during processing |
| **Token Usage** | Total tokens consumed | ≤ 50K for typical document | API token count |

#### 5.1.4 User Experience Metrics

| Metric | Description | Target | Measurement |
|:-------|:------------|:-------|:------------|
| **User Override Rate** | Users changing AI decisions | ≤ 20% | Manual adjustments / total decisions |
| **Confidence Understanding** | Users correctly interpreting confidence | ≥ 80% | Survey/usability testing |
| **Time to Review** | User time reviewing results | ≤ current pipeline | Comparative timing |
| **Satisfaction** | User satisfaction with results | ≥ 4.0/5.0 | User feedback |

### 5.2 Measurement Methodology

#### 5.2.1 Automated Testing

```swift
/// Automated corpus testing framework.
struct CorpusTestRunner {
    
    func runFullCorpusSuite() async -> CorpusTestResults {
        var results = CorpusTestResults()
        
        for document in testCorpus.documents {
            let testResult = await testDocument(document)
            results.documentResults.append(testResult)
        }
        
        results.computeAggregateMetrics()
        return results
    }
    
    private func testDocument(_ document: TestDocument) async -> DocumentTestResult {
        // Run pipeline
        let pipelineResult = await cleaningPipeline.process(document.content)
        
        // Compare structure detection
        let structureAccuracy = compareStructure(
            detected: pipelineResult.structureHints,
            golden: document.goldenStructure
        )
        
        // Compare boundaries
        let boundaryAccuracy = compareBoundaries(
            detected: pipelineResult.confirmedBoundaries,
            golden: document.goldenBoundaries
        )
        
        // Compare final output
        let outputSimilarity = compareOutput(
            actual: pipelineResult.cleanedDocument,
            golden: document.goldenOutput
        )
        
        // Record metrics
        return DocumentTestResult(
            documentId: document.identifier,
            structureAccuracy: structureAccuracy,
            boundaryAccuracy: boundaryAccuracy,
            outputSimilarity: outputSimilarity,
            falsePositiveRate: calculateFalsePositives(pipelineResult, document),
            falseNegativeRate: calculateFalseNegatives(pipelineResult, document),
            checkpointsPassed: pipelineResult.context.checkpointResults.filter { $0.result == .passed }.count,
            checkpointsTotal: pipelineResult.context.checkpointResults.count,
            fallbacksTriggered: countFallbacks(pipelineResult),
            processingTime: pipelineResult.duration,
            confidence: pipelineResult.finalConfidence
        )
    }
}
```

#### 5.2.2 Baseline Comparison

Before declaring success, compare evolved pipeline against current pipeline:

```swift
/// A/B comparison between pipelines.
struct PipelineComparison {
    
    func compareOnCorpus() async -> ComparisonResults {
        var results = ComparisonResults()
        
        for document in testCorpus.documents {
            // Run both pipelines
            let classicResult = await classicPipeline.process(document.content)
            let evolvedResult = await evolvedPipeline.process(document.content)
            
            // Compare to golden standard
            let classicScore = scoreAgainstGolden(classicResult, document.goldenOutput)
            let evolvedScore = scoreAgainstGolden(evolvedResult, document.goldenOutput)
            
            results.recordComparison(
                documentId: document.identifier,
                classicScore: classicScore,
                evolvedScore: evolvedScore
            )
        }
        
        return results
    }
}
```

### 5.3 Success Criteria

The evolved pipeline is considered successful when:

1. **Quality**: All quality metrics meet or exceed targets on test corpus
2. **Reliability**: Checkpoint pass rate ≥ 90%, recovery success rate ≥ 95%
3. **Performance**: Processing time ≤ 2x current pipeline
4. **Regression**: No quality regression vs. current pipeline on any corpus document
5. **User Acceptance**: Beta user satisfaction ≥ 4.0/5.0

---

## 6. Migration Path

### 6.1 Migration Principles

**Parallel Operation**
The evolved pipeline runs alongside the current pipeline. Users choose which to use. Both remain available until the evolved pipeline proves itself.

**Incremental Rollout**
Start with opt-in beta, expand to default with opt-out classic mode, eventually deprecate classic mode.

**Reversibility**
Every stage can be reversed. If problems emerge, roll back without data loss or disruption.

**Quality Gates**
Each migration phase requires meeting success criteria before proceeding to the next.

### 6.2 Migration Phases

#### Phase M1: Foundation (Weeks 1-2)

**Scope:**
- Implement data schemas (StructureHints, AccumulatedContext)
- Implement content type model and UI selector
- Create prompt templates
- Set up corpus testing framework

**Deliverables:**
- New Swift files for schemas
- ContentType enum and selector UI
- PromptManager with templates
- CorpusTestRunner framework
- Initial test corpus (5 documents)

**Validation:**
- Schemas serialize/deserialize correctly
- UI selector appears and functions
- Prompts render with parameters
- Test framework runs against sample documents

**Gate:** Schema unit tests pass, UI renders correctly

#### Phase M2: Reconnaissance (Weeks 3-4)

**Scope:**
- Implement Phase 0 reconnaissance service
- Implement structure analysis prompt flow
- Implement Checkpoint 0 (Reconnaissance Quality)
- Create structure analysis results UI

**Deliverables:**
- ReconnaissanceService
- AIStructureAnalyzer
- ReconnaissanceQualityCheckpoint
- StructureAnalysisView

**Validation:**
- Reconnaissance runs on corpus documents
- Structure hints match expected results (≥ 80% accuracy)
- Checkpoint correctly identifies low-confidence documents
- UI displays results clearly

**Gate:** Structure detection accuracy ≥ 80% on test corpus

#### Phase M3: Enhanced Cleaning (Weeks 5-7)

**Scope:**
- Implement phase-aware cleaning flow
- Integrate structure hints into boundary detection
- Implement Checkpoints 2, 3, 4
- Implement fallback mechanisms for cleaning phases

**Deliverables:**
- PhaseAwareCleaningOrchestrator
- Enhanced BoundaryValidator with hints
- SemanticIntegrityCheckpoint, StructuralIntegrityCheckpoint, ReferenceIntegrityCheckpoint
- CleaningFallbackCoordinator

**Validation:**
- Cleaning uses structure hints when available
- Fallback triggers appropriately and recovers
- Checkpoints catch problems
- Quality metrics meet targets

**Gate:** All checkpoint pass rates ≥ 85%, fallback recovery ≥ 90%

#### Phase M4: Optimization & Review (Weeks 8-9)

**Scope:**
- Implement enhanced optimization phases
- Implement Checkpoint 6 (Optimization Integrity)
- Implement Phase 8 (Final Review) with AI assessment
- Implement Checkpoint 8 (Final Quality)

**Deliverables:**
- Enhanced ReflowParagraphsStep with validation
- Enhanced OptimizeParagraphLengthStep with validation
- OptimizationIntegrityCheckpoint
- FinalReviewService
- FinalQualityCheckpoint

**Validation:**
- Optimization respects chapter boundaries
- Word count ratios within tolerance
- Final review provides accurate assessment
- Final confidence correlates with quality

**Gate:** Optimization validation ≥ 95%, confidence calibration r ≥ 0.6

#### Phase M5: Confidence & UI (Weeks 10-11)

**Scope:**
- Implement confidence tracking and display
- Implement progress UI with phases
- Implement recovery notification UI
- Implement detailed results view

**Deliverables:**
- ConfidenceTracker
- PhaseAwareProgressView
- RecoveryNotificationView
- DetailedResultsView

**Validation:**
- Confidence displays correctly throughout pipeline
- Progress shows phase completion
- Recovery notifications are clear and actionable
- Detailed results provide complete audit trail

**Gate:** UI usability testing positive feedback

#### Phase M6: Integration & Beta (Weeks 12-14)

**Scope:**
- Integrate all components into cohesive pipeline
- Implement pipeline switcher (classic/evolved)
- Complete test corpus to 24 documents
- Internal beta testing

**Deliverables:**
- Complete EvolvedCleaningPipeline
- PipelineSwitcher with user preference
- Full test corpus with golden outputs
- Beta feedback collection system

**Validation:**
- End-to-end pipeline runs on all corpus documents
- No regressions vs. classic pipeline
- Internal users report positive experience
- All success metrics meet targets

**Gate:** All success criteria met, internal beta approval

#### Phase M7: Public Beta (Weeks 15-17)

**Scope:**
- Release evolved pipeline as opt-in beta
- Collect user feedback and telemetry
- Address issues discovered in beta
- Refine based on real-world usage

**Deliverables:**
- Beta release with feature flag
- Telemetry dashboard
- Issue tracking and resolution
- Refinements based on feedback

**Validation:**
- Beta users prefer evolved pipeline (≥ 60%)
- No critical issues in production
- Performance acceptable in real-world conditions
- User satisfaction ≥ 4.0/5.0

**Gate:** Beta user satisfaction ≥ 4.0, no critical issues

#### Phase M8: General Availability (Weeks 18-20)

**Scope:**
- Make evolved pipeline default (with classic opt-out)
- Complete documentation updates
- Performance optimization if needed
- Deprecation plan for classic pipeline

**Deliverables:**
- Default pipeline switch
- Updated user documentation
- Helper sheet updates
- Deprecation timeline communication

**Validation:**
- Smooth transition for all users
- Support volume manageable
- Metrics remain positive post-transition

**Gate:** Successful GA rollout, stable metrics

### 6.3 Rollback Procedures

At any phase, if problems emerge:

1. **Immediate:** Revert feature flag to classic pipeline
2. **Assessment:** Analyze what went wrong
3. **Resolution:** Fix issues before re-enabling
4. **Validation:** Re-run validation suite before retry
5. **Communication:** Inform users of status

### 6.4 Code Organization

```
Horus/
├── Core/
│   ├── Models/
│   │   ├── ContentType.swift              # NEW
│   │   ├── StructureHints.swift           # NEW
│   │   ├── AccumulatedContext.swift       # NEW
│   │   └── ... (existing)
│   ├── Services/
│   │   ├── Cleaning/
│   │   │   ├── CleaningService.swift      # Modified to support evolved mode
│   │   │   ├── ClassicCleaningPipeline.swift  # Extracted existing logic
│   │   │   ├── EvolvedCleaningPipeline.swift  # NEW
│   │   │   ├── ReconnaissanceService.swift    # NEW
│   │   │   ├── PhaseOrchestrator.swift        # NEW
│   │   │   └── ... (existing steps)
│   │   ├── Validation/
│   │   │   ├── BoundaryValidator.swift    # Enhanced with hints
│   │   │   ├── ContentVerification.swift  # Existing
│   │   │   ├── CheckpointEvaluator.swift  # NEW
│   │   │   └── ... (existing)
│   │   ├── AI/
│   │   │   ├── PromptManager.swift        # NEW
│   │   │   ├── AIResponseParser.swift     # NEW
│   │   │   └── AIStructureAnalyzer.swift  # NEW
│   │   └── Recovery/
│   │       ├── FallbackCoordinator.swift  # NEW
│   │       └── RecoveryStrategies.swift   # NEW
│   └── Utilities/
│       └── ConfidenceTracker.swift        # NEW
├── Features/
│   └── Cleaning/
│       ├── Views/
│       │   ├── ContentTypeSelectorView.swift  # NEW
│       │   ├── StructureAnalysisView.swift    # NEW
│       │   ├── PhaseProgressView.swift        # NEW
│       │   ├── RecoveryNotificationView.swift # NEW
│       │   ├── DetailedResultsView.swift      # NEW
│       │   └── ... (existing)
│       └── ViewModels/
│           └── CleaningViewModel.swift    # Enhanced
├── Resources/
│   └── Prompts/
│       ├── structure_analysis_v1.txt      # NEW
│       ├── content_type_v1.txt            # NEW
│       └── ... (prompt templates)
└── Tests/
    ├── CorpusTests/
    │   ├── CorpusTestRunner.swift         # NEW
    │   └── TestCorpus/                    # NEW
    │       ├── academic/
    │       ├── fiction/
    │       └── ...
    ├── UnitTests/
    │   ├── StructureHintsTests.swift      # NEW
    │   ├── CheckpointTests.swift          # NEW
    │   └── ...
    └── IntegrationTests/
        └── PipelineComparisonTests.swift  # NEW
```

---

## 7. Risk Management

### 7.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|:-----|:-----------|:-------|:-----------|
| AI response quality varies | High | Medium | Multi-layer validation, fallback strategies |
| Prompts produce inconsistent results | Medium | High | Prompt versioning, extensive testing, structured output |
| Performance degradation | Medium | Medium | Token budget management, parallel operations where possible |
| Edge cases cause failures | High | Low | Graceful degradation, skip-and-preserve strategy |
| Integration complexity | Medium | Medium | Incremental integration, comprehensive testing |

### 7.2 User Experience Risks

| Risk | Likelihood | Impact | Mitigation |
|:-----|:-----------|:-------|:-----------|
| Confidence scores confuse users | Medium | Medium | Clear explanations, visual design, user testing |
| Too much information overwhelms | Medium | Medium | Progressive disclosure, sensible defaults |
| New workflow disrupts habits | Medium | Low | Optional adoption, classic mode fallback |
| False confidence in AI | Low | High | Honest uncertainty communication, review encouragement |

### 7.3 Project Risks

| Risk | Likelihood | Impact | Mitigation |
|:-----|:-----------|:-------|:-----------|
| Scope creep | Medium | Medium | Strict phase boundaries, quality gates |
| Timeline slippage | Medium | Medium | Buffer in schedule, prioritized features |
| Integration with existing code complex | Medium | Medium | Parallel construction, minimal modification |
| Test corpus insufficient | Medium | High | Early corpus development, continuous expansion |

### 7.4 Contingency Plans

**If reconnaissance accuracy is below target:**
- Refine prompts with additional examples
- Add second-pass verification
- Lower confidence threshold to trigger more fallbacks

**If performance is unacceptable:**
- Reduce token usage through smarter chunking
- Parallelize independent operations
- Cache reconnaissance results

**If user feedback is negative:**
- Extend beta period for refinement
- Add more user controls
- Improve documentation and guidance

**If integration proves too complex:**
- Simplify to fewer phases
- Delay non-essential features
- Focus on core value proposition

---

## 8. Implementation Timeline

### 8.1 Timeline Overview

```
Week  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20
      ├──┴──┼──┴──┼──┴──┴──┼──┴──┼──┴──┼──┴──┴──┼──┴──┴──┼──┴──┴──┤
      │ M1  │ M2  │   M3   │ M4  │ M5  │   M6   │   M7   │   M8   │
      │Found│Recon│Enhanced│Opt &│Conf │Integr &│ Public │ General│
      │ation│nais │Cleaning│Revw │& UI │  Beta  │  Beta  │Avail   │
      └─────┴─────┴────────┴─────┴─────┴────────┴────────┴────────┘
```

### 8.2 Milestones

| Milestone | Week | Criteria |
|:----------|:-----|:---------|
| Foundation Complete | 2 | Schemas, UI selector, prompt framework, test runner |
| Reconnaissance Working | 4 | ≥ 80% structure accuracy on corpus |
| Cleaning Enhanced | 7 | Checkpoints pass ≥ 85%, fallback works |
| Full Pipeline | 11 | End-to-end working, confidence displayed |
| Internal Beta | 14 | All metrics met, internal approval |
| Public Beta | 17 | User satisfaction ≥ 4.0 |
| General Availability | 20 | Stable rollout, classic deprecated |

### 8.3 Resource Requirements

**Development:**
- Primary development focus on evolved pipeline
- Testing and corpus development parallel track
- UI/UX refinement based on feedback

**Testing:**
- Automated corpus testing infrastructure
- Manual testing for UX flows
- Beta user coordination

**Documentation:**
- User documentation updates
- Helper sheet revisions
- Technical documentation maintenance

---

## 9. Summary & Next Steps

### 9.1 What This Specification Establishes

Across four documents, we have defined:

**Part 1: Foundation & Taxonomy**
- 10 content types with specific behaviors
- 8-phase pipeline structure
- Step groupings and execution order
- Content-type-aware processing rules

**Part 2: Data Architecture**
- StructureHints schema for reconnaissance output
- AccumulatedContext schema for inter-phase communication
- Data flow between phases
- Persistence and serialization strategy

**Part 3: Validation & Reliability**
- 6 strategic checkpoints with specific criteria
- Confidence calculation model
- Fallback and recovery strategies
- Integration with existing defense architecture

**Part 4: Integration & Implementation**
- AI prompt architecture
- User interface specifications
- Test corpus strategy
- Success metrics and measurement
- Migration path with phases and gates
- Risk management and contingencies

### 9.2 Implementation Priority

The migration phases establish a logical sequence, but within each phase, prioritize:

1. **Core functionality** before edge cases
2. **Validation** before features
3. **Testing** alongside development
4. **User feedback** informing refinement

### 9.3 Immediate Next Steps

1. **Review this specification** for completeness and alignment with your vision
2. **Establish the test corpus** with initial 5 documents and golden outputs
3. **Begin Phase M1** (Foundation) implementation
4. **Set up tracking** for progress and metrics

### 9.4 Success Vision

When this evolution is complete, Horus will:

- **Understand documents** before attempting to clean them
- **Adapt intelligently** to different content types
- **Communicate honestly** about confidence and uncertainty
- **Recover gracefully** when things don't go as expected
- **Provide transparency** into what it's doing and why
- **Maintain reliability** through comprehensive validation
- **Preserve quality** with multiple layers of defense

The pipeline will transform from a sequence of independent operations into a coordinated system where each phase builds on prior understanding. Users will have clearer expectations, better visibility, and more control.

This is not about making the pipeline more complex—it's about making it more intelligent. Complexity lives in the implementation; what users experience is competence.

---

**End of Part 4: Integration & Implementation**

---

## Appendix A: Complete Specification Index

| Document | File | Scope |
|:---------|:-----|:------|
| Part 1: Foundation & Taxonomy | Part1-Foundation-Taxonomy.md | Content types, phases, step organization |
| Part 2: Data Architecture | Part2-Data-Architecture.md | StructureHints, AccumulatedContext schemas |
| Part 3: Validation & Reliability | Part3-Validation-Reliability.md | Checkpoints, confidence, fallbacks |
| Part 4: Integration & Implementation | Part4-Integration-Implementation.md | Prompts, UI, tests, metrics, migration |

---

**End of Cleaning Pipeline Evolution Specification**
