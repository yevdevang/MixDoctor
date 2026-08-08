//
//  OnboardingFreeTrialScreen.swift
//  MixDoctor
//
//  Screen 4: Free Trial screen
//

import SwiftUI

struct OnboardingFreeTrialScreen: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Visual
            Image(systemName: "gift.fill")
                .font(.system(size: 100))
                .foregroundStyle(Color.primaryAccent)
                .symbolRenderingMode(.hierarchical)
            
            // Title
            Text("Start Analyzing")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            // Subtitle
            Text("You have 4 free analyses and demo tracks to get started")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Body text
            Text("No credit card required. Upgrade to Pro for more AI analyses and premium features, or unlock unlimited on-device analysis forever with a one-time Lifetime Pro purchase.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)
            
            Spacer()
            
            // Get Started button
            OnboardingButton(title: "Get Started") {
                withAnimation {
                    isPresented = false
                }
                // Post notification when onboarding is completed
                NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    OnboardingFreeTrialScreen(isPresented: .constant(true))
}
