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
    @State private var hasAccepted = false

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
                VStack(spacing: 28) {
                    heroSection
                    disclaimerCard
                    featureRows
                }
                .padding(.horizontal, 32)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }

            VStack(spacing: 16) {
                acceptanceToggle

                if let url = privacyURL {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11))
                            Text("Read our Privacy Policy")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color("PrimaryOrange"))
                    }
                    .accessibilityLabel("Read our Privacy Policy")
                    .accessibilityHint("Opens the privacy policy in Safari")
                }

                Button(action: onAccept) {
                    Text(isPrivacyUpdate ? "Accept & Continue" : "Continue")
                        .font(.interSemiBold(size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(hasAccepted ? Color("PrimaryOrange") : Color("PrimaryOrange").opacity(0.35))
                        )
                }
                .disabled(!hasAccepted)
                .animation(.easeInOut(duration: 0.2), value: hasAccepted)
                .accessibilityLabel(isPrivacyUpdate ? "Accept updated privacy notice" : "Continue")
                .accessibilityHint(hasAccepted ? "Continues to the app" : "You must accept the notice first")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Image(systemName: isPrivacyUpdate ? "arrow.triangle.2.circlepath" : "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color("PrimaryOrange"))

            Text(isPrivacyUpdate ? "Privacy Policy Updated" : "How KnowEat works")
                .font(.interSemiBold(size: 26))

            Text(isPrivacyUpdate
                 ? "We've updated our privacy policy. Please review and accept to continue."
                 : "Your data is processed entirely on your device. Nothing is sent externally.")
                .font(.interRegular(size: 15))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Disclaimer Card

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.orange)
                .frame(width: 34, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text("Always double-check")
                    .font(.interSemiBold(size: 17))

                Text("KnowEat suggests — you decide. Always confirm with restaurant staff, especially for severe allergies.")
                    .font(.interRegular(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Feature Rows

    private var featureRows: some View {
        VStack(alignment: .leading, spacing: 24) {
            featureRow(
                icon: "lock.shield.fill",
                iconColor: .blue,
                title: "Private & secure",
                subtitle: "All processing happens on your device."
            )

            featureRow(
                icon: "person.text.rectangle",
                iconColor: Color("PrimaryOrange"),
                title: "Personalized for you",
                subtitle: "Results match your dietary profile."
            )
        }
    }

    // MARK: - Acceptance Toggle

    private var acceptanceToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                hasAccepted.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: hasAccepted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(hasAccepted ? Color("PrimaryOrange") : Color(.systemGray3))

                Text("I understand this is not medical advice")
                    .font(.interRegular(size: 14))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("I understand this is not medical advice")
        .accessibilityHint(hasAccepted ? "Checked. Tap to uncheck" : "Unchecked. Tap to accept")
        .accessibilityAddTraits(hasAccepted ? [.isButton, .isSelected] : .isButton)
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
