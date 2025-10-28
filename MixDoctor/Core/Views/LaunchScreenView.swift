//
//  LaunchScreenView.swift
//  MixDoctor
//
//  Launch screen with animated logo
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    @State private var fadeOut = false
    @State private var showTagline = false
    
    var body: some View {
        ZStack {
            // Background color matching paywall
            Color(red: 0xef/255, green: 0xe8/255, blue: 0xfd/255)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App Icon with animations
                Image("mix-doctor-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                
                // App name
                Text("MixDoctor")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.435, green: 0.173, blue: 0.871),
                                Color(red: 0.6, green: 0.3, blue: 0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                // Tagline
                Text("Professional Audio Analysis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(showTagline ? 1.0 : 0.0)
            }
            .opacity(fadeOut ? 0.0 : 1.0)
        }
        .onAppear {
            // Initial scale and fade in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
            
            // Show tagline with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeIn(duration: 0.5)) {
                    showTagline = true
                }
            }
            
            // Pulse animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
