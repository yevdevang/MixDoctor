//
//  OnboardingWelcomeScreen.swift
//  MixDoctor
//
//  Screen 1: Welcome screen
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingWelcomeScreen: View {
    @Binding var currentPage: Int
    
    private var imageName: String {
        #if targetEnvironment(macCatalyst)
        return "GuideImportViewMac"
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "GuideImportViewiPad"
        } else {
            return "GuideImportViewPhone"
        }
        #else
        return "GuideImportViewPhone"
        #endif
    }
    
    private var imageMaxWidth: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 700
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 500
        } else {
            return 300
        }
        #else
        return 300
        #endif
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Title
            Text("Welcome to MixDoctor! 🎵")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 20)
            
            // Image above text (vertical layout)
            VStack(spacing: 24) {
                // Image on top
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: imageMaxWidth)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Instructions below image
                VStack(alignment: .center, spacing: 16) {
                    Text("Get Started")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.primary)
                    
                    Text("Select a **Genre** and **Stage** — Mix, Master (Streaming), or Master (CD) — then tap the **Import More** button to upload your audio file.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(Color.primaryAccent)
                        Text("Go to Import tab")
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
                    currentPage = 1
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    OnboardingWelcomeScreen(currentPage: .constant(0))
}
