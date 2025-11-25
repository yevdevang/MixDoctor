//
//  LaunchScreenView.swift
//  MixDoctor
//
//  Launch screen with animated logo
//

import SwiftUI
import AVFoundation
import UIKit

struct LaunchScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    @State private var fadeOut = false
    @State private var showTagline = false
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        ZStack {
            // Background color adapting to theme
            if colorScheme == .dark {
                Color(red: 0.08, green: 0.09, blue: 0.12)
                    .ignoresSafeArea()
            } else {
                Color(red: 0xef/255, green: 0xe8/255, blue: 0xfd/255)
                    .ignoresSafeArea()
            }
            
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
                
                // Tagline with falling letter animation
                AnimatedTaglineView(colorScheme: colorScheme, showTagline: showTagline)
            }
            .opacity(fadeOut ? 0.0 : 1.0)
        }
        .onAppear {
            // Initial scale and fade in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
            
            // Play sound with a slight delay to avoid blocking initial render
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                playLaunchSound()
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
    
    // MARK: - Animated Tagline View
    
    struct AnimatedTaglineView: View {
        let colorScheme: ColorScheme
        let showTagline: Bool
        let text = "Intelligent Audio Analysis"
        
        @State private var letterOffsets: [CGFloat] = []
        @State private var letterOpacities: [Double] = []
        
        var body: some View {
            HStack(spacing: 0) {
                ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                    Text(String(character))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(gradientForIndex(index))
                        .offset(y: letterOffsets.indices.contains(index) ? letterOffsets[index] : -50)
                        .opacity(letterOpacities.indices.contains(index) ? letterOpacities[index] : 0)
                }
            }
            .onAppear {
                // Initialize arrays
                letterOffsets = Array(repeating: -50, count: text.count)
                letterOpacities = Array(repeating: 0, count: text.count)
            }
            .onChange(of: showTagline) { oldValue, newValue in
                if newValue {
                    animateLetters()
                }
            }
        }
        
        private func animateLetters() {
            for index in 0..<text.count {
                let delay = Double(index) * 0.05 // Stagger each letter by 50ms (slower)
                
                // Animate the falling motion with spring
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.65)) {
                        letterOffsets[index] = 0
                    }
                }
                
                // Animate the fade-in separately with a smoother easing
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeIn(duration: 0.6)) {
                        letterOpacities[index] = 1.0
                    }
                }
            }
        }
        
        private func gradientForIndex(_ index: Int) -> LinearGradient {
            let colors = colorScheme == .dark ? [
                Color(red: 0.4, green: 0.8, blue: 1.0),   // Bright cyan
                Color(red: 0.7, green: 0.5, blue: 0.95),  // Purple
                Color(red: 1.0, green: 0.4, blue: 0.7)    // Pink
            ] : [
                Color(red: 0.5, green: 0.2, blue: 0.9),   // Deep purple
                Color(red: 0.9, green: 0.3, blue: 0.6),   // Magenta
                Color(red: 1.0, green: 0.5, blue: 0.3)    // Orange
            ]
            
            return LinearGradient(
                colors: colors,
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private func playLaunchSound() {
        if let soundAsset = NSDataAsset(name: "MixDoctor_sound") {
            do {
                audioPlayer = try AVAudioPlayer(data: soundAsset.data)
                audioPlayer?.volume = 0.5
                audioPlayer?.play()
            } catch {
                print("Error playing launch sound: \(error.localizedDescription)")
            }
        } else {
            print("Could not find sound asset: MixDoctor_sound")
        }
    }
    
    //#Preview {
    //    LaunchScreenView()
    //}
}
