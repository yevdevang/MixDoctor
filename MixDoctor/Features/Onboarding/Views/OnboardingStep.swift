//
//  OnboardingStep.swift
//  MixDoctor
//
//  Helper component for displaying steps in onboarding
//

import SwiftUI

struct OnboardingStep: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(Color.primaryAccent)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        OnboardingStep(
            icon: "arrow.up.doc.fill",
            title: "Upload Your Mix",
            description: "Import or record audio files"
        )
        OnboardingStep(
            icon: "brain.head.profile",
            title: "Get AI Analysis",
            description: "Powered by Claude AI"
        )
        OnboardingStep(
            icon: "waveform",
            title: "Improve Your Sound",
            description: "Follow specific recommendations"
        )
    }
    .padding()
}
