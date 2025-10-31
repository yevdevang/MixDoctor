//
//  FrequencySpectrumImageService.swift
//  MixDoctor
//
//  Service for handling frequency spectrum images from ChatGPT
//

import Foundation
import UIKit

actor FrequencySpectrumImageService {
    
    // MARK: - Image Storage
    
    private let imageDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("FrequencySpectrumImages")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir
    }()
    
    /// Save base64 image data to file
    func saveImage(base64String: String, forAudioFileID: UUID) async throws -> URL {
        // Extract image data from base64 string (remove "data:image/png;base64," prefix if present)
        var cleanedBase64 = base64String
        if let range = base64String.range(of: "base64,") {
            cleanedBase64 = String(base64String[range.upperBound...])
        }
        
        guard let imageData = Data(base64Encoded: cleanedBase64) else {
            throw ImageError.invalidBase64
        }
        
        // Verify it's a valid image
        guard UIImage(data: imageData) != nil else {
            throw ImageError.invalidImageData
        }
        
        // Save to file
        let filename = "\(forAudioFileID.uuidString).png"
        let fileURL = imageDirectory.appendingPathComponent(filename)
        
        try imageData.write(to: fileURL)
        
        print("🖼️ Saved frequency spectrum image: \(filename)")
        
        return fileURL
    }
    
    /// Load image from file
    func loadImage(forAudioFileID: UUID) async throws -> UIImage {
        let filename = "\(forAudioFileID.uuidString).png"
        let fileURL = imageDirectory.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ImageError.imageNotFound
        }
        
        guard let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            throw ImageError.invalidImageData
        }
        
        return image
    }
    
    /// Check if image exists for audio file
    func hasImage(forAudioFileID: UUID) async -> Bool {
        let filename = "\(forAudioFileID.uuidString).png"
        let fileURL = imageDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Delete image for audio file
    func deleteImage(forAudioFileID: UUID) async throws {
        let filename = "\(forAudioFileID.uuidString).png"
        let fileURL = imageDirectory.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Deleted frequency spectrum image: \(filename)")
        }
    }
    
    /// Delete all images
    func deleteAllImages() async throws {
        let contents = try FileManager.default.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil)
        
        for fileURL in contents {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        print("🗑️ Deleted all frequency spectrum images")
    }
}

// MARK: - Errors

enum ImageError: LocalizedError {
    case invalidBase64
    case invalidImageData
    case imageNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return "Invalid base64 image data"
        case .invalidImageData:
            return "Invalid image data"
        case .imageNotFound:
            return "Frequency spectrum image not found"
        }
    }
}
