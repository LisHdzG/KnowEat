//
//  LoaderView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct LoaderView: View {
    var progress: Double? = nil
    var stage: String? = nil
    var strings: AppStrings = AppStrings()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let gifNames = ["LoaderTomato", "LoaderEggs"]

    private static let defaultPhrases = [
        "Reading every dish on the menu…",
        "Checking ingredients carefully…",
        "Matching with your allergen profile…",
        "Almost there, analyzing details…",
        "Making sure everything is safe for you…"
    ]

    private let phrases: [String]
    @State private var currentPhrase: String
    @State private var displayedProgress: Double = 0
    private let selectedGIF: String

    init(progress: Double? = nil, stage: String? = nil, phrases: [String]? = nil, strings: AppStrings = AppStrings()) {
        self.progress = progress
        self.stage = stage
        self.strings = strings
        let p = phrases ?? Self.defaultPhrases
        self.phrases = p
        let gif = Self.gifNames.randomElement() ?? Self.gifNames[0]
        selectedGIF = gif
        _currentPhrase = State(initialValue: p.randomElement() ?? p[0])
    }

    var body: some View {
        VStack(spacing: 28) {
            GIFImageView(name: selectedGIF, animate: !reduceMotion)
                .frame(width: 180, height: 180)
                .accessibilityHidden(true)

            VStack(spacing: 18) {
                if progress != nil {
                    progressBar
                }

                Text(stage ?? currentPhrase)
                    .font(.interMedium(.subheadline))
                    .foregroundStyle(Color("SecondaryGray").opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: stage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(strings.analyzingMenu)
        .accessibilityHint(stage ?? currentPhrase)
        .onAppear {
            if progress == nil { startPhraseRotation() }
        }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                displayedProgress = newValue ?? 0
            } else {
                withAnimation(.easeInOut(duration: 0.6)) {
                    displayedProgress = newValue ?? 0
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray5))

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color("PrimaryOrange"))
                    .frame(width: geo.size.width * displayedProgress)
            }
        }
        .frame(height: 5)
        .padding(.horizontal, 60)
        .accessibilityLabel(strings.analyzingMenu)
        .accessibilityValue(strings.progressPercent(Int(displayedProgress * 100)))
    }

    private func startPhraseRotation() {
        guard !reduceMotion else { return }
        Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation {
                    currentPhrase = phrases.filter { $0 != currentPhrase }.randomElement() ?? phrases[0]
                }
            }
        }
    }
}

#Preview {
    LoaderView()
}

#Preview("With Progress") {
    LoaderView(progress: 0.45, stage: "Analyzing dishes…")
}
