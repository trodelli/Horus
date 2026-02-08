//
//  SessionStatsView.swift
//  Horus
//
//  Created on 28/01/2026.
//

import SwiftUI

/// Session statistics summary displayed at the bottom of the navigation sidebar.
/// Shows processed document count with OCR/Clean breakdown and total spending.
struct SessionStatsView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session Summary")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 8)
            
            // Stats content
            VStack(alignment: .leading, spacing: 12) {
                // Processed Documents
                processedDocumentsSection
                
                // Total Spending
                totalSpendingSection
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
    
    // MARK: - Processed Documents Section
    
    private var processedDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Processed Documents")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            // Number and badges on same line
            HStack(spacing: 8) {
                Text("\(stats.processedCount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                
                // Process type badges inline
                if stats.ocrCount > 0 || stats.cleanCount > 0 {
                    HStack(spacing: 6) {
                        if stats.ocrCount > 0 {
                            ProcessBadge(count: stats.ocrCount, type: .ocr)
                        }
                        if stats.cleanCount > 0 {
                            ProcessBadge(count: stats.cleanCount, type: .clean)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Total Spending Section
    
    private var totalSpendingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total Spending")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Text(formattedCost)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Computed Properties
    
    /// Session statistics calculated from all documents
    private var stats: SessionStats {
        SessionStats.calculate(from: appState.allSessionDocuments)
    }
    
    /// Formatted cost string
    private var formattedCost: String {
        let cost = stats.totalCost
        let nsDecimal = cost as NSDecimalNumber
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: nsDecimal) ?? "$0.00"
    }
}

// MARK: - Process Badge

/// Small badge showing count for a specific process type (OCR or Clean)
struct ProcessBadge: View {
    let count: Int
    let type: ProcessType
    
    enum ProcessType {
        case ocr
        case clean
        
        var label: String {
            switch self {
            case .ocr: return "OCR"
            case .clean: return "Clean"
            }
        }
        
        var color: Color {
            switch self {
            case .ocr: return .blue
            case .clean: return .purple
            }
        }
    }
    
    var body: some View {
        Text("\(count) \(type.label)")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(type.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(type.color.opacity(0.15))
            )
    }
}

// MARK: - Session Stats Model

/// Session statistics data model
struct SessionStats {
    let processedCount: Int
    let ocrCount: Int
    let cleanCount: Int
    let totalCost: Decimal
    
    /// Calculate session stats from a collection of documents
    static func calculate(from documents: [Document]) -> SessionStats {
        // Debug logging
        print("📊 SessionStats Debug:")
        print("Total documents: \(documents.count)")
        
        for (index, doc) in documents.enumerated() {
            print("Doc \(index + 1): \(doc.displayName)")
            print("  - Has result: \(doc.result != nil)")
            print("  - Result model: \(doc.result?.model ?? "none")")
            print("  - Has cleanedContent: \(doc.cleanedContent != nil)")
            print("  - isCompleted: \(doc.isCompleted)")
        }
        
        // 1. PROCESSED COUNT: Documents that incurred processing costs
        //    This aligns "processed" with actual spending (OCR or Cleaning)
        let processed = documents.filter { doc in
            doc.hasBeenProcessed
        }.count
        
        // 2. OCR BADGE: Documents with OCR but NOT yet cleaned
        //    Once cleaned, they move to Clean badge only
        let ocrProcessed = documents.filter { doc in
            guard let result = doc.result else { return false }
            // Has OCR (not direct import) AND has NOT been cleaned
            return result.model != "direct-text-import" && doc.cleanedContent == nil
        }.count
        
        // 3. CLEAN BADGE: Documents that have been cleaned
        //    This includes docs that had OCR first - they count as "Clean" only
        let cleanProcessed = documents.filter { doc in
            doc.cleanedContent != nil
        }.count
        
        // 4. TOTAL COST: Sum of all OCR and Cleaning costs
        let cost = documents.reduce(Decimal(0)) { sum, doc in
            let ocrCost = doc.actualCost ?? 0
            let cleaningCost = doc.cleanedContent?.totalCost ?? 0
            return sum + ocrCost + cleaningCost
        }
        
        print("📊 Calculated Stats:")
        print("  - Processed: \(processed)")
        print("  - OCR: \(ocrProcessed)")
        print("  - Clean: \(cleanProcessed)")
        print("  - Cost: \(cost)")
        
        return SessionStats(
            processedCount: processed,
            ocrCount: ocrProcessed,
            cleanCount: cleanProcessed,
            totalCost: cost
        )
    }
}

// MARK: - Preview

#Preview("With Stats") {
    SessionStatsView()
        .environment(AppState())
        .frame(width: 200)
        .padding()
}

#Preview("Dark Mode") {
    SessionStatsView()
        .environment(AppState())
        .frame(width: 200)
        .padding()
        .preferredColorScheme(.dark)
}
