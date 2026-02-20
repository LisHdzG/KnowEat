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
    var intolerances: [Allergen] = []
    var conditions: [Allergen] = []
    var diets: [Allergen] = []
    var situations: [Allergen] = []

    var selectedAllergens: Set<String> = []
    var selectedIntolerances: Set<String> = []
    var selectedConditions: Set<String> = []
    var selectedDiets: Set<String> = []
    var selectedSituations: Set<String> = []

    var selectedLanguage = "English"
    let availableLanguages = ["English", "Español", "Italiano"]

    init() {
        allergens = Self.loadJSON("allergens")
        intolerances = Self.loadJSON("intolerances")
        conditions = Self.loadJSON("conditions")
        diets = Self.loadJSON("diets")
        situations = Self.loadJSON("situations")
    }

    func toggle(_ id: String, category: DietaryCategory) {
        switch category {
        case .allergens:
            if selectedAllergens.contains(id) { selectedAllergens.remove(id) } else { selectedAllergens.insert(id) }
        case .intolerances:
            if selectedIntolerances.contains(id) { selectedIntolerances.remove(id) } else { selectedIntolerances.insert(id) }
        case .conditions:
            if selectedConditions.contains(id) { selectedConditions.remove(id) } else { selectedConditions.insert(id) }
        case .diets:
            if selectedDiets.contains(id) { selectedDiets.remove(id) } else { selectedDiets.insert(id) }
        case .situations:
            if selectedSituations.contains(id) { selectedSituations.remove(id) } else { selectedSituations.insert(id) }
        }
    }

    func isSelected(_ id: String, category: DietaryCategory) -> Bool {
        switch category {
        case .allergens: selectedAllergens.contains(id)
        case .intolerances: selectedIntolerances.contains(id)
        case .conditions: selectedConditions.contains(id)
        case .diets: selectedDiets.contains(id)
        case .situations: selectedSituations.contains(id)
        }
    }

    func toggleAllergen(_ id: String) { toggle(id, category: .allergens) }
    func isSelected(_ id: String) -> Bool { isSelected(id, category: .allergens) }

    func buildProfile() -> UserProfile {
        UserProfile(
            nativeLanguage: selectedLanguage,
            allergenIds: Array(selectedAllergens),
            intoleranceIds: Array(selectedIntolerances),
            conditionIds: Array(selectedConditions),
            dietIds: Array(selectedDiets),
            situationIds: Array(selectedSituations),
            saveHistory: true
        )
    }

    private static func loadJSON(_ name: String) -> [Allergen] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Allergen].self, from: data) else { return [] }
        return decoded
    }
}
