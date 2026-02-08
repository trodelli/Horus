# Horus Test Corpus

## Purpose

This corpus contains curated test documents for validating the evolved cleaning pipeline. Each document represents a distinct content type with characteristic structural patterns that the pipeline must handle correctly.

## Structure

```
Corpus/
├── README.md                    # This file
├── academic/                    # Academic papers
│   ├── sample_paper.md
│   ├── golden_output.md
│   └── manifest.json
├── fiction/                     # Fiction excerpts
│   ├── sample_novel_chapter.md
│   ├── golden_output.md
│   └── manifest.json
└── mixed/                       # Mixed content documents
    ├── sample_mixed.md
    ├── golden_output.md
    └── manifest.json
```

## Document Categories

### Academic
- **Content Type**: `academic`
- **Characteristics**: Citations, footnotes, structured sections, formal tone
- **Test Focus**: Citation handling, footnote preservation, section boundaries

### Fiction
- **Content Type**: `proseFiction`
- **Characteristics**: Dialogue, chapter divisions, narrative flow
- **Test Focus**: Dialogue formatting, chapter recognition, paragraph reflow

### Mixed
- **Content Type**: `mixed`
- **Characteristics**: Multiple content types in one document
- **Test Focus**: Adaptive behavior, section-specific handling

## Manifest Schema

Each document directory contains a `manifest.json` with metadata:

```json
{
  "documentName": "Sample Academic Paper",
  "contentType": "academic",
  "description": "Test document for academic content handling",
  "sourceAttribution": "Public domain / created for testing",
  "wordCount": 2500,
  "expectedPatterns": {
    "citations": true,
    "footnotes": true,
    "chapterHeadings": false,
    "pageNumbers": true
  },
  "testObjective": "Validate citation and footnote preservation"
}
```

## Golden Outputs

Golden outputs represent the **expected result** after the evolved pipeline processes the source document. They are created through:

1. Manual review of pipeline output
2. Careful verification against specification
3. User approval of quality standard

## Usage

Test runner (`CorpusTestRunner.swift`) automatically:
1. Discovers all corpus documents
2. Loads source and golden output pairs
3. Executes cleaning pipeline
4. Compares results using structural diff
5. Reports pass/fail with detailed diagnostics

## Adding New Documents

To add a test document:

1. Create new directory under appropriate category
2. Add `sample_X.md` with source content
3. Run pipeline and verify output quality
4. Save verified output as `golden_output.md`
5. Create `manifest.json` with metadata
6. Run corpus tests to verify integration

## Document Sources

All corpus documents are either:
- Public domain content (Project Gutenberg, etc.)
- Original content created specifically for testing
- Properly attributed with source information in manifest
