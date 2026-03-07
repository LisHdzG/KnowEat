//
//  ScannedMenu.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

struct ScannedMenu: Identifiable, Codable, Sendable {
    let id: UUID
    var restaurant: String
    var dishes: [Dish]
    let scannedAt: Date
    var categoryIcon: String
    var menuLanguage: String
    var imageFileNames: [String]
    var textRegions: [TextRegion]

    init(
        restaurant: String,
        dishes: [Dish],
        categoryIcon: String = "restaurant",
        menuLanguage: String = "Unknown",
        imageFileNames: [String] = [],
        textRegions: [TextRegion] = []
    ) {
        self.id = UUID()
        self.restaurant = restaurant
        self.dishes = dishes
        self.scannedAt = .now
        self.categoryIcon = categoryIcon
        self.menuLanguage = menuLanguage
        self.imageFileNames = imageFileNames
        self.textRegions = textRegions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        restaurant = try container.decode(String.self, forKey: .restaurant)
        dishes = try container.decode([Dish].self, forKey: .dishes)
        scannedAt = try container.decode(Date.self, forKey: .scannedAt)
        categoryIcon = try container.decodeIfPresent(String.self, forKey: .categoryIcon) ?? "restaurant"
        menuLanguage = try container.decodeIfPresent(String.self, forKey: .menuLanguage) ?? "Unknown"
        imageFileNames = try container.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        textRegions = try container.decodeIfPresent([TextRegion].self, forKey: .textRegions) ?? []
    }
}

struct TextRegion: Codable, Sendable {
    let text: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let confidence: Float
    let imageIndex: Int
}

struct Dish: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let translatedName: String?
    let description: String?
    let price: String?
    let category: String?
    let ingredients: [String]
    let inferredIngredients: [String]
    let allergenIds: [String]
    let suggestedAllergenIds: [String]
    let textRegionIndices: [Int]

    init(
        name: String,
        translatedName: String? = nil,
        description: String?,
        price: String?,
        category: String?,
        ingredients: [String],
        allergenIds: [String],
        inferredIngredients: [String] = [],
        suggestedAllergenIds: [String] = [],
        textRegionIndices: [Int] = []
    ) {
        self.id = UUID()
        self.name = name
        self.translatedName = translatedName
        self.description = description
        self.price = price
        self.category = category
        self.ingredients = ingredients
        self.inferredIngredients = inferredIngredients
        self.allergenIds = allergenIds
        self.suggestedAllergenIds = suggestedAllergenIds
        self.textRegionIndices = textRegionIndices
    }

    init(from original: Dish, translatedName: String?, translatedDescription: String?, translatedIngredients: [String], translatedInferredIngredients: [String]) {
        self.id = original.id
        self.name = original.name
        self.translatedName = translatedName
        self.description = translatedDescription
        self.price = original.price
        self.category = original.category
        self.ingredients = translatedIngredients
        self.inferredIngredients = translatedInferredIngredients
        self.allergenIds = original.allergenIds
        self.suggestedAllergenIds = original.suggestedAllergenIds
        self.textRegionIndices = original.textRegionIndices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        translatedName = try container.decodeIfPresent(String.self, forKey: .translatedName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        price = try container.decodeIfPresent(String.self, forKey: .price)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        ingredients = try container.decode([String].self, forKey: .ingredients)
        inferredIngredients = try container.decodeIfPresent([String].self, forKey: .inferredIngredients) ?? []
        allergenIds = try container.decode([String].self, forKey: .allergenIds)
        suggestedAllergenIds = try container.decodeIfPresent([String].self, forKey: .suggestedAllergenIds) ?? []
        textRegionIndices = try container.decodeIfPresent([Int].self, forKey: .textRegionIndices) ?? []
    }
}

struct AnalyzedDish: Identifiable, Sendable {
    let dish: Dish
    let isSafe: Bool
    let matchedAllergenIds: [String]
    let matchedConditionIds: [String]
    let matchedIntoleranceIds: [String]
    let matchedDietIds: [String]
    let matchedSituationIds: [String]
    let suggestedMatchedIds: [String]

    var id: UUID { dish.id }

    var dangerIds: [String] { matchedAllergenIds + matchedConditionIds }
    var advisoryIds: [String] { matchedIntoleranceIds + matchedDietIds + matchedSituationIds }
    var isDanger: Bool { !dangerIds.isEmpty }
    var isAdvisory: Bool { !advisoryIds.isEmpty && !isDanger }
    var hasSuggested: Bool { !suggestedMatchedIds.isEmpty }
}
