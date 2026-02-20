//
//  SettingsViewModel.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

enum DietaryCategory {
    case allergens, intolerances, conditions, diets, situations
}

@Observable
final class SettingsViewModel {
    let availableLanguages = ["English", "Español", "Italiano"]

    var selectedLanguage: String = "English"
    var showLanguagePicker = false

    private(set) var allergens: [Allergen] = []
    private(set) var intolerances: [Allergen] = []
    private(set) var conditions: [Allergen] = []
    private(set) var diets: [Allergen] = []
    private(set) var situations: [Allergen] = []

    var selectedAllergens: Set<String> = []
    var selectedIntolerances: Set<String> = []
    var selectedConditions: Set<String> = []
    var selectedDiets: Set<String> = []
    var selectedSituations: Set<String> = []

    init() {
        allergens = Self.loadJSON("allergens")
        intolerances = Self.loadJSON("intolerances")
        conditions = Self.loadJSON("conditions")
        diets = Self.loadJSON("diets")
        situations = Self.loadJSON("situations")
    }

    func load(from profile: UserProfile) {
        selectedLanguage = profile.nativeLanguage
        selectedAllergens = Set(profile.allergenIds)
        selectedIntolerances = Set(profile.intoleranceIds)
        selectedConditions = Set(profile.conditionIds)
        selectedDiets = Set(profile.dietIds)
        selectedSituations = Set(profile.situationIds)
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

    func selectedIds(for category: DietaryCategory) -> Set<String> {
        switch category {
        case .allergens: selectedAllergens
        case .intolerances: selectedIntolerances
        case .conditions: selectedConditions
        case .diets: selectedDiets
        case .situations: selectedSituations
        }
    }

    func toggleAllergen(_ id: String) {
        toggle(id, category: .allergens)
    }

    func isSelected(_ id: String) -> Bool {
        isSelected(id, category: .allergens)
    }

    func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "KnowEat V\(version).\(build)"
    }

    private static func loadJSON(_ name: String) -> [Allergen] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Allergen].self, from: data) else { return [] }
        return decoded
    }
}
