//
//  ExportService.swift
//  MixDoctor
//
//  Service for exporting analysis results in various formats
//

import Foundation
import UIKit
import PDFKit

final class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    // MARK: - Export Methods
    
    func exportToPDF(audioFile: AudioFile) throws -> URL {
        guard let result = audioFile.analysisResult else {
            throw ExportError.noAnalysisResult
        }
        
        let pdfData = createPDFData(audioFile: audioFile, result: result)
        let fileName = "\(audioFile.fileName)_Analysis_Report.pdf"
        let url = try saveToTemporaryDirectory(data: pdfData, fileName: fileName)
        
        return url
    }
    
    func exportToCSV(audioFiles: [AudioFile]) throws -> URL {
        let csvString = createCSVString(from: audioFiles)
        guard let data = csvString.data(using: .utf8) else {
            throw ExportError.dataConversionFailed
        }
        
        let fileName = "MixDoctor_Export_\(formattedTimestamp()).csv"
        return try saveToTemporaryDirectory(data: data, fileName: fileName)
    }
    
    func exportToJSON(audioFiles: [AudioFile]) throws -> URL {
        let exportData = audioFiles.map { file -> [String: Any] in
            createJSONDictionary(from: file)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        let fileName = "MixDoctor_Export_\(formattedTimestamp()).json"
        
        return try saveToTemporaryDirectory(data: jsonData, fileName: fileName)
    }
    
    // MARK: - PDF Generation
    
    private func createPDFData(audioFile: AudioFile, result: AnalysisResult) -> Data {
        let pageWidth: CGFloat = 612 // US Letter width in points
        let pageHeight: CGFloat = 792 // US Letter height in points
        let margin: CGFloat = 50
        
        let pdfMetaData = [
            kCGPDFContextCreator: "MixDoctor",
            kCGPDFContextTitle: "\(audioFile.fileName) Analysis Report"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = margin
            
            // Title
            yPosition = drawText(
                "Audio Analysis Report",
                at: CGPoint(x: margin, y: yPosition),
                fontSize: 24,
                bold: true,
                in: pageRect
            )
            
            yPosition += 20
            
            // File Information
            yPosition = drawSectionHeader("File Information", at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("File Name", value: audioFile.fileName, at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Duration", value: formatDuration(audioFile.duration), at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Sample Rate", value: "\(Int(audioFile.sampleRate)) Hz", at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Bit Depth", value: "\(audioFile.bitDepth) bit", at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Channels", value: "\(audioFile.numberOfChannels)", at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("File Size", value: ByteCountFormatter.string(fromByteCount: audioFile.fileSize, countStyle: .file), at: yPosition, margin: margin, in: pageRect)
            
            yPosition += 30
            
            // Overall Score
            yPosition = drawSectionHeader("Overall Score", at: yPosition, margin: margin, in: pageRect)
            yPosition = drawScore(result.overallScore, at: yPosition, margin: margin, in: pageRect)
            
            yPosition += 30
            
            // Analysis Results
            yPosition = drawSectionHeader("Analysis Results", at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Stereo Width", value: String(format: "%.1f%%", result.stereoWidthScore), at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Phase Coherence", value: String(format: "%.1f%%", result.phaseCoherence), at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Dynamic Range", value: String(format: "%.1f dB", result.dynamicRange), at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Loudness (LUFS)", value: String(format: "%.1f LUFS", result.loudnessLUFS), at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Peak Level", value: String(format: "%.1f dB", result.peakLevel), at: yPosition, margin: margin, in: pageRect)
            
            yPosition += 30
            
            // Frequency Balance
            yPosition = drawSectionHeader("Frequency Balance", at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Low End (20-250 Hz)", value: String(format: "%.1f%%", result.lowEndBalance), at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Low Mids (250-500 Hz)", value: String(format: "%.1f%%", result.lowMidBalance), at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Mids (500-2000 Hz)", value: String(format: "%.1f%%", result.midBalance), at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("High Mids (2000-6000 Hz)", value: String(format: "%.1f%%", result.highMidBalance), at: yPosition, margin: margin, in: pageRect)
            yPosition = drawKeyValue("Highs (6000-20000 Hz)", value: String(format: "%.1f%%", result.highBalance), at: yPosition, margin: margin, in: pageRect)
            
            yPosition += 30
            
            // Issues
            if result.hasAnyIssues {
                yPosition = drawSectionHeader("Detected Issues", at: yPosition, margin: margin, in: pageRect)
                if result.hasPhaseIssues {
                    yPosition = drawBulletPoint("Phase correlation issues detected", at: yPosition, margin: margin, in: pageRect)
                }
                if result.hasStereoIssues {
                    yPosition = drawBulletPoint("Stereo imaging issues detected", at: yPosition, margin: margin, in: pageRect)
                }
                if result.hasFrequencyImbalance {
                    yPosition = drawBulletPoint("Frequency balance issues detected", at: yPosition, margin: margin, in: pageRect)
                }
                if result.hasDynamicRangeIssues {
                    yPosition = drawBulletPoint("Dynamic range issues detected", at: yPosition, margin: margin, in: pageRect)
                }
                yPosition += 20
            }
            
            // Recommendations
            if !result.recommendations.isEmpty {
                yPosition = drawSectionHeader("Recommendations", at: yPosition, margin: margin, in: pageRect)
                for recommendation in result.recommendations {
                    yPosition = drawBulletPoint(recommendation, at: yPosition, margin: margin, in: pageRect)
                }
            }
            
            // Footer
            drawFooter(at: pageHeight - margin, margin: margin, pageWidth: pageWidth)
        }
        
        return data
    }
    
    // MARK: - PDF Drawing Helpers
    
    @discardableResult
    private func drawText(
        _ text: String,
        at point: CGPoint,
        fontSize: CGFloat = 12,
        bold: Bool = false,
        in rect: CGRect
    ) -> CGFloat {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(at: point)
        
        return point.y + fontSize + 8
    }
    
    @discardableResult
    private func drawSectionHeader(_ text: String, at yPosition: CGFloat, margin: CGFloat, in rect: CGRect) -> CGFloat {
        drawText(text, at: CGPoint(x: margin, y: yPosition), fontSize: 16, bold: true, in: rect)
    }
    
    @discardableResult
    private func drawKeyValue(_ key: String, value: String, at yPosition: CGFloat, margin: CGFloat, in rect: CGRect) -> CGFloat {
        let fullText = "\(key): \(value)"
        return drawText(fullText, at: CGPoint(x: margin + 10, y: yPosition), fontSize: 12, in: rect)
    }
    
    @discardableResult
    private func drawBulletPoint(_ text: String, at yPosition: CGFloat, margin: CGFloat, in rect: CGRect) -> CGFloat {
        let bulletText = "• \(text)"
        return drawText(bulletText, at: CGPoint(x: margin + 10, y: yPosition), fontSize: 12, in: rect)
    }
    
    @discardableResult
    private func drawScore(_ score: Double, at yPosition: CGFloat, margin: CGFloat, in rect: CGRect) -> CGFloat {
        let scoreText = String(format: "%.1f / 100", score)
        return drawText(scoreText, at: CGPoint(x: margin + 10, y: yPosition), fontSize: 18, bold: true, in: rect)
    }
    
    private func drawFooter(at yPosition: CGFloat, margin: CGFloat, pageWidth: CGFloat) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let footerText = "Generated by MixDoctor on \(dateFormatter.string(from: Date()))"
        
        let font = UIFont.systemFont(ofSize: 10)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray
        ]
        
        let attributedString = NSAttributedString(string: footerText, attributes: attributes)
        let textSize = attributedString.size()
        let xPosition = (pageWidth - textSize.width) / 2
        
        attributedString.draw(at: CGPoint(x: xPosition, y: yPosition))
    }
    
    // MARK: - CSV Generation
    
    private func createCSVString(from audioFiles: [AudioFile]) -> String {
        var csv = "File Name,Duration,Sample Rate,Bit Depth,Channels,File Size,Date Imported,Overall Score,Stereo Width,Phase Coherence,Dynamic Range,Loudness (LUFS),Peak Level,Has Issues\n"
        
        for file in audioFiles {
            let overallScore = file.analysisResult.map { String(format: "%.1f", $0.overallScore) } ?? "N/A"
            let stereoWidth = file.analysisResult.map { String(format: "%.1f", $0.stereoWidthScore) } ?? "N/A"
            let phaseCoherence = file.analysisResult.map { String(format: "%.1f", $0.phaseCoherence) } ?? "N/A"
            let dynamicRange = file.analysisResult.map { String(format: "%.1f", $0.dynamicRange) } ?? "N/A"
            let loudness = file.analysisResult.map { String(format: "%.1f", $0.loudnessLUFS) } ?? "N/A"
            let peakLevel = file.analysisResult.map { String(format: "%.1f", $0.peakLevel) } ?? "N/A"
            let hasIssues = file.analysisResult?.hasAnyIssues == true ? "Yes" : "No"
            
            let row = [
                file.fileName,
                formatDuration(file.duration),
                "\(Int(file.sampleRate))",
                "\(file.bitDepth)",
                "\(file.numberOfChannels)",
                "\(file.fileSize)",
                formatDate(file.dateImported),
                overallScore,
                stereoWidth,
                phaseCoherence,
                dynamicRange,
                loudness,
                peakLevel,
                hasIssues
            ]
            
            csv += row.joined(separator: ",") + "\n"
        }
        
        return csv
    }
    
    // MARK: - JSON Generation
    
    private func createJSONDictionary(from audioFile: AudioFile) -> [String: Any] {
        var dict: [String: Any] = [
            "fileName": audioFile.fileName,
            "duration": audioFile.duration,
            "sampleRate": audioFile.sampleRate,
            "bitDepth": audioFile.bitDepth,
            "numberOfChannels": audioFile.numberOfChannels,
            "fileSize": audioFile.fileSize,
            "dateImported": ISO8601DateFormatter().string(from: audioFile.dateImported)
        ]
        
        if let result = audioFile.analysisResult {
            dict["analysis"] = [
                "dateAnalyzed": ISO8601DateFormatter().string(from: result.dateAnalyzed),
                "overallScore": result.overallScore,
                "stereoWidthScore": result.stereoWidthScore,
                "phaseCoherence": result.phaseCoherence,
                "dynamicRange": result.dynamicRange,
                "loudnessLUFS": result.loudnessLUFS,
                "peakLevel": result.peakLevel,
                "frequencyBalance": [
                    "lowEnd": result.lowEndBalance,
                    "lowMids": result.lowMidBalance,
                    "mids": result.midBalance,
                    "highMids": result.highMidBalance,
                    "highs": result.highBalance
                ],
                "issues": [
                    "phaseIssues": result.hasPhaseIssues,
                    "stereoIssues": result.hasStereoIssues,
                    "frequencyImbalance": result.hasFrequencyImbalance,
                    "dynamicRangeIssues": result.hasDynamicRangeIssues
                ],
                "recommendations": result.recommendations
            ]
        }
        
        return dict
    }
    
    // MARK: - File Saving
    
    private func saveToTemporaryDirectory(data: Data, fileName: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Formatters
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case noAnalysisResult
    case dataConversionFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .noAnalysisResult:
            return "No analysis result available for this file"
        case .dataConversionFailed:
            return "Failed to convert data to required format"
        case .saveFailed:
            return "Failed to save exported file"
        }
    }
}
