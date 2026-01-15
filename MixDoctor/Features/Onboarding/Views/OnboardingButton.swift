//
//  OnboardingButton.swift
//  MixDoctor
//
//  Shared button component for onboarding screens
//

import SwiftUI

struct OnboardingButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.primaryAccent)
                .cornerRadius(12)
        }
        .buttonStyle(.plain) // Prevents default button styling
    }
}

#Preview {
    VStack(spacing: 20) {
        OnboardingButton(title: "Next") {
            print("Button tapped")
        }
        OnboardingButton(title: "Get Started") {
            print("Button tapped")
        }
    }
    .padding()
}
