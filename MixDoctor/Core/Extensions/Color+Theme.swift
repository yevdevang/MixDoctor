import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    // Purple accent color
    static var avidPink: Color {
        Color(red: 0.435, green: 0.173, blue: 0.871) // #6f2cde
    }
    
    // Use purple as primary accent
    static var primaryAccent: Color {
        avidPink
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
