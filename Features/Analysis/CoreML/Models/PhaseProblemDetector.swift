//
//  PhaseProblemDetector.swift
//  MixDoctor
//
//  CoreML model for phase problem detection
//

import Foundation

final class PhaseProblemDetector {
    
    func detect(stereoFeatures: AudioFeatureExtractor.StereoFeatures) -> PhaseResult {
        let correlation = stereoFeatures.correlation
        
        // Negative correlation indicates phase problems
        if correlation < Constants.Analysis.phaseCorrelationError {
            return PhaseResult(
                hasIssue: true,
                severity: .severe,
                confidence: 0.9,
                recommendation: "Severe phase cancellation detected. Check for inverted polarity or phase issues. This will cause significant problems in mono playback."
            )
        } else if correlation < Constants.Analysis.phaseCorrelationWarning {
            return PhaseResult(
                hasIssue: true,
                severity: .moderate,
                confidence: 0.7,
                recommendation: "Possible phase issues detected. Review stereo processing and check correlation. May cause minor issues in mono compatibility."
            )
        } else {
            return PhaseResult(
                hasIssue: false,
                severity: .none,
                confidence: 0.95,
                recommendation: "Phase relationship is healthy. Good correlation between left and right channels."
            )
        }
    }
    
    struct PhaseResult {
        enum Severity {
            case none, moderate, severe
        }
        
        let hasIssue: Bool
        let severity: Severity
        let confidence: Float
        let recommendation: String
    }
}
