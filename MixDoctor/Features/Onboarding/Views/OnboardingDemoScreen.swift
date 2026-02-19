//
//  OnboardingDemoScreen.swift
//  MixDoctor
//
//  Screen 4: Demo Mixes screen — explains bundled sample files
//

import SwiftUI

struct OnboardingDemoScreen: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 100))
                .foregroundStyle(Color.primaryAccent)
                .symbolRenderingMode(.hierarchical)

            // Title
            Text("Sample Mixes Included")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            // Subtitle
            Text("We've included demo audio files so you can explore the app right away")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Steps
            VStack(spacing: 20) {
                OnboardingStep(
                    icon: "waveform",
                    title: "Mix & Master Files",
                    description: "Different stages to test with — no import needed"
                )

                OnboardingStep(
                    icon: "hand.tap",
                    title: "Tap to Analyze",
                    description: "Select any demo file and run analysis instantly"
                )

                OnboardingStep(
                    icon: "square.and.arrow.down",
                    title: "Import Your Own",
                    description: "When you're ready, import your own mixes"
                )
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()

            // Next button
            OnboardingButton(title: "Next") {
                withAnimation {
                    currentPage = 4
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    OnboardingDemoScreen(currentPage: .constant(3))
}
