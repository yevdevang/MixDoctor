//
//  OnboardingResultsScreen.swift
//
//  Screen 3: View Results screen
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingResultsScreen: View {
    @Binding var currentPage: Int
    
    private var imageName: String {
        #if targetEnvironment(macCatalyst)
        return "GuideResultViewMac"
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "GuideResultViewiPad"
        } else {
            return "GuideResultViewPhone"
        }
        #else
        return "GuideResultViewPhone"
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
            Text("View Your Results")
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
                    Text("See Your Analysis")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.primary)
                    
                    Text("View detailed analysis results with AI-powered recommendations to improve your mix.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Color.primaryAccent)
                        Text("View analysis results")
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
                    currentPage = 3
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    OnboardingResultsScreen(currentPage: .constant(2))
}
