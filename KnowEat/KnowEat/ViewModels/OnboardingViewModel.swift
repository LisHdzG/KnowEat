//
//  OnboardingViewModel.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

@Observable
final class OnboardingViewModel {
    var allergens: [Allergen] = []
    var selectedAllergens: Set<String> = []
    var selectedLanguage = "English"

    let availableLanguages = ["English", "Español", "Italiano"]

    init() {
        loadAllergens()
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

    private func loadAllergens() {
        guard let url = Bundle.main.url(forResource: "allergens", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Allergen].self, from: data) else {
            return
        }
        allergens = decoded
    }
}
