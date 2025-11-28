//
//  TermsView.swift
//  MixDoctor
//
//  Terms of Service view
//

import SwiftUI

struct TermsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Terms of Service")
                        .font(.largeTitle.bold())
                        .padding(.bottom, 8)
                    
                    Text("Last updated: November 26, 2025")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 16)
                    
                    sectionView(
                        title: "1. Acceptance of Terms",
                        content: "By accessing and using MixDoctor (\"the App\"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to these terms, please do not use the App."
                    )
                    
                    sectionView(
                        title: "2. Use License",
                        content: "MixDoctor grants you a personal, non-transferable, non-exclusive license to use the App on your devices in accordance with the terms of this Agreement."
                    )
                    
                    sectionView(
                        title: "3. Subscription Terms",
                        content: """
                        • Free users receive 3 audio analyses per month
                        • Pro subscription provides 50 analyses per month
                        • 7-day free trial is available for new Pro subscribers
                        • Subscriptions auto-renew unless cancelled 24 hours before the period ends
                        • Payment will be charged to your Apple ID account
                        • You can manage or cancel your subscription in App Store settings
                        """
                    )
                    
                    sectionView(
                        title: "4. User Responsibilities",
                        content: """
                        You agree to:
                        • Use the App only for lawful purposes
                        • Not reverse engineer or attempt to extract the source code
                        • Not upload content that infringes on third-party rights
                        • Maintain the security of your account credentials
                        """
                    )
                    
                    sectionView(
                        title: "5. Audio Files and Content",
                        content: "You retain all rights to audio files you upload to the App. MixDoctor processes your audio files to provide analysis and does not claim ownership of your content. We do not share your audio files with third parties."
                    )
                    
                    sectionView(
                        title: "6. AI Analysis Disclaimer",
                        content: "The AI-powered analysis provided by MixDoctor is for informational and educational purposes. While we strive for accuracy, the analysis should be used as a guide and not as absolute professional advice. Results may vary based on audio quality and other factors."
                    )
                    
                    sectionView(
                        title: "7. Limitation of Liability",
                        content: "MixDoctor is provided \"as is\" without warranties of any kind. We shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use or inability to use the App."
                    )
                    
                    sectionView(
                        title: "8. Changes to Terms",
                        content: "We reserve the right to modify these terms at any time. We will notify users of any material changes. Your continued use of the App after changes constitutes acceptance of the modified terms."
                    )
                    
                    sectionView(
                        title: "9. Termination",
                        content: "We may terminate or suspend your access to the App immediately, without prior notice, for any breach of these Terms. Upon termination, your right to use the App will immediately cease."
                    )
                    
                    sectionView(
                        title: "10. Contact Information",
                        content: "For questions about these Terms of Service, please contact us through the App Store or the support section within the App."
                    )
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(red: 0.435, green: 0.173, blue: 0.871))
                    }
                }
            }
        }
    }
    
    private func sectionView(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    TermsView()
}
