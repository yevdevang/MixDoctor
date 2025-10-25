//
//  AppBackgroundView.swift
//  MixDoctor
//
//  Professional audio tool-inspired background gradient
//

import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Base layer - system background
            if colorScheme == .dark {
                Color.black
                    .ignoresSafeArea()
            } else {
                Color(white: 0.98)
                    .ignoresSafeArea()
            }
            
            // Gradient overlay - inspired by Pro Tools, Logic Pro
            if colorScheme == .dark {
                // Dark mode: Deep charcoal with subtle purple-blue tint
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.12),      // Very dark blue-gray (top)
                        Color(red: 0.05, green: 0.05, blue: 0.08),      // Deep charcoal-blue (middle)
                        Color(red: 0.03, green: 0.04, blue: 0.07)       // Almost black with blue tint (bottom)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.6)
                .ignoresSafeArea()
                
                // Subtle radial accent - like studio monitors glow
                RadialGradient(
                    colors: [
                        Color(red: 0.12, green: 0.15, blue: 0.25).opacity(0.3),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 600
                )
                .ignoresSafeArea()
            } else {
                // Light mode: Very subtle cool gray with hint of blue
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.97, blue: 0.99),      // Very light blue-white (top)
                        Color(red: 0.94, green: 0.95, blue: 0.97),      // Cool white (middle)
                        Color(red: 0.92, green: 0.93, blue: 0.96)       // Subtle blue-gray (bottom)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.4)
                .ignoresSafeArea()
                
                // Very subtle accent
                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.05),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - View Extension for Easy Application

extension View {
    func withAppBackground() -> some View {
        ZStack {
            AppBackgroundView()
            self
        }
    }
}

#Preview("Dark Mode") {
    VStack {
        Text("MixDoctor")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        Text("Professional Audio Analysis")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .withAppBackground()
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    VStack {
        Text("MixDoctor")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        Text("Professional Audio Analysis")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .withAppBackground()
    .preferredColorScheme(.light)
}
