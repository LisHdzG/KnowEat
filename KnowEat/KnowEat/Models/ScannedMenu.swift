//
//  ScannedMenu.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

struct ScannedMenu: Identifiable, Codable {
    let id: UUID
    var restaurant: String
    let dishes: [Dish]
    let scannedAt: Date
    var categoryIcon: String
    let menuLanguage: String

    init(restaurant: String, dishes: [Dish], categoryIcon: String = "restaurant", menuLanguage: String = "Unknown") {
        self.id = UUID()
        self.restaurant = restaurant
        self.dishes = dishes
        self.scannedAt = .now
        self.categoryIcon = categoryIcon
        self.menuLanguage = menuLanguage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        restaurant = try container.decode(String.self, forKey: .restaurant)
        dishes = try container.decode([Dish].self, forKey: .dishes)
        scannedAt = try container.decode(Date.self, forKey: .scannedAt)
        categoryIcon = try container.decodeIfPresent(String.self, forKey: .categoryIcon) ?? "restaurant"
        menuLanguage = try container.decodeIfPresent(String.self, forKey: .menuLanguage) ?? "Unknown"
    }
}

struct Dish: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String?
    let price: String?
    let category: String?
    let ingredients: [String]
    let allergenIds: [String]

    init(name: String, description: String?, price: String?, category: String?, ingredients: [String], allergenIds: [String]) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.price = price
        self.category = category
        self.ingredients = ingredients
        self.allergenIds = allergenIds
    }
}

struct AnalyzedDish: Identifiable {
    let dish: Dish
    let isSafe: Bool
    let matchedAllergenIds: [String]

    var id: UUID { dish.id }
}
