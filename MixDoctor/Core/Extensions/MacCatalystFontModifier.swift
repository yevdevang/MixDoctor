//
//  MacCatalystFontModifier.swift
//  MixDoctor
//
//  Global font scaling for Mac Catalyst
//

import SwiftUI

struct MacCatalystFontScaling: ViewModifier {
    let scale: CGFloat
    
    init(scale: CGFloat = 1.3) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        content
            .environment(\.dynamicTypeSize, .xxxLarge) // This increases all system fonts
        #else
        content
        #endif
    }
}

extension View {
    func macCatalystFontScaling(_ scale: CGFloat = 1.3) -> some View {
        modifier(MacCatalystFontScaling(scale: scale))
    }
}
