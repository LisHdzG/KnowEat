//
//  AnalysisDisclaimerView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct AnalysisDisclaimerView: View {
    let onAccept: () -> Void

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
                    Text("Continue")
                        .font(.interSemiBold(size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color("PrimaryOrange"), in: RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Continue")
                .accessibilityHint("Accepts the terms and starts using KnowEat")

                Text("By continuing you agree that KnowEat provides dietary suggestions only and is not a medical tool.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 44))
                .foregroundStyle(Color("PrimaryOrange"))

            Text("How KnowEat works")
                .font(.interSemiBold(size: 26))

            Text("Here's how we help you eat safely")
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
                icon: "iphone",
                iconColor: .blue,
                title: "Private on-device analysis",
                subtitle: "Menus are analyzed using Apple Intelligence. Nothing leaves your device."
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

#Preview {
    AnalysisDisclaimerView(onAccept: {})
}
