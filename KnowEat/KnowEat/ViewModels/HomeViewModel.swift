//
//  HomeViewModel.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

@Observable
final class HomeViewModel {
    private(set) var allergens: [Allergen] = []

    init() {
        loadAllergens()
    }

    func activeFilters(for profile: UserProfile) -> [Allergen] {
        allergens.filter { profile.allergenIds.contains($0.id) }
    }

    private func loadAllergens() {
        guard let url = Bundle.main.url(forResource: "allergens", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Allergen].self, from: data) else { return }
        allergens = decoded
    }
}
