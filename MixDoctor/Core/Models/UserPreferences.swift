//
//  UserPreferences.swift
//  MixDoctor
//
//  User preferences and settings data model
//

import Foundation
import SwiftData

@Model
final class UserPreferences {
    var id: UUID
    var theme: String // "system", "light", "dark"
    var analysisSensitivity: String // "low", "medium", "high"
    var autoAnalyze: Bool
    var keepOriginalFiles: Bool
    var defaultExportFormat: String // "pdf", "csv", "json"
    var showDetailedMetrics: Bool
    var enableNotifications: Bool
    var maxCacheSize: Int64 // in bytes
    var lastModified: Date
    
    init() {
        self.id = UUID()
        self.theme = "system"
        self.analysisSensitivity = "medium"
        self.autoAnalyze = true
        self.keepOriginalFiles = true
        self.defaultExportFormat = "pdf"
        self.showDetailedMetrics = true
        self.enableNotifications = true
        self.maxCacheSize = 1024 * 1024 * 1024 // 1GB default
        self.lastModified = Date()
    }
}

// MARK: - Theme Options
enum ThemeOption: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
}

// MARK: - Analysis Sensitivity
enum AnalysisSensitivity: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .low:
            return "Less strict analysis, fewer issues flagged"
        case .medium:
            return "Balanced analysis with standard thresholds"
        case .high:
            return "Strict analysis, more issues flagged"
        }
    }
    
    var thresholdMultiplier: Double {
        switch self {
        case .low:
            return 0.7
        case .medium:
            return 1.0
        case .high:
            return 1.3
        }
    }
}

// MARK: - Export Format
enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case csv = "CSV"
    case json = "JSON"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .pdf:
            return "pdf"
        case .csv:
            return "csv"
        case .json:
            return "json"
        }
    }
    
    var description: String {
        switch self {
        case .pdf:
            return "Formatted report with charts"
        case .csv:
            return "Spreadsheet-compatible data"
        case .json:
            return "Structured data for developers"
        }
    }
}
