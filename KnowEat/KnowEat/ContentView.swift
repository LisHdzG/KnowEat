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

    private var showPrivacyUpdate: Bool {
        profileStore.hasAcceptedAnalysisDisclaimer
        && privacyConfig.isLoaded
        && profileStore.needsPrivacyUpdate(remoteVersion: privacyConfig.privacyNotice?.version)
    }

    private var showPrivacySheet: Bool {
        (!profileStore.hasAcceptedAnalysisDisclaimer || showPrivacyUpdate) && !showSplash
    }

    var body: some View {
        ZStack {
            Group {
                HomeView()
            }
            .task {
                await PrivacyConfigService.shared.fetch()
            }
            .sheet(isPresented: .constant(showPrivacySheet)) {
                AnalysisDisclaimerView(isPrivacyUpdate: showPrivacyUpdate) {
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
