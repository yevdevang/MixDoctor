//
//  FrequencyBalanceAnalyzer.swift
//  MixDoctor
//
//  Analyzer for frequency balance and spectral content
//

import Foundation

final class FrequencyBalanceAnalyzer {
    
    func analyze(frequencyFeatures: AudioFeatureExtractor.FrequencyFeatures) -> FrequencyBalanceResult {
        let bands = frequencyFeatures.frequencyBands
        
        // Extract band energies
        let bass = bands[60] ?? 0
        let mids = bands[500] ?? 0
        let highs = bands[6000] ?? 0
        
        // Normalize
        let total = bass + mids + highs + 0.0001
        let bassRatio = bass / total
        let midsRatio = mids / total
        let highsRatio = highs / total
        
        var issues: [String] = []
        var recommendations: [String] = []
        
        // Check for imbalances
        let idealBass = Constants.Analysis.idealBassRatio
        let idealMids = Constants.Analysis.idealMidsRatio
        let idealHighs = Constants.Analysis.idealHighsRatio
        
        if bassRatio < idealBass - 0.1 {
            issues.append("Bass deficiency")
            recommendations.append("Boost low end frequencies (60-250 Hz) or add sub-bass content")
        } else if bassRatio > idealBass + 0.2 {
            issues.append("Bass excess")
            recommendations.append("Reduce low end frequencies or add high-pass filter to clean up mud")
        }
        
        if midsRatio < idealMids - 0.15 {
            issues.append("Midrange deficiency")
            recommendations.append("Boost midrange frequencies (500-2000 Hz) for presence and clarity")
        } else if midsRatio > idealMids + 0.15 {
            issues.append("Midrange excess")
            recommendations.append("Reduce midrange frequencies to avoid boxy or honky sound")
        }
        
        if highsRatio < idealHighs - 0.15 {
            issues.append("High frequency deficiency")
            recommendations.append("Add brightness with high shelf or air band boost (8-16 kHz)")
        } else if highsRatio > idealHighs + 0.1 {
            issues.append("High frequency excess")
            recommendations.append("Reduce harsh high frequencies to avoid listener fatigue")
        }
        
        let score = calculateBalanceScore(
            bassRatio: bassRatio,
            midsRatio: midsRatio,
            highsRatio: highsRatio
        )
        
        return FrequencyBalanceResult(
            score: score,
            bassRatio: bassRatio,
            midsRatio: midsRatio,
            highsRatio: highsRatio,
            issues: issues,
            recommendations: recommendations
        )
    }
    
    private func calculateBalanceScore(bassRatio: Float, midsRatio: Float, highsRatio: Float) -> Float {
        // Ideal ratios
        let idealBass = Constants.Analysis.idealBassRatio
        let idealMids = Constants.Analysis.idealMidsRatio
        let idealHighs = Constants.Analysis.idealHighsRatio
        
        // Calculate deviation from ideal
        let bassDeviation = abs(bassRatio - idealBass)
        let midsDeviation = abs(midsRatio - idealMids)
        let highsDeviation = abs(highsRatio - idealHighs)
        
        let totalDeviation = bassDeviation + midsDeviation + highsDeviation
        let score = max(0, 100 - (totalDeviation * 200)) // Scale to 0-100
        
        return score
    }
    
    struct FrequencyBalanceResult {
        let score: Float
        let bassRatio: Float
        let midsRatio: Float
        let highsRatio: Float
        let issues: [String]
        let recommendations: [String]
    }
}
