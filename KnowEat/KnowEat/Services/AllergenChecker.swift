//
//  AllergenChecker.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

enum AllergenChecker {
    static func analyze(menu: ScannedMenu, userAllergenIds: [String]) -> [AnalyzedDish] {
        menu.dishes.map { dish in
            let matched = dish.allergenIds.filter { userAllergenIds.contains($0) }
            return AnalyzedDish(
                dish: dish,
                isSafe: matched.isEmpty,
                matchedAllergenIds: matched
            )
        }
    }

    static func analyze(menu: ScannedMenu, profile: UserProfile) -> [AnalyzedDish] {
        let allIds = profile.allergenIds
            + profile.intoleranceIds
            + profile.conditionIds
            + profile.dietIds
            + profile.situationIds
        return analyze(menu: menu, userAllergenIds: allIds)
    }

    static func safeCount(in analyzed: [AnalyzedDish]) -> Int {
        analyzed.filter(\.isSafe).count
    }

    static func unsafeCount(in analyzed: [AnalyzedDish]) -> Int {
        analyzed.filter { !$0.isSafe }.count
    }
}
