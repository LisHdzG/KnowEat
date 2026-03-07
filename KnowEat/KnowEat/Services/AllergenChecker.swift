//
//  AllergenChecker.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

enum AllergenChecker {

    // MARK: - Diet → conflicting content IDs

    private static let dietConflicts: [String: Set<String>] = [
        "vegan": ["dairy", "eggs", "fish", "crustaceans", "mollusks", "meat", "poultry", "pork", "lactose"],
        "vegetarian": ["fish", "crustaceans", "mollusks", "meat", "poultry", "pork"],
        "pescatarian": ["meat", "poultry", "pork"],
        "halal": ["pork", "alcohol"],
        "kosher": ["pork", "crustaceans", "mollusks"],
    ]

    private static let conditionConflicts: [String: Set<String>] = [
        "celiac": ["gluten"],
        "diabetes": ["fructose"],
        "hypertension": ["fodmap"],
        "kidney_disease": [],
        "gout": [],
        "favism": ["lupins"],
    ]

    private static let situationConflicts: [String: Set<String>] = [
        "pregnant": ["alcohol"],
        "breastfeeding": ["alcohol"],
    ]

    // MARK: - Analysis

    static func analyze(menu: ScannedMenu, userAllergenIds: [String]) -> [AnalyzedDish] {
        let userSet = Set(userAllergenIds)
        return menu.dishes.map { dish in
            let matched = dish.allergenIds.filter { userSet.contains($0) }
            let suggested = dish.suggestedAllergenIds.filter { userSet.contains($0) && !matched.contains($0) }
            return AnalyzedDish(
                dish: dish,
                isSafe: matched.isEmpty && suggested.isEmpty,
                matchedAllergenIds: matched,
                matchedConditionIds: [],
                matchedIntoleranceIds: [],
                matchedDietIds: [],
                matchedSituationIds: [],
                suggestedMatchedIds: suggested
            )
        }
    }

    static func analyze(menu: ScannedMenu, profile: UserProfile) -> [AnalyzedDish] {
        let allergenSet = Set(profile.allergenIds)
        let intoleranceSet = Set(profile.intoleranceIds)

        let expandedConditionIds = profile.conditionIds
            .flatMap { conditionConflicts[$0] ?? [] }
        let expandedDietIds = profile.dietIds
            .flatMap { dietConflicts[$0] ?? [] }
        let expandedSituationIds = profile.situationIds
            .flatMap { situationConflicts[$0] ?? [] }

        let conditionConflictSet = Set(expandedConditionIds)
        let dietConflictSet = Set(expandedDietIds)
        let situationConflictSet = Set(expandedSituationIds)

        let allConflicting = allergenSet
            .union(intoleranceSet)
            .union(conditionConflictSet)
            .union(dietConflictSet)
            .union(situationConflictSet)

        return menu.dishes.map { dish in
            let dishIds = Set(dish.allergenIds)

            let allergens = Array(dishIds.intersection(allergenSet)).sorted()
            let intolerances = Array(dishIds.intersection(intoleranceSet)).sorted()

            let conditionMatches = Array(dishIds.intersection(conditionConflictSet)).sorted()
            let dietMatches = Array(dishIds.intersection(dietConflictSet)).sorted()
            let situationMatches = Array(dishIds.intersection(situationConflictSet)).sorted()

            let confirmedMatches = Set(allergens + intolerances + conditionMatches + dietMatches + situationMatches)

            let suggestedIds = Set(dish.suggestedAllergenIds)
            let suggestedMatched = Array(suggestedIds.intersection(allConflicting).subtracting(confirmedMatches)).sorted()

            let allMatched = !confirmedMatches.isEmpty

            return AnalyzedDish(
                dish: dish,
                isSafe: !allMatched && suggestedMatched.isEmpty,
                matchedAllergenIds: allergens,
                matchedConditionIds: conditionMatches,
                matchedIntoleranceIds: intolerances,
                matchedDietIds: dietMatches,
                matchedSituationIds: situationMatches,
                suggestedMatchedIds: suggestedMatched
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
