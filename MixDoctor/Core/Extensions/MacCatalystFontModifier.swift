//
//  MacCatalystFontModifier.swift
//  MixDoctor
//
//  Global font scaling for Mac Catalyst
//

import SwiftUI

// MARK: - Font Scaling Modifier
struct MacCatalystFontScaling: ViewModifier {
    let scale: CGFloat
    
    init(scale: CGFloat = 1.5) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        content
            .scaleEffect(scale) // Scale the entire view up
            .frame(width: UIScreen.main.bounds.width / scale, height: UIScreen.main.bounds.height / scale) // Adjust frame
        #else
        content
        #endif
    }
}

extension View {
    /// Applies font scaling for Mac Catalyst environment by scaling the entire view
    func macCatalystFontScaling(_ scale: CGFloat = 1.5) -> some View {
        modifier(MacCatalystFontScaling(scale: scale))
    }
}

// MARK: - Scaled Font Extensions (for explicit use)
extension Font {
    /// Creates a system font with automatic Mac Catalyst scaling
    static func macScaled(_ style: Font.TextStyle) -> Font {
        #if targetEnvironment(macCatalyst)
        let scale: CGFloat = 1.5
        switch style {
        case .largeTitle:
            return .system(size: 34 * scale, weight: .regular)
        case .title:
            return .system(size: 28 * scale, weight: .regular)
        case .title2:
            return .system(size: 22 * scale, weight: .regular)
        case .title3:
            return .system(size: 20 * scale, weight: .regular)
        case .headline:
            return .system(size: 17 * scale, weight: .semibold)
        case .body:
            return .system(size: 17 * scale, weight: .regular)
        case .callout:
            return .system(size: 16 * scale, weight: .regular)
        case .subheadline:
            return .system(size: 15 * scale, weight: .regular)
        case .footnote:
            return .system(size: 13 * scale, weight: .regular)
        case .caption:
            return .system(size: 12 * scale, weight: .regular)
        case .caption2:
            return .system(size: 11 * scale, weight: .regular)
        @unknown default:
            return .system(size: 17 * scale, weight: .regular)
        }
        #else
        return .system(style)
        #endif
    }
    
    /// Creates a custom sized font with automatic Mac Catalyst scaling
    static func macScaled(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        #if targetEnvironment(macCatalyst)
        return .system(size: size * 1.5, weight: weight)
        #else
        return .system(size: size, weight: weight)
        #endif
    }
}
