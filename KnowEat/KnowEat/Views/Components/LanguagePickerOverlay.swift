//
//  LanguagePickerOverlay.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct LanguagePickerOverlay: View {
    @Binding var selectedLanguage: String
    let languages: [String]
    @Binding var isPresented: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var sheetAppeared = false

    private let sheetHeight: CGFloat = 420
    private let dismissThreshold: CGFloat = 100

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(sheetAppeared ? Double(0.35 * max(0, 1 - dragOffset / sheetHeight)) : 0)
                .ignoresSafeArea()
                .onTapGesture { animateDismiss() }

            sheetContent
                .offset(y: sheetAppeared ? max(0, dragOffset) : sheetHeight)
                .gesture(dragGesture)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                sheetAppeared = true
            }
        }
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {
            grabHandle

            Image(systemName: "globe")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color("PrimaryOrange"))
                .padding(.bottom, 8)

            Text("Select Language")
                .font(.interSemiBold(size: 20))
                .padding(.bottom, 4)

            Text("Choose your preferred language")
                .font(.interRegular(size: 13))
                .foregroundStyle(Color("SecondaryGray"))
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                ForEach(languages, id: \.self) { language in
                    languageCard(language)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        )
    }

    private var grabHandle: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 16)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold ||
                   value.predictedEndTranslation.height > sheetHeight * 0.5 {
                    animateDismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func languageCard(_ language: String) -> some View {
        let isActive = language == selectedLanguage

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedLanguage = language
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                animateDismiss()
            }
        } label: {
            HStack(spacing: 14) {
                Text(flagEmoji(for: language))
                    .font(.system(size: 36))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                Text(language)
                    .font(.interSemiBold(size: 16))
                    .foregroundStyle(isActive ? Color("PrimaryOrange") : .primary)

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(
                            isActive ? Color("PrimaryOrange") : Color(.systemGray4),
                            lineWidth: 2
                        )
                        .frame(width: 26, height: 26)

                    if isActive {
                        Circle()
                            .fill(Color("PrimaryOrange"))
                            .frame(width: 16, height: 16)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? Color("PrimaryOrange").opacity(0.08) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isActive ? Color("PrimaryOrange").opacity(0.4) : .clear,
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func flagEmoji(for language: String) -> String {
        switch language {
        case "English": return "\u{1F1FA}\u{1F1F8}"
        case "Español": return "\u{1F1EA}\u{1F1F8}"
        case "Italiano": return "\u{1F1EE}\u{1F1F9}"
        default: return "\u{1F310}"
        }
    }

    private func animateDismiss() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            sheetAppeared = false
            dragOffset = sheetHeight
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }
}
