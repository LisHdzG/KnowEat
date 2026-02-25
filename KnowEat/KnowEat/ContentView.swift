//
//  ContentView.swift
//  KnowEat
//
//  Created by Lisette HG on 19/02/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(UserProfileStore.self) private var profileStore
    @State private var showSplash = true
    @State private var privacyConfig = PrivacyConfigService.shared

    private var showAnalysisDisclaimer: Bool {
        profileStore.hasCompletedOnboarding && !profileStore.hasAcceptedAnalysisDisclaimer
    }

    private var showPrivacyUpdate: Bool {
        profileStore.hasCompletedOnboarding
        && profileStore.hasAcceptedAnalysisDisclaimer
        && privacyConfig.isLoaded
        && profileStore.needsPrivacyUpdate(remoteVersion: privacyConfig.privacyNotice?.version)
    }

    var body: some View {
        ZStack {
            Group {
                if profileStore.hasCompletedOnboarding {
                    HomeView()
                } else {
                    WelcomeView()
                }
            }
            .task {
                await PrivacyConfigService.shared.fetch()
            }
            .sheet(isPresented: .constant(showAnalysisDisclaimer && !showSplash)) {
                AnalysisDisclaimerView {
                    profileStore.acceptAnalysisDisclaimer()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: .constant(showPrivacyUpdate && !showSplash)) {
                AnalysisDisclaimerView(isPrivacyUpdate: true) {
                    profileStore.acceptAnalysisDisclaimer()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .interactiveDismissDisabled()
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(UserProfileStore())
}
