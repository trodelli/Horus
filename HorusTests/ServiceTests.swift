//
//  ServiceTests.swift
//  HorusTests
//
//  Unit tests for core services.
//

import XCTest
@testable import Horus

// MARK: - Cost Calculator Tests

final class CostCalculatorTests: XCTestCase {
    
    var calculator: CostCalculator!
    
    override func setUp() {
        super.setUp()
        calculator = CostCalculator.shared
    }
    
    func testCalculateCostSinglePage() {
        let cost = calculator.calculateCost(pages: 1)
        XCTAssertEqual(cost, Decimal(string: "0.001"))
    }
    
    func testCalculateCostMultiplePages() {
        let cost = calculator.calculateCost(pages: 100)
        XCTAssertEqual(cost, Decimal(string: "0.1"))
    }
    
    func testCalculateCostZeroPages() {
        let cost = calculator.calculateCost(pages: 0)
        XCTAssertEqual(cost, Decimal(0))
    }
    
    func testFormatCostWithoutPrefix() {
        let cost = Decimal(string: "0.015")!
        let formatted = calculator.formatCost(cost, includeEstimatePrefix: false)
        
        // Should not have the estimate prefix
        XCTAssertFalse(formatted.hasPrefix("~"), "Should not have estimate prefix when includeEstimatePrefix is false")
        
        // Should be a non-empty currency string (format varies by locale)
        XCTAssertFalse(formatted.isEmpty, "Formatted cost should not be empty")
        
        // Should contain a currency symbol or numeric value
        XCTAssertTrue(formatted.contains("$") || formatted.contains("0"), "Should contain currency symbol or numeric value: \(formatted)")
        
        // Should contain decimal point or comma (depending on locale)
        XCTAssertTrue(formatted.contains(".") || formatted.contains(","), "Should contain decimal separator: \(formatted)")
    }
    
    func testFormatCostWithPrefix() {
        let cost = Decimal(string: "0.015")!
        let formatted = calculator.formatCost(cost, includeEstimatePrefix: true)
        
        XCTAssertTrue(formatted.hasPrefix("~"))
    }
    
    func testPricingSummary() {
        let summary = CostCalculator.pricingSummary
        
        XCTAssertTrue(summary.contains("$0.001"))
        XCTAssertTrue(summary.lowercased().contains("page"))
    }
}

// MARK: - Export Configuration Tests

final class ExportConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        let config = ExportConfiguration.default
        
        XCTAssertEqual(config.format, .markdown)
        XCTAssertTrue(config.includeMetadata)
        XCTAssertTrue(config.includeCost)
        XCTAssertTrue(config.includeProcessingTime)
        XCTAssertTrue(config.prettyPrint)
        XCTAssertTrue(config.includeFrontMatter)
    }
    
    func testMinimalConfiguration() {
        let config = ExportConfiguration.minimal
        
        XCTAssertEqual(config.format, .plainText)
        XCTAssertFalse(config.includeMetadata)
        XCTAssertFalse(config.includeCost)
        XCTAssertFalse(config.includeProcessingTime)
    }
    
    func testConfigurationEquality() {
        let config1 = ExportConfiguration.default
        let config2 = ExportConfiguration.default
        
        XCTAssertEqual(config1, config2)
    }
}

// MARK: - Export Format Tests

final class ExportFormatTests: XCTestCase {
    
    func testFileExtensions() {
        XCTAssertEqual(ExportFormat.markdown.fileExtension, "md")
        XCTAssertEqual(ExportFormat.json.fileExtension, "json")
        XCTAssertEqual(ExportFormat.plainText.fileExtension, "txt")
    }
    
    func testDisplayNames() {
        XCTAssertEqual(ExportFormat.markdown.displayName, "Markdown")
        XCTAssertEqual(ExportFormat.json.displayName, "JSON")
        XCTAssertEqual(ExportFormat.plainText.displayName, "Plain Text")
    }
    
    func testMimeTypes() {
        XCTAssertEqual(ExportFormat.markdown.mimeType, "text/markdown")
        XCTAssertEqual(ExportFormat.json.mimeType, "application/json")
        XCTAssertEqual(ExportFormat.plainText.mimeType, "text/plain")
    }
    
    func testAllCases() {
        XCTAssertEqual(ExportFormat.allCases.count, 3)
        XCTAssertTrue(ExportFormat.allCases.contains(.markdown))
        XCTAssertTrue(ExportFormat.allCases.contains(.json))
        XCTAssertTrue(ExportFormat.allCases.contains(.plainText))
    }
}

// MARK: - User Preferences Tests

final class UserPreferencesTests: XCTestCase {
    
    func testDefaultValues() {
        let prefs = UserPreferences()
        
        XCTAssertTrue(prefs.showCostConfirmation)
        XCTAssertEqual(prefs.costConfirmationThreshold, Decimal(string: "0.50"))
        XCTAssertEqual(prefs.defaultExportFormat, .markdown)
        XCTAssertTrue(prefs.includeMetadataInExport)
        XCTAssertTrue(prefs.includeCostInExport)
        XCTAssertTrue(prefs.rememberExportLocation)
        XCTAssertNil(prefs.lastExportLocationPath)
        XCTAssertFalse(prefs.includeImagesInOCR)
        XCTAssertEqual(prefs.tableFormat, .markdown)
        XCTAssertTrue(prefs.showSidebar)
        XCTAssertTrue(prefs.showInspector)
        XCTAssertEqual(prefs.previewMode, .rendered)
    }
    
    func testLastExportLocationConversion() {
        var prefs = UserPreferences()
        
        XCTAssertNil(prefs.lastExportLocation)
        
        prefs.lastExportLocation = URL(fileURLWithPath: "/Users/test/Documents")
        XCTAssertNotNil(prefs.lastExportLocation)
        XCTAssertEqual(prefs.lastExportLocationPath, "/Users/test/Documents")
        
        prefs.lastExportLocation = nil
        XCTAssertNil(prefs.lastExportLocation)
        XCTAssertNil(prefs.lastExportLocationPath)
    }
    
    func testEncodingDecoding() throws {
        var original = UserPreferences()
        original.showCostConfirmation = false
        original.costConfirmationThreshold = Decimal(string: "1.50")!
        original.defaultExportFormat = .json
        original.includeImagesInOCR = true
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserPreferences.self, from: data)
        
        XCTAssertEqual(decoded.showCostConfirmation, false)
        XCTAssertEqual(decoded.costConfirmationThreshold, Decimal(string: "1.50"))
        XCTAssertEqual(decoded.defaultExportFormat, .json)
        XCTAssertEqual(decoded.includeImagesInOCR, true)
    }
    
    func testReset() {
        var prefs = UserPreferences()
        prefs.showCostConfirmation = false
        prefs.defaultExportFormat = .json
        
        prefs.reset()
        
        XCTAssertTrue(prefs.showCostConfirmation)
        XCTAssertEqual(prefs.defaultExportFormat, .markdown)
    }
}

// MARK: - Preview Mode Tests

final class PreviewModeTests: XCTestCase {
    
    func testDisplayNames() {
        XCTAssertEqual(PreviewMode.rendered.displayName, "Rendered")
        XCTAssertEqual(PreviewMode.raw.displayName, "Raw Markdown")
    }
    
    func testSymbolNames() {
        XCTAssertEqual(PreviewMode.rendered.symbolName, "eye")
        XCTAssertEqual(PreviewMode.raw.symbolName, "chevron.left.forwardslash.chevron.right")
    }
    
    func testAllCases() {
        XCTAssertEqual(PreviewMode.allCases.count, 2)
    }
}

// MARK: - Table Format Preference Tests

final class TableFormatPreferenceTests: XCTestCase {
    
    func testDisplayNames() {
        XCTAssertEqual(TableFormatPreference.inline.displayName, "Inline")
        XCTAssertEqual(TableFormatPreference.markdown.displayName, "Markdown Tables")
        XCTAssertEqual(TableFormatPreference.html.displayName, "HTML Tables")
    }
    
    func testAPIValues() {
        XCTAssertNil(TableFormatPreference.inline.apiValue)
        XCTAssertEqual(TableFormatPreference.markdown.apiValue, "markdown")
        XCTAssertEqual(TableFormatPreference.html.apiValue, "html")
    }
}
