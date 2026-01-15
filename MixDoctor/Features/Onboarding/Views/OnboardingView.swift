//
//  OnboardingView.swift
//  MixDoctor
//
//  Main onboarding container with TabView for pagination
//

import SwiftUI
import FirebaseAnalytics

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            // Main content with TabView for pagination
            TabView(selection: $currentPage) {
                OnboardingWelcomeScreen(currentPage: $currentPage)
                    .tag(0)
                
                OnboardingHowItWorksScreen(currentPage: $currentPage)
                    .tag(1)
                
                OnboardingResultsScreen(currentPage: $currentPage)
                    .tag(2)
                
                OnboardingFreeTrialScreen(isPresented: $isPresented)
                    .tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            // Skip button overlay (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        // Log skip event
                        Analytics.logEvent("onboarding_skipped", parameters: [
                            "screen": currentPage
                        ])
                        
                        withAnimation {
                            isPresented = false
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            // Log onboarding started event
            Analytics.logEvent("onboarding_started", parameters: nil)
        }
        .onChange(of: isPresented) { _, newValue in
            // When onboarding is dismissed, mark as completed
            if !newValue {
                // Log completion event when onboarding is dismissed via "Get Started"
                if currentPage == 3 {
                    Analytics.logEvent("onboarding_completed", parameters: [
                        "method": "finished"
                    ])
                }
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
