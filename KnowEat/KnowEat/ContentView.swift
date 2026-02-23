//
//  ContentView.swift
//  KnowEat
//
//  Created by Lisette HG on 19/02/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(UserProfileStore.self) private var profileStore

    private var showAnalysisDisclaimer: Bool {
        profileStore.hasCompletedOnboarding && !profileStore.hasAcceptedAnalysisDisclaimer
    }

    var body: some View {
        Group {
            if profileStore.hasCompletedOnboarding {
                HomeView()
            } else {
                WelcomeView()
            }
        }
        .sheet(isPresented: .constant(showAnalysisDisclaimer)) {
            AnalysisDisclaimerView {
                profileStore.acceptAnalysisDisclaimer()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .interactiveDismissDisabled()
        }
    }
}

#Preview {
    ContentView()
        .environment(UserProfileStore())
}
