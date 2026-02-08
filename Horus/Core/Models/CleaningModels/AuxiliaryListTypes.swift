//
//  AuxiliaryListTypes.swift
//  Horus
//
//  Created by Claude on 2026-01-27.
//
//  Type definitions for Step 4 (Remove Auxiliary Lists).
//  Supports detection and removal of supplementary reference lists
//  that appear in front matter adjacent to the Table of Contents.
//
//  Document History:
//  - 2026-01-27: Initial creation as part of V2 pipeline expansion (11→14 steps)
//

import Foundation

// MARK: - AuxiliaryListType

/// Types of auxiliary lists that can be detected and removed.
///
/// Auxiliary lists are supplementary reference lists that appear in the front
/// matter, typically after the Table of Contents. They provide navigational
/// value in printed books but add noise to AI training data without
/// contributing meaningful content.
///
/// Categories:
/// - **Figure/Illustration Lists**: Visual element references
/// - **Table Lists**: Data table references
/// - **Reference Lists**: Abbreviations, acronyms, contributors
enum AuxiliaryListType: String, Codable, CaseIterable, Identifiable, Sendable {
    
    // MARK: - Figure/Illustration Lists
    
    /// List of Figures - References to figures with page numbers.
    /// Example: "Figure 1.1: Market Growth... 24"
    case figures = "figures"
    
    /// List of Illustrations - Alternative name, often in art/design books.
    /// Example: "Illustration 1: The Castle... 12"
    case illustrations = "illustrations"
    
    /// List of Plates - Photo sections, often in history/art books.
    /// Example: "Plate I: Portrait of the Author... 45"
    case plates = "plates"
    
    /// List of Maps - Geographic references.
    /// Example: "Map 1: Trade Routes... 78"
    case maps = "maps"
    
    /// List of Charts - Data visualizations.
    /// Example: "Chart 3.2: Revenue Trends... 112"
    case charts = "charts"
    
    /// List of Diagrams - Technical illustrations.
    /// Example: "Diagram 2: System Architecture... 56"
    case diagrams = "diagrams"
    
    // MARK: - Table Lists
    
    /// List of Tables - Data table references.
    /// Example: "Table 4.1: Survey Results... 89"
    case tables = "tables"
    
    /// List of Exhibits - Legal/business document attachments.
    /// Example: "Exhibit A: Contract Terms... 102"
    case exhibits = "exhibits"
    
    // MARK: - Reference Lists
    
    /// List of Abbreviations - Acronym definitions.
    /// Example: "API - Application Programming Interface"
    case abbreviations = "abbreviations"
    
    /// List of Acronyms - Similar to abbreviations, formal documents.
    /// Example: "NATO - North Atlantic Treaty Organization"
    case acronyms = "acronyms"
    
    /// List of Symbols - Mathematical or technical symbols.
    /// Example: "α - Alpha coefficient"
    case symbols = "symbols"
    
    /// List of Contributors - Multi-author works.
    /// Example: "John Smith, Chapter 1-3"
    case contributors = "contributors"
    
    /// List of Authors - Anthology or collection works.
    /// Example: "Jane Doe, 'Short Story Title'"
    case authors = "authors"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// Display name for UI.
    var displayName: String {
        switch self {
        case .figures: return "List of Figures"
        case .illustrations: return "List of Illustrations"
        case .plates: return "List of Plates"
        case .maps: return "List of Maps"
        case .charts: return "List of Charts"
        case .diagrams: return "List of Diagrams"
        case .tables: return "List of Tables"
        case .exhibits: return "List of Exhibits"
        case .abbreviations: return "List of Abbreviations"
        case .acronyms: return "List of Acronyms"
        case .symbols: return "List of Symbols"
        case .contributors: return "List of Contributors"
        case .authors: return "List of Authors"
        }
    }
    
    /// Short name for compact display.
    var shortName: String {
        switch self {
        case .figures: return "Figures"
        case .illustrations: return "Illustrations"
        case .plates: return "Plates"
        case .maps: return "Maps"
        case .charts: return "Charts"
        case .diagrams: return "Diagrams"
        case .tables: return "Tables"
        case .exhibits: return "Exhibits"
        case .abbreviations: return "Abbreviations"
        case .acronyms: return "Acronyms"
        case .symbols: return "Symbols"
        case .contributors: return "Contributors"
        case .authors: return "Authors"
        }
    }
    
    /// Category this list type belongs to.
    var category: AuxiliaryListCategory {
        switch self {
        case .figures, .illustrations, .plates, .maps, .charts, .diagrams:
            return .figureIllustration
        case .tables, .exhibits:
            return .table
        case .abbreviations, .acronyms, .symbols, .contributors, .authors:
            return .reference
        }
    }
    
    /// SF Symbol for UI.
    var symbolName: String {
        switch self {
        case .figures: return "photo"
        case .illustrations: return "paintbrush"
        case .plates: return "photo.on.rectangle"
        case .maps: return "map"
        case .charts: return "chart.bar"
        case .diagrams: return "diagram"
        case .tables: return "tablecells"
        case .exhibits: return "doc.badge.plus"
        case .abbreviations: return "textformat.abc"
        case .acronyms: return "character.textbox"
        case .symbols: return "x.squareroot"
        case .contributors: return "person.2"
        case .authors: return "person.text.rectangle"
        }
    }
    
    // MARK: - Multi-Language Labels
    
    /// Common header labels for this list type across supported languages.
    /// Used for detection during boundary analysis.
    var headerLabels: [String] {
        switch self {
        case .figures:
            return [
                // English
                "List of Figures", "Figures", "Figure List",
                // German
                "Abbildungsverzeichnis", "Abbildungen",
                // French
                "Liste des figures", "Table des figures",
                // Spanish
                "Lista de figuras", "Índice de figuras",
                // Italian
                "Elenco delle figure", "Indice delle figure"
            ]
        case .illustrations:
            return [
                "List of Illustrations", "Illustrations",
                "Illustrationsverzeichnis",
                "Liste des illustrations",
                "Lista de ilustraciones",
                "Elenco delle illustrazioni"
            ]
        case .plates:
            return [
                "List of Plates", "Plates",
                "Tafelverzeichnis",
                "Liste des planches",
                "Lista de láminas",
                "Elenco delle tavole"
            ]
        case .maps:
            return [
                "List of Maps", "Maps",
                "Kartenverzeichnis",
                "Liste des cartes",
                "Lista de mapas",
                "Elenco delle mappe"
            ]
        case .charts:
            return [
                "List of Charts", "Charts",
                "Diagrammverzeichnis",
                "Liste des graphiques",
                "Lista de gráficos",
                "Elenco dei grafici"
            ]
        case .diagrams:
            return [
                "List of Diagrams", "Diagrams",
                "Schemaverzeichnis",
                "Liste des diagrammes",
                "Lista de diagramas",
                "Elenco dei diagrammi"
            ]
        case .tables:
            return [
                "List of Tables", "Tables", "Table List",
                "Tabellenverzeichnis", "Tabellen",
                "Liste des tableaux",
                "Lista de tablas", "Índice de tablas",
                "Elenco delle tabelle"
            ]
        case .exhibits:
            return [
                "List of Exhibits", "Exhibits",
                "Anlagenverzeichnis",
                "Liste des pièces",
                "Lista de anexos",
                "Elenco degli allegati"
            ]
        case .abbreviations:
            return [
                "List of Abbreviations", "Abbreviations", "Glossary of Abbreviations",
                "Abkürzungsverzeichnis",
                "Liste des abréviations",
                "Lista de abreviaturas",
                "Elenco delle abbreviazioni"
            ]
        case .acronyms:
            return [
                "List of Acronyms", "Acronyms", "Glossary of Acronyms",
                "Akronymverzeichnis",
                "Liste des acronymes",
                "Lista de acrónimos",
                "Elenco degli acronimi"
            ]
        case .symbols:
            return [
                "List of Symbols", "Symbols", "Nomenclature", "Notation",
                "Symbolverzeichnis",
                "Liste des symboles",
                "Lista de símbolos",
                "Elenco dei simboli"
            ]
        case .contributors:
            return [
                "List of Contributors", "Contributors", "About the Contributors",
                "Autorenverzeichnis", "Beitragende",
                "Liste des contributeurs",
                "Lista de colaboradores",
                "Elenco dei collaboratori"
            ]
        case .authors:
            return [
                "List of Authors", "Authors", "About the Authors",
                "Autorenliste",
                "Liste des auteurs",
                "Lista de autores",
                "Elenco degli autori"
            ]
        }
    }
}

// MARK: - AuxiliaryListCategory

/// Category grouping for auxiliary list types.
enum AuxiliaryListCategory: String, Codable, CaseIterable, Sendable {
    case figureIllustration = "figure_illustration"
    case table = "table"
    case reference = "reference"
    
    var displayName: String {
        switch self {
        case .figureIllustration: return "Figure/Illustration Lists"
        case .table: return "Table Lists"
        case .reference: return "Reference Lists"
        }
    }
    
    var description: String {
        switch self {
        case .figureIllustration:
            return "Lists referencing visual elements (figures, illustrations, maps, etc.)"
        case .table:
            return "Lists referencing data tables and exhibits"
        case .reference:
            return "Lists of abbreviations, acronyms, symbols, and contributors"
        }
    }
    
    /// List types belonging to this category.
    var listTypes: [AuxiliaryListType] {
        AuxiliaryListType.allCases.filter { $0.category == self }
    }
}

// MARK: - AuxiliaryListInfo

/// Information about a detected auxiliary list section.
///
/// Used by Step 4 to track detected lists and their boundaries for removal.
struct AuxiliaryListInfo: Codable, Equatable, Sendable {
    
    /// Type of auxiliary list detected.
    let type: AuxiliaryListType
    
    /// Line number where the list starts (0-indexed).
    let startLine: Int
    
    /// Line number where the list ends (0-indexed, inclusive).
    let endLine: Int
    
    /// Confidence score for this detection (0.0 to 1.0).
    let confidence: Double
    
    /// Optional header text that was detected.
    let headerText: String?
    
    // MARK: - Computed Properties
    
    /// Number of lines in this list section.
    var lineCount: Int {
        endLine - startLine + 1
    }
    
    /// Range of lines covered by this list.
    var lineRange: ClosedRange<Int> {
        startLine...endLine
    }
    
    /// Whether the confidence is sufficient for automatic removal.
    /// Uses 0.7 threshold per spec.
    var hasHighConfidence: Bool {
        confidence >= 0.7
    }
    
    /// Short description for logging/display.
    var shortDescription: String {
        "\(type.shortName) (lines \(startLine)-\(endLine), \(Int(confidence * 100))% confidence)"
    }
}

// MARK: - AuxiliaryListDetectionResult

/// Result of auxiliary list detection for a document.
///
/// Contains all detected auxiliary lists and summary information.
struct AuxiliaryListDetectionResult: Codable, Equatable, Sendable {
    
    /// All auxiliary lists detected in the document.
    let auxiliaryLists: [AuxiliaryListInfo]
    
    /// Total number of lists found.
    let totalListsFound: Int
    
    /// Overall confidence in the detection.
    let confidence: Double
    
    /// Optional notes about the detection.
    let notes: String?
    
    // MARK: - Computed Properties
    
    /// Whether any auxiliary lists were detected.
    var hasAuxiliaryLists: Bool {
        !auxiliaryLists.isEmpty
    }
    
    /// Lists with confidence above the removal threshold.
    var highConfidenceLists: [AuxiliaryListInfo] {
        auxiliaryLists.filter { $0.hasHighConfidence }
    }
    
    /// Total lines that would be removed.
    var totalLinesAffected: Int {
        auxiliaryLists.reduce(0) { $0 + $1.lineCount }
    }
    
    /// Categories of lists found.
    var categoriesFound: Set<AuxiliaryListCategory> {
        Set(auxiliaryLists.map { $0.type.category })
    }
    
    /// Summary for display.
    var summary: String {
        if auxiliaryLists.isEmpty {
            return "No auxiliary lists detected"
        }
        let types = auxiliaryLists.map { $0.type.shortName }.joined(separator: ", ")
        return "\(totalListsFound) list(s) found: \(types)"
    }
    
    // MARK: - Static
    
    /// Empty result when no lists are found.
    static let empty = AuxiliaryListDetectionResult(
        auxiliaryLists: [],
        totalListsFound: 0,
        confidence: 1.0,
        notes: "No auxiliary lists found"
    )
}
