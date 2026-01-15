//
//  OnboardingHowItWorksScreen.swift
//  MixDoctor
//
//  Screen 2: How It Works screen
//

import SwiftUI

struct OnboardingHowItWorksScreen: View {
    @Binding var currentPage: Int
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Title
            Text("How It Works")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 20)
            
            // Image above text (vertical layout)
            VStack(spacing: 24) {
                // Image on top
                Image("GuideDashboardViewPhone")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Instructions below image
                VStack(alignment: .center, spacing: 16) {
                    Text("Analyze Your Mix")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.primary)
                    
                    Text("Tap the analysis icon to get AI-powered feedback on your audio mix.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .foregroundStyle(Color.primaryAccent)
                        Text("Tap to analyze")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Next button
            OnboardingButton(title: "Next") {
                withAnimation {
                    currentPage = 2
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    OnboardingHowItWorksScreen(currentPage: .constant(1))
}
