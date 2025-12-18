//
//  Font+MacCatalyst.swift
//  MixDoctor
//
//  Created for Mac Catalyst font scaling
//

import SwiftUI

extension Font {
    /// Returns a scaled font for Mac Catalyst, or the original font for iOS
    static func scaledForCatalyst(_ font: Font, scale: CGFloat = 1.2) -> Font {
        #if targetEnvironment(macCatalyst)
        return font
        #else
        return font
        #endif
    }
}

extension View {
    /// Applies font with automatic Mac Catalyst scaling
    func catalystScaledFont(_ font: Font, macScale: CGFloat = 1.2) -> some View {
        #if targetEnvironment(macCatalyst)
        return self.font(scaleFont(font, by: macScale))
        #else
        return self.font(font)
        #endif
    }
    
    private func scaleFont(_ font: Font, by scale: CGFloat) -> Font {
        // Map standard fonts to scaled versions for Mac Catalyst
        switch font {
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
        case .subheadline:
            return .system(size: 15 * scale, weight: .regular)
        case .body:
            return .system(size: 17 * scale, weight: .regular)
        case .callout:
            return .system(size: 16 * scale, weight: .regular)
        case .caption:
            return .system(size: 12 * scale, weight: .regular)
        case .caption2:
            return .system(size: 11 * scale, weight: .regular)
        case .footnote:
            return .system(size: 13 * scale, weight: .regular)
        default:
            return font
        }
    }
}

// Text extension for easier usage
extension Text {
    func catalystScaled(_ textStyle: Font.TextStyle, macScale: CGFloat = 1.2) -> Text {
        #if targetEnvironment(macCatalyst)
        switch textStyle {
        case .largeTitle:
            return self.font(.system(size: 34 * macScale, weight: .regular))
        case .title:
            return self.font(.system(size: 28 * macScale, weight: .regular))
        case .title2:
            return self.font(.system(size: 22 * macScale, weight: .regular))
        case .title3:
            return self.font(.system(size: 20 * macScale, weight: .regular))
        case .headline:
            return self.font(.system(size: 17 * macScale, weight: .semibold))
        case .subheadline:
            return self.font(.system(size: 15 * macScale, weight: .regular))
        case .body:
            return self.font(.system(size: 17 * macScale, weight: .regular))
        case .callout:
            return self.font(.system(size: 16 * macScale, weight: .regular))
        case .caption:
            return self.font(.system(size: 12 * macScale, weight: .regular))
        case .caption2:
            return self.font(.system(size: 11 * macScale, weight: .regular))
        case .footnote:
            return self.font(.system(size: 13 * macScale, weight: .regular))
        @unknown default:
            return self
        }
        #else
        return self
        #endif
    }
}
