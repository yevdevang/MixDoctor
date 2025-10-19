import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    static let primaryAccent = Color("AccentColor")
    #if canImport(UIKit)
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let secondaryText = Color(UIColor.secondaryLabel)
    #else
    static let backgroundPrimary = Color.white
    static let backgroundSecondary = Color.gray.opacity(0.15)
    static let secondaryText = Color.gray
    #endif
}
