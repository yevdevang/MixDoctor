//
//  AnalysisProgressTracker.swift
//  MixDoctor
//
//  Tracks analysis progress for UI updates
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AnalysisProgressTracker {
    static let shared = AnalysisProgressTracker()
    
    var currentStep: String = "Starting analysis..."
    var progress: Double = 0.0
    var elapsedTime: TimeInterval = 0.0
    
    private var startTime: Date?
    private var timer: Timer?
    
    private init() {}
    
    func updateProgress(step: String, progress: Double) {
        // Animate progress bar smoothly
        withAnimation(.easeInOut(duration: 0.5)) {
            self.progress = progress
        }
        
        // Update step text without animation (immediate)
        self.currentStep = step
        
        // Start timer on first progress update
        if startTime == nil {
            startTimer()
        }
    }
    
    func reset() {
        currentStep = "Starting analysis..."
        progress = 0.0
        elapsedTime = 0.0
        stopTimer()
    }
    
    private func startTimer() {
        startTime = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            Task { @MainActor in
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startTime = nil
    }
    
    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
