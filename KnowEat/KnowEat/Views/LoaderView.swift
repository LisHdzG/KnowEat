//
//  LoaderView.swift
//  KnowEat
//

import SwiftUI

struct LoaderView: View {
    private static let gifNames = ["LoaderTomato", "LoaderEggs"]

    private static let phrases = [
        "Reading every dish on the menu…",
        "Checking ingredients carefully…",
        "Matching with your allergen profile…",
        "Almost there, analyzing details…",
        "Making sure everything is safe for you…"
    ]

    @State private var currentPhrase: String
    private let selectedGIF: String

    init() {
        let gif = Self.gifNames.randomElement() ?? Self.gifNames[0]
        let phrase = Self.phrases.randomElement() ?? Self.phrases[0]
        selectedGIF = gif
        _currentPhrase = State(initialValue: phrase)
    }

    var body: some View {
        VStack(spacing: 32) {
            GIFImageView(name: selectedGIF)
                .frame(width: 180, height: 180)

            Text(currentPhrase)
                .font(.interMedium(size: 15))
                .foregroundStyle(Color("SecondaryGray").opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.4), value: currentPhrase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            startPhraseRotation()
        }
    }

    private func startPhraseRotation() {
        Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation {
                    currentPhrase = Self.phrases.filter { $0 != currentPhrase }.randomElement() ?? Self.phrases[0]
                }
            }
        }
    }
}

#Preview {
    LoaderView()
}
