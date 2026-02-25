//
//  AnalysisDisclaimerView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct AnalysisDisclaimerView: View {
    let isPrivacyUpdate: Bool
    let onAccept: () -> Void

    @Environment(\.openURL) private var openURL

    init(isPrivacyUpdate: Bool = false, onAccept: @escaping () -> Void) {
        self.isPrivacyUpdate = isPrivacyUpdate
        self.onAccept = onAccept
    }

    private var privacyURL: URL? {
        guard let urlString = PrivacyConfigService.shared.privacyNotice?.url else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    heroSection
                    featureRows
                }
                .padding(.horizontal, 32)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                Button(action: onAccept) {
                    Text(isPrivacyUpdate ? "Accept & Continue" : "Continue")
                        .font(.interSemiBold(size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color("PrimaryOrange"), in: RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel(isPrivacyUpdate ? "Accept updated privacy notice" : "Continue")
                .accessibilityHint("Accepts that data is processed on-device only and starts using KnowEat")

                Text("By continuing, you agree that KnowEat provides dietary suggestions only (not medical advice) and that your photos and data are processed only on your device.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                if let url = privacyURL {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11))
                            Text("Read our Privacy Policy")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color("PrimaryOrange"))
                    }
                    .padding(.top, 4)
                    .accessibilityLabel("Read our Privacy Policy")
                    .accessibilityHint("Opens the privacy policy in Safari")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Image(systemName: isPrivacyUpdate ? "arrow.triangle.2.circlepath" : "apple.intelligence")
                .font(.system(size: 44))
                .foregroundStyle(Color("PrimaryOrange"))

            Text(isPrivacyUpdate ? "Privacy Policy Updated" : "How KnowEat works")
                .font(.interSemiBold(size: 26))

            Text(isPrivacyUpdate
                 ? "We've updated our privacy policy. Please review the changes below and accept to continue using KnowEat."
                 : "Your menu photos and dietary preferences are processed entirely on your device using Apple Intelligence. We never send your data to third-party AI services.")
                .font(.interRegular(size: 16))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Feature Rows

    private var featureRows: some View {
        VStack(alignment: .leading, spacing: 28) {
            featureRow(
                icon: "lock.shield.fill",
                iconColor: .blue,
                title: "No data sent to third parties",
                subtitle: "Photos of menus, your language preference, and dietary profile are processed only on your device with Apple Intelligence. No third-party AI services receive your data."
            )

            featureRow(
                icon: "person.text.rectangle",
                iconColor: Color("PrimaryOrange"),
                title: "Personalized for you",
                subtitle: "Results are matched against the dietary profile you set up."
            )

            featureRow(
                icon: "hand.raised",
                iconColor: .purple,
                title: "Always double-check",
                subtitle: "We suggest — you decide. Please confirm with restaurant staff before ordering."
            )
        }
    }

    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.interSemiBold(size: 15))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.interRegular(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
    }
}

#Preview("First time") {
    AnalysisDisclaimerView(onAccept: {})
}

#Preview("Privacy update") {
    AnalysisDisclaimerView(isPrivacyUpdate: true, onAccept: {})
}
