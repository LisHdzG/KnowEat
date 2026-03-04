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
                VStack(spacing: 32) {
                    heroSection
                    disclaimerCard
                    featureRows
                }
                .padding(.horizontal, 28)
                .padding(.top, 48)
                .padding(.bottom, 24)
            }

            bottomSection
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: isPrivacyUpdate ? "arrow.triangle.2.circlepath" : "apple.intelligence")
                .font(.system(size: 52))
                .foregroundStyle(Color("PrimaryOrange"))
                .padding(.bottom, 4)

            Text(isPrivacyUpdate ? "Privacy Policy Updated" : "How KnowEat works")
                .font(.interSemiBold(size: 28))

            Text(isPrivacyUpdate
                 ? "Please review and accept to continue."
                 : "Your data stays on your device.")
                .font(.interRegular(size: 16))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "apple.intelligence")
                    .font(.system(size: 12))
                Text("Powered by Apple Intelligence")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Disclaimer Card

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)

                Text("Always double-check")
                    .font(.interSemiBold(size: 17))
            }

            Text("KnowEat suggests — you decide. Always confirm with staff for severe allergies.")
                .font(.interRegular(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
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
                subtitle: "All processing happens on-device."
            )

            featureRow(
                icon: "person.text.rectangle",
                iconColor: Color("PrimaryOrange"),
                title: "Personalized for you",
                subtitle: "Results match your dietary profile."
            )
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 16) {
            acceptanceCard

            if let url = privacyURL {
                Button {
                    openURL(url)
                } label: {
                    Text("Read our Privacy Policy")
                        .font(.system(size: 13, weight: .medium))
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
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(hasAccepted ? Color("PrimaryOrange") : Color("PrimaryOrange").opacity(0.3))
                    )
            }
            .disabled(!hasAccepted)
            .animation(.easeInOut(duration: 0.25), value: hasAccepted)
            .accessibilityLabel(isPrivacyUpdate ? "Accept updated privacy notice" : "Continue")
            .accessibilityHint(hasAccepted ? "Continues to the app" : "You must accept the notice first")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 32)
    }

    // MARK: - Acceptance Card

    private var acceptanceCard: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                hasAccepted.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(
                            hasAccepted ? Color("PrimaryOrange") : Color(.systemGray3),
                            lineWidth: 2
                        )
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(hasAccepted ? Color("PrimaryOrange") : .clear)
                        )

                    if hasAccepted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("I understand")
                        .font(.interSemiBold(size: 15))
                        .foregroundStyle(.primary)

                    Text("This is not medical advice")
                        .font(.interRegular(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(hasAccepted ? Color("PrimaryOrange").opacity(0.06) : .clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("I understand this is not medical advice")
        .accessibilityHint(hasAccepted ? "Accepted. Tap to uncheck" : "Tap to accept")
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

                Text(subtitle)
                    .font(.interRegular(size: 14))
                    .foregroundStyle(.secondary)
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
