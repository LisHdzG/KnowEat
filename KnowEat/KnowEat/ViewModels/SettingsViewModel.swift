//
//  SettingsViewModel.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

@Observable
final class SettingsViewModel {
    let availableLanguages = ["English", "Español", "Italiano"]

    var selectedLanguage: String = "English"
    var showLanguagePicker = false
    private(set) var allergens: [Allergen] = []
    var selectedAllergens: Set<String> = []

    init() {
        loadAllergens()
    }

    func load(from profile: UserProfile) {
        selectedLanguage = profile.nativeLanguage
        selectedAllergens = Set(profile.allergenIds)
    }

    func toggleAllergen(_ id: String) {
        if selectedAllergens.contains(id) {
            selectedAllergens.remove(id)
        } else {
            selectedAllergens.insert(id)
        }
    }

    func isSelected(_ id: String) -> Bool {
        selectedAllergens.contains(id)
    }

    func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "KnowEat V\(version).\(build)"
    }

    private func loadAllergens() {
        guard let url = Bundle.main.url(forResource: "allergens", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Allergen].self, from: data) else { return }
        allergens = decoded
    }
}
