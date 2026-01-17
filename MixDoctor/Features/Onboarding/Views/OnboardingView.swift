//
//  OnboardingView.swift
//  MixDoctor
//
//  Main onboarding container with TabView for pagination
//

import SwiftUI
import FirebaseAnalytics
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            // Background color to ensure full coverage
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
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
            .onAppear {
                #if canImport(UIKit)
                // Set page indicator color to purple (primaryAccent)
                // Adapts to light/dark mode like primaryAccent
                UIPageControl.appearance().currentPageIndicatorTintColor = UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        // Dark mode: Brighter purple - RGB(140, 80, 240) or #8c50f0
                        return UIColor(red: 0.55, green: 0.31, blue: 0.94, alpha: 1.0)
                    } else {
                        // Light mode: Original purple - RGB(111, 44, 222) or #6f2cde
                        return UIColor(red: 0.435, green: 0.173, blue: 0.871, alpha: 1.0)
                    }
                }
                UIPageControl.appearance().pageIndicatorTintColor = UIColor.secondaryLabel
                #endif
            }
            
            // Skip button overlay (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        // Log skip event
                        Analytics.logEvent("onboarding_skipped", parameters: [
                            "screen": String(currentPage)
                        ])
                        
                        withAnimation {
                            isPresented = false
                        }
                    }
                    .foregroundStyle(Color.primaryAccent)
                    .padding()
                    #if canImport(UIKit)
                    .padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? 20 : 0)
                    #endif
                }
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Log onboarding started event
            Analytics.logEvent("onboarding_started", parameters: nil)
        }
        .onChange(of: currentPage) { _, newPage in
            // Log screen view event when user navigates to a new onboarding screen
            Analytics.logEvent("onboarding_screen_viewed", parameters: [
                "screen": String(newPage + 1)  // Screen numbers are 1-indexed for analytics
            ])
        }
        .onChange(of: isPresented) { _, newValue in
            // When onboarding is dismissed, mark as completed
            if !newValue {
                // Log completion event when onboarding is dismissed via "Get Started"
                if currentPage == 3 {
                    Analytics.logEvent("onboarding_completed", parameters: nil)
                }
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
