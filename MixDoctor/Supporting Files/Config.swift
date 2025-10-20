//
//  Config.swift
//  MixDoctor
//
//  Configuration management for secure API keys
//

import Foundation

enum Config {
    /// OpenAI API Key loaded from Info.plist
    static var openAIAPIKey: String {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
              !key.isEmpty,
              key != "YOUR_OPENAI_API_KEY_HERE" else {
            fatalError("""
                ⚠️ OpenAI API Key not configured!
                
                Please follow these steps:
                1. Copy Config.xcconfig.template to Config.xcconfig
                2. Add your OpenAI API key to Config.xcconfig
                3. Get your key from: https://platform.openai.com/api-keys
                """)
        }
        return key
    }
}
