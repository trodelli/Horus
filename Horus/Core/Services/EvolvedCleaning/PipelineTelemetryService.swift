//
//  PipelineTelemetryService.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: Collects anonymous usage metrics for the V3 cleaning pipeline.
//  All data is stored locally - no external calls.
//

import Foundation
import OSLog

// MARK: - Telemetry Event

/// A single telemetry event.
struct TelemetryEvent: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let eventType: TelemetryEventType
    let pipelineMode: String
    let data: [String: String]
}

/// Types of telemetry events.
enum TelemetryEventType: String, Codable, Sendable {
    case cleaningStarted
    case cleaningCompleted
    case cleaningFailed
    case fallbackUsed
    case feedbackSubmitted
    case issueReported
}

// MARK: - Telemetry Summary

/// Summary of telemetry data.
struct TelemetrySummary: Sendable {
    let totalCleanings: Int
    let successRate: Double
    let averageConfidence: Double
    let fallbackRate: Double
}

// MARK: - Pipeline Telemetry Service

/// Collects and manages pipeline usage telemetry.
/// All data is stored locally for privacy.
final class PipelineTelemetryService: Sendable {
    
    static let shared = PipelineTelemetryService()
    
    private let logger = Logger(subsystem: "com.horus.app", category: "Telemetry")
    private let storageKey = "pipelineTelemetryEvents"
    private let maxEvents = 1000
    
    private let queue = DispatchQueue(label: "com.horus.telemetry", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {
        logger.info("Telemetry service initialized")
    }
    
    // MARK: - Event Recording
    
    /// Record a telemetry event.
    func record(
        eventType: TelemetryEventType,
        data: [String: String] = [:]
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let event = TelemetryEvent(
                id: UUID(),
                timestamp: Date(),
                eventType: eventType,
                pipelineMode: "V3",
                data: data
            )
            
            var events = self.loadEvents()
            events.append(event)
            
            // Trim old events if needed
            if events.count > self.maxEvents {
                events = Array(events.suffix(self.maxEvents))
            }
            
            self.saveEvents(events)
            self.logger.debug("Recorded event: \(eventType.rawValue)")
        }
    }
    
    /// Record cleaning started.
    func recordCleaningStarted(documentWordCount: Int) {
        record(
            eventType: .cleaningStarted,
            data: ["wordCount": String(documentWordCount)]
        )
    }
    
    /// Record cleaning completed.
    func recordCleaningCompleted(
        confidence: Double,
        durationSeconds: Double,
        usedFallback: Bool
    ) {
        record(
            eventType: .cleaningCompleted,
            data: [
                "confidence": String(format: "%.2f", confidence),
                "duration": String(format: "%.1f", durationSeconds),
                "usedFallback": String(usedFallback)
            ]
        )
    }
    
    /// Record cleaning failed.
    func recordCleaningFailed(error: String) {
        record(
            eventType: .cleaningFailed,
            data: ["error": error]
        )
    }
    
    /// Record feedback submitted.
    func recordFeedbackSubmitted(rating: Int) {
        record(
            eventType: .feedbackSubmitted,
            data: ["rating": String(rating)]
        )
    }
    
    // MARK: - Summary
    
    /// Get telemetry summary.
    func getSummary() -> TelemetrySummary {
        let events = loadEvents()
        
        let cleaningCompleted = events.filter { $0.eventType == .cleaningCompleted }
        let cleaningFailed = events.filter { $0.eventType == .cleaningFailed }
        
        let total = cleaningCompleted.count + cleaningFailed.count
        
        let successRate = total > 0 ? Double(cleaningCompleted.count) / Double(total) : 1.0
        
        let confidences = cleaningCompleted.compactMap { Double($0.data["confidence"] ?? "") }
        let avgConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Double(confidences.count)
        
        let fallbacks = cleaningCompleted.filter { $0.data["usedFallback"] == "true" }.count
        let fallbackRate = cleaningCompleted.isEmpty ? 0 : Double(fallbacks) / Double(cleaningCompleted.count)
        
        return TelemetrySummary(
            totalCleanings: total,
            successRate: successRate,
            averageConfidence: avgConfidence,
            fallbackRate: fallbackRate
        )
    }
    
    // MARK: - Persistence
    
    private func loadEvents() -> [TelemetryEvent] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let events = try? JSONDecoder().decode([TelemetryEvent].self, from: data) else {
            return []
        }
        return events
    }
    
    private func saveEvents(_ events: [TelemetryEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    /// Clear all telemetry data.
    func clearAllData() {
        queue.async {
            UserDefaults.standard.removeObject(forKey: self.storageKey)
            self.logger.info("Telemetry data cleared")
        }
    }
}
