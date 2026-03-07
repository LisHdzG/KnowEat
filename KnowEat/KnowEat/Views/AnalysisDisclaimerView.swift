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

    @Environment(UserProfileStore.self) private var profileStore
    @Environment(\.openURL) private var openURL
    @State private var hasAccepted = false

    private var strings: AppStrings {
        AppStrings(profileStore.profile?.nativeLanguage ?? "English")
    }

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
                    if isPrivacyUpdate {
                        disclaimerCard
                    }
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
            Image(systemName: isPrivacyUpdate ? "arrow.triangle.2.circlepath" : "doc.text.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color("PrimaryOrange"))
                .padding(.bottom, 4)

            Text(isPrivacyUpdate ? strings.privacyPolicyUpdated : strings.howKnowEatWorks)
                .font(.interSemiBold(size: 28))

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

                Text(strings.alwaysDoubleCheck)
                    .font(.interSemiBold(size: 17))
            }

            Text(strings.suggestsYouDecide)
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
                icon: "hand.raised.fill",
                iconColor: Color(red: 0.45, green: 0.35, blue: 0.85),
                title: strings.alwaysDoubleCheck,
                subtitle: strings.doubleCheckDesc
            )
            featureRow(
                icon: "lock.shield.fill",
                iconColor: Color(red: 0.25, green: 0.48, blue: 0.85),
                title: strings.noDataSent,
                subtitle: strings.noDataSentDesc
            )
            featureRow(
                icon: "person.text.rectangle",
                iconColor: Color("PrimaryOrange"),
                title: strings.personalizedForYou,
                subtitle: strings.personalizedDesc
            )
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 16) {
            acceptanceCard

            Button(action: onAccept) {
                Text(isPrivacyUpdate ? strings.acceptContinue : strings.continueButton)
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
            .accessibilityLabel(isPrivacyUpdate ? strings.acceptUpdatedPrivacyNotice : strings.continueButton)
            .accessibilityHint(hasAccepted ? strings.continuesToApp : strings.mustAcceptFirst)
            
            if let url = privacyURL {
                Button {
                    openURL(url)
                } label: {
                    Text(strings.readPrivacyPolicy)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("PrimaryOrange"))
                }
                .accessibilityLabel(strings.readPrivacyPolicy)
                .accessibilityHint(strings.opensPrivacyInSafari)
            }

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
            HStack(spacing: 16) {

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                hasAccepted ? Color("PrimaryOrange") : Color(.systemGray4),
                                lineWidth: 2
                            )
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(hasAccepted ? Color("PrimaryOrange") : Color(.secondarySystemBackground))
                            )

                        if hasAccepted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text(strings.understandNotMedical)
                        .font(.interSemiBold(size: 12))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                hasAccepted ? Color("PrimaryOrange").opacity(0.3) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(strings.understandNotMedical)
        .accessibilityHint(hasAccepted ? strings.acceptedTapToUncheck : strings.tapToAccept)
        .accessibilityAddTraits(hasAccepted ? [.isButton, .isSelected] : .isButton)
    }

    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String, smallSubtitle: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.interSemiBold(size: 15))

                Text(subtitle)
                    .font(smallSubtitle ? .interRegular(size: 11) : .interRegular(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(smallSubtitle ? 1.5 : 2)
            }
        }
    }
}

#Preview("First time") {
    AnalysisDisclaimerView(onAccept: {})
        .environment(UserProfileStore())
}

#Preview("Privacy update") {
    AnalysisDisclaimerView(isPrivacyUpdate: true, onAccept: {})
        .environment(UserProfileStore())
}
