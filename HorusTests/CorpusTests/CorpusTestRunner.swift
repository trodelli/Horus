//
//  CorpusTestRunner.swift
//  HorusTests
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Infrastructure for corpus-based testing of the cleaning pipeline.
//  Based on: Part 4, Sections 4.1-4.3 of the specification.
//

import Foundation

// MARK: - Corpus Manifest

/// Metadata for a corpus test document.
struct CorpusManifest: Codable {
    let documentName: String
    let contentType: String
    let description: String
    let sourceAttribution: String
    let wordCount: Int
    let expectedPatterns: ExpectedPatterns
    let testObjective: String
    
    struct ExpectedPatterns: Codable {
        let citations: Bool
        let footnotes: Bool
        let chapterHeadings: Bool
        let pageNumbers: Bool
        let abstractSection: Bool?
        let bibliography: Bool?
        let dialogue: Bool?
        let narrativeStructure: Bool?
        let tables: Bool?
        let bulletedLists: Bool?
        let codeBlocks: Bool?
    }
}

// MARK: - Corpus Document

/// A test document from the corpus.
struct CorpusDocument {
    let category: String            // "academic", "fiction", "mixed"
    let sourceContent: String       // Content  from sample_*.md
   let goldenOutput: String        // Expected cleaned output
    let manifest: CorpusManifest   // Metadata
    let directoryPath: URL         // Path to document directory
}

// MARK: - Comparison Result

/// Result of comparing pipeline output to golden output.
struct ComparisonResult {
    let documentName: String
    let passed: Bool
    let metrics: ComparisonMetrics
    let differences: [ContentDifference]
    
    struct ComparisonMetrics {
        let wordCountDelta: Int           // Difference in word count
        let lineCountDelta: Int           // Difference in line count
        let structuralSimilarity: Double  // 0.0-1.0, how similar is structure
        let contentSimilarity: Double     // 0.0-1.0, how similar is content
    }
    
    struct ContentDifference {
        let type: DifferenceType
        let location: Location
        let expected: String
        let actual: String
        
        enum DifferenceType: String {
            case missingContent
            case extraContent
            case modifiedContent
            case structuralChange
        }
        
        struct Location {
            let lineRange: Range<Int>
            let context: String
        }
    }
}

// MARK: - Corpus Test Runner

/// Manages loading and execution of corpus-based tests.
@MainActor
class CorpusTestRunner {
    
    // MARK: - Properties
    
    private let corpusDirectoryURL: URL
    private var documents: [CorpusDocument] = []
    
    // MARK: - Initialization
    
    init(corpusDirectoryPath: String? = nil) {
        if let path = corpusDirectoryPath {
            self.corpusDirectoryURL = URL(fileURLWithPath: path)
        } else {
            // Default: HorusTests/Testing/Corpus/
            let projectPath = FileManager.default.currentDirectoryPath
            self.corpusDirectoryURL = URL(fileURLWithPath: projectPath)
                .appendingPathComponent("HorusTests/Testing/Corpus")
        }
    }
    
    // MARK: - Corpus Loading
    
    /// Load all corpus documents from the corpus directory.
    func loadCorpus() throws -> [CorpusDocument] {
        documents.removeAll()
        
        let fileManager = FileManager.default
        
        // Get all category directories
        let categoryURLs = try fileManager.contentsOfDirectory(
            at: corpusDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
        
        for categoryURL in categoryURLs {
            let categoryName = categoryURL.lastPathComponent
            
            // Skip README.md if it's treated as a directory somehow
            guard categoryName != "README.md" else { continue }
            
            // Load manifest (now with category prefix)
            let manifestURL = categoryURL.appendingPathComponent("\(categoryName)_manifest.json")
            guard fileManager.fileExists(atPath: manifestURL.path) else {
                print("Warning: No \(categoryName)_manifest.json found in \(categoryName), skipping")
                continue
            }
            
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(CorpusManifest.self, from: manifestData)
            
            // Load source content
            let sourceFiles = try fileManager.contentsOfDirectory(atPath: categoryURL.path)
                .filter { $0.hasPrefix("sample_") && $0.hasSuffix(".md") }
            
            guard let sourceFileName = sourceFiles.first else {
                print("Warning: No sample_.md file found in \(categoryName), skipping")
                continue
            }
            
            let sourceURL = categoryURL.appendingPathComponent(sourceFileName)
            let sourceContent = try String(contentsOf: sourceURL, encoding: .utf8)
            
            // Load golden output (now with category prefix)
            let goldenURL = categoryURL.appendingPathComponent("\(categoryName)_golden_output.md")
            guard fileManager.fileExists(atPath: goldenURL.path) else {
                print("Warning: No \(categoryName)_golden_output.md found in \(categoryName), skipping")
                continue
            }
            
            let goldenOutput = try String(contentsOf: goldenURL, encoding: .utf8)
            
            // Create corpus document
            let document = CorpusDocument(
                category: categoryName,
                sourceContent: sourceContent,
                goldenOutput: goldenOutput,
                manifest: manifest,
                directoryPath: categoryURL
            )
            
            documents.append(document)
        }
        
        return documents
    }
    
    // MARK: - Test Execution
    
    /// Run tests for a specific document (stub for M1 - actual pipeline integration in M2).
    func runTest(document: CorpusDocument) -> ComparisonResult {
        // M1 PLACEHOLDER: Actual pipeline execution will be implemented in M2
        // For now, we just return a mock comparison showing the infrastructure works
        
        let metrics = ComparisonResult.ComparisonMetrics(
            wordCountDelta: 0,
            lineCountDelta: 0,
            structuralSimilarity: 1.0,
            contentSimilarity: 1.0
        )
        
        return ComparisonResult(
            documentName: document.manifest.documentName,
            passed: true,
            metrics: metrics,
            differences: []
        )
    }
    
    /// Run tests for all loaded corpus documents.
    func runAllTests() -> [ComparisonResult] {
        return documents.map { runTest(document: $0) }
    }
    
    // MARK: - Comparison Logic
    
    /// Compare pipeline output to golden output (actual implementation for M2).
    private func compareOutputs(
        actual: String,
        golden: String,
        documentName: String
    ) -> ComparisonResult {
        
        // Word count comparison
        let actualWords = actual.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let goldenWords = golden.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let wordCountDelta = actualWords.count - goldenWords.count
        
        // Line count comparison
        let actualLines = actual.components(separatedBy: .newlines)
        let goldenLines = golden.components(separatedBy: .newlines)
        let lineCountDelta = actualLines.count - goldenLines.count
        
        // Content similarity (simple Levenshtein ratio for M1)
        let contentSimilarity = calculateSimilarity(actual, golden)
        
        // Structural similarity (based on preserved markdown structure)
        let structuralSimilarity = calculateStructuralSimilarity(actual, golden)
        
        // Detect differences
        let differences = detectDifferences(actual: actualLines, golden: goldenLines)
        
        let metrics = ComparisonResult.ComparisonMetrics(
            wordCountDelta: wordCountDelta,
            lineCountDelta: lineCountDelta,
            structuralSimilarity: structuralSimilarity,
            contentSimilarity: contentSimilarity
        )
        
        // Pass if similarity is high and delta is reasonable
        let passed = contentSimilarity >= 0.95 && abs(wordCountDelta) < 50
        
        return ComparisonResult(
            documentName: documentName,
            passed: passed,
            metrics: metrics,
            differences: differences
        )
    }
    
    // MARK: - Similarity Calculations
    
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        // Simple character-level similarity for M1
        let maxLength = max(s1.count, s2.count)
        guard maxLength > 0 else { return 1.0 }
        
        let distance = levenshteinDistance(s1, s2)
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        var matrix = Array(
            repeating: Array(repeating: 0, count: s2Array.count + 1),
            count: s1Array.count + 1
        )
        
        for i in 0...s1Array.count { matrix[i][0] = i }
        for j in 0...s2Array.count { matrix[0][j] = j }
        
        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        
        return matrix[s1Array.count][s2Array.count]
    }
    
    private func calculateStructuralSimilarity(_ actual: String, _ golden: String) -> Double {
        // Count structural markers (headers, lists, etc.)
        let actualHeaders = actual.components(separatedBy: "\n").filter { $0.hasPrefix("#") }
        let goldenHeaders = golden.components(separatedBy: "\n").filter { $0.hasPrefix("#") }
        
        let actualLists = actual.components(separatedBy: "\n").filter { $0.hasPrefix("-") || $0.hasPrefix("•") }
        let goldenLists = golden.components(separatedBy: "\n").filter { $0.hasPrefix("-") || $0.hasPrefix("•") }
        
        let headerDelta = abs(actualHeaders.count - goldenHeaders.count)
        let listDelta = abs(actualLists.count - goldenLists.count)
        
        let totalStructuralElements = max(goldenHeaders.count + goldenLists.count, 1)
        let totalDelta = headerDelta + listDelta
        
        return 1.0 - (Double(totalDelta) / Double(totalStructuralElements))
    }
    
    private func detectDifferences(
        actual: [String],
        golden: [String]
    ) -> [ComparisonResult.ContentDifference] {
        var differences: [ComparisonResult.ContentDifference] = []
        
        // Simple line-by-line comparison (more sophisticated diff in M2)
        let minLength = min(actual.count, golden.count)
        
        for i in 0..<minLength {
            if actual[i] != golden[i] {
                differences.append(
                    ComparisonResult.ContentDifference(
                        type: .modifiedContent,
                        location: ComparisonResult.ContentDifference.Location(
                            lineRange: i..<(i+1),
                            context: "Line \(i+1)"
                        ),
                        expected: golden[i],
                        actual: actual[i]
                    )
                )
            }
        }
        
        // Detect missing/extra lines
        if actual.count < golden.count {
            for i in minLength..<golden.count {
                differences.append(
                    ComparisonResult.ContentDifference(
                        type: .missingContent,
                        location: ComparisonResult.ContentDifference.Location(
                            lineRange: i..<(i+1),
                            context: "Line \(i+1)"
                        ),
                        expected: golden[i],
                        actual: ""
                    )
                )
            }
        } else if actual.count > golden.count {
            for i in minLength..<actual.count {
                differences.append(
                    ComparisonResult.ContentDifference(
                        type: .extraContent,
                        location: ComparisonResult.ContentDifference.Location(
                            lineRange: i..<(i+1),
                            context: "Line \(i+1)"
                        ),
                        expected: "",
                        actual: actual[i]
                    )
                )
            }
        }
        
        return differences
    }
}
