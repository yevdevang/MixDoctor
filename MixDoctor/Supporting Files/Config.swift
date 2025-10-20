//
//  Config.swift
//  MixDoctor
//
//  Configuration management for secure API keys
//

import Foundation

enum Config {
    /// OpenAI API Key loaded from build configuration
    static var openAIAPIKey: String {
        // Try to get from Info.plist first
        if let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
           !key.isEmpty,
           key != "YOUR_OPENAI_API_KEY_HERE",
           key != "$(OPENAI_API_KEY)" {
            return key
        }
        
        // Fallback error message
        fatalError("""
            ⚠️ OpenAI API Key not configured!
            
            Please follow these steps:
            1. Copy Config.xcconfig.template to Config.xcconfig
            2. Add your OpenAI API key to Config.xcconfig
            3. Get your key from: https://platform.openai.com/api-keys
            4. Rebuild the project in Xcode
            """)
    }
}
