//
//  ContentView.swift
//  KnowEat
//
//  Created by Lisette HG on 19/02/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(UserProfileStore.self) private var profileStore

    var body: some View {
        if profileStore.hasCompletedOnboarding {
            HomeView()
        } else {
            WelcomeView()
        }
    }
}

#Preview {
    ContentView()
        .environment(UserProfileStore())
}
