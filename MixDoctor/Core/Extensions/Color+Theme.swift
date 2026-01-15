import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    // Purple accent color - adapts to color scheme
    // Light mode: #6f2cde (RGB: 111, 44, 222)
    // Dark mode: Brighter version for better readability
    static var avidPink: Color {
        #if canImport(UIKit)
        Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                // Dark mode: Brighter purple - RGB(140, 80, 240) or #8c50f0
                return UIColor(red: 0.55, green: 0.31, blue: 0.94, alpha: 1.0)
            } else {
                // Light mode: Original purple - RGB(111, 44, 222) or #6f2cde
                return UIColor(red: 0.435, green: 0.173, blue: 0.871, alpha: 1.0)
            }
        })
        #else
        Color(red: 0.435, green: 0.173, blue: 0.871)
        #endif
    }
    
    // Use purple as primary accent
    static var primaryAccent: Color {
        avidPink
    }
    
    // Helper function for explicit color scheme control (if needed)
    static func appPurple(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            // Dark mode: Brighter purple for better readability
            return Color(red: 0.55, green: 0.31, blue: 0.94) // #8c50f0
        } else {
            // Light mode: Original purple
            return Color(red: 0.435, green: 0.173, blue: 0.871) // #6f2cde
        }
    }
    
    #if canImport(UIKit)
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let secondaryText = Color(UIColor.secondaryLabel)
    #else
    static let backgroundPrimary = Color.white
    static let backgroundSecondary = Color.gray.opacity(0.15)
    static let secondaryText = Color.gray
    #endif
    
    // Score-based colors matching "Understanding Your Score" ranges
    static let scoreReferenceQuality = Color.green                              // 95-100: Reference Quality
    static let scoreProfessionalCommercial = Color(red: 0.0, green: 0.6, blue: 0.0)  // 85-94: Professional Commercial - Dark Green
    static let scoreSemiProfessional = Color.orange                             // 75-84: Semi-Professional
    static let scoreAmateur = Color(red: 1.0, green: 0.6, blue: 0.0)            // 60-74: Amateur/Unmixed
    static let scoreRaw = Color.red                                             // Below 60: Raw/Unprocessed

    // Function to get color based on score - matches "Understanding Your Score" section
    static func scoreColor(for score: Double) -> Color {
        switch score {
        case 95...100: return .scoreReferenceQuality        // Reference Quality - Bright Green
        case 85..<95: return .scoreProfessionalCommercial   // Professional Commercial - Dark Green
        case 75..<85: return .scoreSemiProfessional         // Semi-Professional - Orange
        case 60..<75: return .scoreAmateur                  // Amateur/Unmixed - Orange-Red
        default: return .scoreRaw                           // Raw/Unprocessed - Red
        }
    }
}
