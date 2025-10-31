//
//  FrequencySpectrumImageView.swift
//  MixDoctor
//
//  View for displaying frequency spectrum images from ChatGPT
//

import SwiftUI

struct FrequencySpectrumImageView: View {
    let audioFileID: UUID
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var error: String?
    
    private let imageService = FrequencySpectrumImageService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Frequency Spectrum", systemImage: "waveform.path")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if !isLoading {
                HStack {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                    Text("No frequency spectrum available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        error = nil
        
        do {
            let hasImage = await imageService.hasImage(forAudioFileID: audioFileID)
            
            if hasImage {
                let loadedImage = try await imageService.loadImage(forAudioFileID: audioFileID)
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load image: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

#Preview {
    FrequencySpectrumImageView(audioFileID: UUID())
        .padding()
}
