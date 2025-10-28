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
    var autoAnalyze: Bool
    var keepOriginalFiles: Bool
    var defaultExportFormat: String // "pdf", "csv", "json"
    var enableNotifications: Bool
    var maxCacheSize: Int64 // in bytes
    var lastModified: Date
    
    init() {
        self.id = UUID()
        self.theme = "system"
        self.autoAnalyze = true
        self.keepOriginalFiles = true
        self.defaultExportFormat = "pdf"
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
    
    var id: String { value }
    
    var value: String {
        switch self {
        case .system: return "system"
        case .light: return "light"
        case .dark: return "dark"
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
