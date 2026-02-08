//
//  CostCalculator.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation

// MARK: - Protocol

/// Protocol for cost calculation operations
protocol CostCalculatorProtocol {
    /// Calculate cost for a given number of pages
    func calculateCost(pages: Int) -> Decimal
    
    /// Format a cost value for display
    func formatCost(_ cost: Decimal, includeEstimatePrefix: Bool) -> String
    
    /// Format a cost with full details (for invoices/exports)
    func formatDetailedCost(_ cost: Decimal, pages: Int) -> String
}

// MARK: - Implementation

/// Calculates and formats costs based on Mistral OCR pricing.
///
/// Current pricing (as of January 2025):
/// - Standard API: $0.001 per page ($1.00 per 1,000 pages)
/// - Batch API: ~$0.0005 per page (50% discount, not used in Horus v1)
final class CostCalculator: CostCalculatorProtocol {
    
    // MARK: - Pricing Constants
    
    /// Cost per page in USD
    static let costPerPage: Decimal = Decimal(string: "0.001")!
    
    /// Cost per 1000 pages (for reference)
    static let costPer1000Pages: Decimal = Decimal(string: "1.00")!
    
    /// Pricing effective date (for documentation)
    static let pricingEffectiveDate = "January 2025"
    
    /// Link to official Mistral pricing
    static let pricingURL = URL(string: "https://mistral.ai/technology/#pricing")!
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide use
    static let shared = CostCalculator()
    
    // MARK: - Number Formatters
    
    /// Formatter for currency display ($ with appropriate decimals)
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")  // Use consistent US locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter
    }()
    
    /// Formatter for compact currency (fewer decimals for larger amounts)
    private let compactCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")  // Use consistent US locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    // MARK: - Cost Calculation
    
    /// Calculate the cost for processing a given number of pages
    /// - Parameter pages: Number of pages to process
    /// - Returns: Total cost in USD as Decimal
    func calculateCost(pages: Int) -> Decimal {
        guard pages > 0 else { return 0 }
        return Decimal(pages) * Self.costPerPage
    }
    
    /// Calculate cost for multiple documents
    /// - Parameter documents: Array of page counts
    /// - Returns: Total cost in USD
    func calculateTotalCost(documents: [Int]) -> Decimal {
        documents.reduce(Decimal.zero) { total, pages in
            total + calculateCost(pages: pages)
        }
    }
    
    // MARK: - Cost Formatting
    
    /// Format a cost value for display
    /// - Parameters:
    ///   - cost: The cost to format
    ///   - includeEstimatePrefix: Whether to prefix with "~" for estimates
    /// - Returns: Formatted string like "$0.012" or "~$0.012"
    func formatCost(_ cost: Decimal, includeEstimatePrefix: Bool = false) -> String {
        let formatter = cost >= 1 ? compactCurrencyFormatter : currencyFormatter
        let formatted = formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
        return includeEstimatePrefix ? "~\(formatted)" : formatted
    }
    
    /// Format a cost with page count details
    /// - Parameters:
    ///   - cost: The cost to format
    ///   - pages: Number of pages
    /// - Returns: Detailed string like "$0.012 (12 pages @ $0.001/page)"
    func formatDetailedCost(_ cost: Decimal, pages: Int) -> String {
        let formattedCost = formatCost(cost)
        let perPage = formatCost(Self.costPerPage)
        return "\(formattedCost) (\(pages) pages @ \(perPage)/page)"
    }
    
    /// Format cost as a range for display in UI
    /// - Parameters:
    ///   - minPages: Minimum estimated pages
    ///   - maxPages: Maximum estimated pages
    /// - Returns: Range string like "$0.01 – $0.02"
    func formatCostRange(minPages: Int, maxPages: Int) -> String {
        let minCost = calculateCost(pages: minPages)
        let maxCost = calculateCost(pages: maxPages)
        
        if minCost == maxCost {
            return formatCost(minCost)
        }
        
        return "\(formatCost(minCost)) – \(formatCost(maxCost))"
    }
}

// MARK: - Pricing Examples

extension CostCalculator {
    
    /// Standard pricing examples for display in onboarding/help
    static let pricingExamples: [(description: String, pages: Int, cost: String)] = [
        ("10-page PDF", 10, "~$0.01"),
        ("50 documents (avg 10 pages)", 500, "~$0.50"),
        ("1,000 pages total", 1000, "$1.00")
    ]
    
    /// Get a human-readable pricing summary
    static var pricingSummary: String {
        "Mistral OCR costs $0.001 per page ($1.00 per 1,000 pages)"
    }
}

// MARK: - Session Cost Tracking

/// Tracks costs across a processing session
final class SessionCostTracker {
    
    // MARK: - Properties
    
    private let calculator: CostCalculatorProtocol
    
    /// Running total of estimated cost
    private(set) var estimatedCost: Decimal = 0
    
    /// Running total of actual cost (after processing)
    private(set) var actualCost: Decimal = 0
    
    /// Number of pages estimated
    private(set) var estimatedPages: Int = 0
    
    /// Number of pages actually processed
    private(set) var actualPages: Int = 0
    
    // MARK: - Initialization
    
    init(calculator: CostCalculatorProtocol = CostCalculator.shared) {
        self.calculator = calculator
    }
    
    // MARK: - Tracking Methods
    
    /// Add an estimate for pages to be processed
    func addEstimate(pages: Int) {
        estimatedPages += pages
        estimatedCost += calculator.calculateCost(pages: pages)
    }
    
    /// Remove an estimate (document removed from queue)
    func removeEstimate(pages: Int) {
        estimatedPages = max(0, estimatedPages - pages)
        estimatedCost = max(0, estimatedCost - calculator.calculateCost(pages: pages))
    }
    
    /// Record actual cost after processing
    func recordActual(pages: Int, cost: Decimal) {
        actualPages += pages
        actualCost += cost
    }
    
    /// Reset all tracking
    func reset() {
        estimatedCost = 0
        actualCost = 0
        estimatedPages = 0
        actualPages = 0
    }
    
    // MARK: - Formatted Output
    
    /// Get formatted estimated cost
    var formattedEstimatedCost: String {
        calculator.formatCost(estimatedCost, includeEstimatePrefix: true)
    }
    
    /// Get formatted actual cost
    var formattedActualCost: String {
        calculator.formatCost(actualCost, includeEstimatePrefix: false)
    }
    
    /// Get a summary suitable for display
    var summary: String {
        if actualPages > 0 {
            return "\(actualPages) pages processed • \(formattedActualCost)"
        } else if estimatedPages > 0 {
            return "~\(estimatedPages) pages • \(formattedEstimatedCost)"
        }
        return "No pages"
    }
}

// MARK: - Mock Implementation

/// Mock cost calculator for testing
final class MockCostCalculator: CostCalculatorProtocol {
    
    var costPerPage: Decimal = Decimal(string: "0.001")!
    
    func calculateCost(pages: Int) -> Decimal {
        Decimal(pages) * costPerPage
    }
    
    func formatCost(_ cost: Decimal, includeEstimatePrefix: Bool) -> String {
        let prefix = includeEstimatePrefix ? "~" : ""
        return "\(prefix)$\(cost)"
    }
    
    func formatDetailedCost(_ cost: Decimal, pages: Int) -> String {
        "$\(cost) (\(pages) pages)"
    }
}
