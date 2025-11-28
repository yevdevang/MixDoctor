//
//  PrivacyView.swift
//  MixDoctor
//
//  Privacy Policy view
//

import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Privacy Policy")
                        .font(.largeTitle.bold())
                        .padding(.bottom, 8)
                    
                    Text("Last updated: November 26, 2025")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 16)
                    
                    sectionView(
                        title: "1. Introduction",
                        content: "MixDoctor (\"we\", \"our\", or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application."
                    )
                    
                    sectionView(
                        title: "2. Information We Collect",
                        content: """
                        We collect the following types of information:
                        
                        • Account Information: Email address and account credentials through Apple Sign-In
                        • Usage Data: App features used, analysis history, and subscription status
                        • Audio Files: Temporary access to audio files you upload for analysis
                        • Device Information: Device type, OS version, and app version
                        • Analytics: Anonymous usage statistics to improve our service
                        """
                    )
                    
                    sectionView(
                        title: "3. How We Use Your Information",
                        content: """
                        Your information is used to:
                        
                        • Provide audio analysis services using AI technology
                        • Manage your subscription and account
                        • Improve app functionality and user experience
                        • Send important updates about your subscription
                        • Provide customer support
                        • Ensure app security and prevent fraud
                        """
                    )
                    
                    sectionView(
                        title: "4. Audio File Processing",
                        content: "Audio files you upload are processed temporarily to generate analysis reports. We do not permanently store your audio files on our servers. Audio files are processed securely and deleted after analysis is complete. We do not share your audio files with third parties."
                    )
                    
                    sectionView(
                        title: "5. iCloud Sync",
                        content: "If you enable iCloud sync, your analysis history and settings will be stored in your personal iCloud account. This data is encrypted and only accessible by you through your iCloud account. We do not have access to your iCloud data."
                    )
                    
                    sectionView(
                        title: "6. Third-Party Services",
                        content: """
                        We use the following third-party services:
                        
                        • RevenueCat: For subscription management and payment processing
                        • Anthropic Claude: For AI-powered audio analysis
                        • Apple CloudKit: For iCloud synchronization
                        
                        These services have their own privacy policies and handle data according to their respective terms.
                        """
                    )
                    
                    sectionView(
                        title: "7. Data Security",
                        content: "We implement appropriate security measures to protect your information. Data transmission is encrypted using industry-standard protocols. However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security."
                    )
                    
                    sectionView(
                        title: "8. Data Retention",
                        content: "We retain your account information and analysis history for as long as your account is active. You can delete your account and associated data at any time through the app settings. Audio files are automatically deleted after analysis completion."
                    )
                    
                    sectionView(
                        title: "9. Your Rights",
                        content: """
                        You have the right to:
                        
                        • Access your personal data
                        • Request correction of inaccurate data
                        • Request deletion of your account and data
                        • Opt-out of marketing communications
                        • Export your analysis history
                        """
                    )
                    
                    sectionView(
                        title: "10. Children's Privacy",
                        content: "MixDoctor is not intended for use by children under 13 years of age. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately."
                    )
                    
                    sectionView(
                        title: "11. Changes to Privacy Policy",
                        content: "We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new Privacy Policy in the app. Your continued use after changes indicates acceptance of the updated policy."
                    )
                    
                    sectionView(
                        title: "12. Contact Us",
                        content: "If you have questions or concerns about this Privacy Policy or our data practices, please contact us through the App Store or the support section within the App."
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
    PrivacyView()
}
