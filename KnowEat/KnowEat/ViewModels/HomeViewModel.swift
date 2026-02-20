//
//  HomeViewModel.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct DietaryFilterGroup: Identifiable {
    let id: String
    let title: String
    let icon: String
    let items: [Allergen]
}

@Observable
final class HomeViewModel {
    private(set) var allergens: [Allergen] = []
    private(set) var intolerances: [Allergen] = []
    private(set) var conditions: [Allergen] = []
    private(set) var diets: [Allergen] = []
    private(set) var situations: [Allergen] = []

    var allDietaryItems: [Allergen] {
        allergens + intolerances + conditions + diets + situations
    }

    init() {
        allergens = Self.loadJSON("allergens")
        intolerances = Self.loadJSON("intolerances")
        conditions = Self.loadJSON("conditions")
        diets = Self.loadJSON("diets")
        situations = Self.loadJSON("situations")
    }

    func activeFilters(for profile: UserProfile) -> [Allergen] {
        let allSelectedIds = Set(
            profile.allergenIds
            + profile.intoleranceIds
            + profile.conditionIds
            + profile.dietIds
            + profile.situationIds
        )
        return allDietaryItems.filter { allSelectedIds.contains($0.id) }
    }

    func groupedFilters(for profile: UserProfile) -> [DietaryFilterGroup] {
        let groups: [(String, String, String, [String])] = [
            ("allergens", "Allergens", "exclamationmark.shield.fill", profile.allergenIds),
            ("intolerances", "Intolerances", "pills.fill", profile.intoleranceIds),
            ("conditions", "Conditions", "heart.text.clipboard.fill", profile.conditionIds),
            ("diets", "Diets", "fork.knife", profile.dietIds),
            ("situations", "Situations", "figure.and.child.holdinghands", profile.situationIds),
        ]

        let catalogs: [String: [Allergen]] = [
            "allergens": allergens,
            "intolerances": intolerances,
            "conditions": conditions,
            "diets": diets,
            "situations": situations,
        ]

        return groups.compactMap { id, title, icon, selectedIds in
            guard !selectedIds.isEmpty,
                  let catalog = catalogs[id] else { return nil }
            let items = catalog.filter { selectedIds.contains($0.id) }
            guard !items.isEmpty else { return nil }
            return DietaryFilterGroup(id: id, title: title, icon: icon, items: items)
        }
    }

    private static func loadJSON(_ name: String) -> [Allergen] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Allergen].self, from: data) else { return [] }
        return decoded
    }
}
