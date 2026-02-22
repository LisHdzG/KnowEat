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
                matchedAllergenIds: matched,
                matchedConditionIds: [],
                matchedIntoleranceIds: [],
                matchedDietIds: [],
                matchedSituationIds: []
            )
        }
    }

    static func analyze(menu: ScannedMenu, profile: UserProfile) -> [AnalyzedDish] {
        let allergenSet = Set(profile.allergenIds)
        let conditionSet = Set(profile.conditionIds)
        let intoleranceSet = Set(profile.intoleranceIds)
        let dietSet = Set(profile.dietIds)
        let situationSet = Set(profile.situationIds)

        return menu.dishes.map { dish in
            let dishIds = Set(dish.allergenIds)

            let allergens = dishIds.intersection(allergenSet).sorted()
            let conditions = dishIds.intersection(conditionSet).sorted()
            let intolerances = dishIds.intersection(intoleranceSet).sorted()
            let diets = dishIds.intersection(dietSet).sorted()
            let situations = dishIds.intersection(situationSet).sorted()

            let allMatched = allergens + conditions + intolerances + diets + situations

            return AnalyzedDish(
                dish: dish,
                isSafe: allMatched.isEmpty,
                matchedAllergenIds: Array(allergens),
                matchedConditionIds: Array(conditions),
                matchedIntoleranceIds: Array(intolerances),
                matchedDietIds: Array(diets),
                matchedSituationIds: Array(situations)
            )
        }
    }

    static func safeCount(in analyzed: [AnalyzedDish]) -> Int {
        analyzed.filter(\.isSafe).count
    }

    static func unsafeCount(in analyzed: [AnalyzedDish]) -> Int {
        analyzed.filter { !$0.isSafe }.count
    }
}
