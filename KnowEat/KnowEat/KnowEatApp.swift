//
//  KnowEatApp.swift
//  KnowEat
//
//  Created by Lisette HG on 19/02/26.
//

import SwiftUI
import CoreText

@main
struct KnowEatApp: App {
    @State private var profileStore = UserProfileStore()
    @State private var menuStore = MenuStore()

    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(profileStore)
                .environment(menuStore)
        }
    }

    private func registerCustomFonts() {
        let fonts = ["Italianno-Regular", "Inter-Regular", "Inter-Medium", "Inter-SemiBold"]
        for font in fonts {
            guard let url = Bundle.main.url(forResource: font, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
