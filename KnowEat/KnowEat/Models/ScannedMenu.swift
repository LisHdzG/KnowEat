//
//  ScannedMenu.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

struct ScannedMenu: Identifiable, Codable {
    let id: UUID
    let restaurant: String
    let dishes: [Dish]
    let scannedAt: Date

    init(restaurant: String, dishes: [Dish]) {
        self.id = UUID()
        self.restaurant = restaurant
        self.dishes = dishes
        self.scannedAt = .now
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
