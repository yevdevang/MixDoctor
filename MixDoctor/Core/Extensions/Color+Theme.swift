import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    // Use system blue as fallback if AccentColor is not found
    static let primaryAccent: Color = {
        #if canImport(UIKit)
        return Color(uiColor: .systemBlue)
        #else
        return Color.blue
        #endif
    }()
    
    #if canImport(UIKit)
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let secondaryText = Color(UIColor.secondaryLabel)
    #else
    static let backgroundPrimary = Color.white
    static let backgroundSecondary = Color.gray.opacity(0.15)
    static let secondaryText = Color.gray
    #endif
    
    // Score-based colors
    static let scoreExcellent = Color.green
    static let scoreGood = Color(hue: 0.22, saturation: 0.7, brightness: 0.8) // Yellow-green
    static let scoreFair = Color.orange
    static let scorePoor = Color.red
    
    // Function to get color based on score
    static func scoreColor(for score: Double) -> Color {
        switch score {
        case 85...100: return .scoreExcellent
        case 70..<85: return .scoreGood
        case 50..<70: return .scoreFair
        default: return .scorePoor
        }
    }
}
