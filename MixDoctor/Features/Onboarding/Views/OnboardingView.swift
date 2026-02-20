//
//  OnboardingView.swift
//  MixDoctor
//
//  Main onboarding container with TabView for pagination
//

import SwiftUI
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

                OnboardingDemoScreen(currentPage: $currentPage)
                    .tag(3)

                OnboardingFreeTrialScreen(isPresented: $isPresented)
                    .tag(4)
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
                        AnalyticsService.log(.onboardingSkipped, parameters: [
                            "screen": String(currentPage)
                        ])
                        
                        withAnimation {
                            isPresented = false
                        }
                        
                        // Post notification when onboarding is skipped
                        NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
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
            AnalyticsService.log(.onboardingStarted)
        }
        .onChange(of: currentPage) { _, newPage in
            // Log screen view event when user navigates to a new onboarding screen
            AnalyticsService.log(.onboardingScreenViewed, parameters: [
                "screen": String(newPage + 1)  // Screen numbers are 1-indexed for analytics
            ])
        }
        .onChange(of: isPresented) { _, newValue in
            // When onboarding is dismissed, mark as completed
            if !newValue {
                // Log completion event when onboarding is dismissed via "Get Started"
                if currentPage == 4 {
                    AnalyticsService.log(.onboardingCompleted)
                }
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
