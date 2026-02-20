//
//  OpenAIService.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation
import UIKit
import FirebaseFunctions

enum OpenAIError: LocalizedError {
    case encodingFailed
    case invalidResponse
    case unreadableMenu
    case timeout
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode the menu images."
        case .invalidResponse:
            return "Could not understand the API response."
        case .unreadableMenu:
            return "The scanned menu could not be analyzed. Please try with a clearer photo and make sure the menu text is fully visible."
        case .timeout:
            return "The request took too long. Please try again."
        case .serverError(let message):
            return message
        }
    }

    var isRetryable: Bool {
        switch self {
        case .timeout, .serverError: return true
        default: return false
        }
    }
}

@MainActor
final class OpenAIService {
    static let shared = OpenAIService()

    private lazy var functions = Functions.functions()

    private static let categoryIcons = [
        "beer", "dinner", "fried-rice", "lasagna", "lunch-bag", "nachos",
        "pancake", "pasta", "pastry", "pizza-slice", "ramen", "restaurant",
        "rice", "salad", "sausage", "shrimp", "taco"
    ]

    func analyzeMenu(images: [UIImage], userLanguage: String) async throws -> ScannedMenu {
        let base64Images = try images.compactMap { image -> String in
            guard let data = image.jpegData(compressionQuality: 0.7) else {
                throw OpenAIError.encodingFailed
            }
            return data.base64EncodedString()
        }

        let result: HTTPSCallableResult
        do {
            result = try await functions.httpsCallable("analyzeMenu").call([
                "base64Images": base64Images,
                "userLanguage": userLanguage
            ])
        } catch {
            let nsError = error as NSError
            if nsError.domain == FunctionsErrorDomain {
                let message = nsError.localizedDescription
                if message.contains("DEADLINE_EXCEEDED") || message.contains("timeout") {
                    throw OpenAIError.timeout
                }
                throw OpenAIError.serverError(message)
            }
            throw OpenAIError.serverError(error.localizedDescription)
        }

        guard let dict = result.data as? [String: Any] else {
            throw OpenAIError.invalidResponse
        }

        return try parseMenuResponse(dict: dict, userLanguage: userLanguage)
    }

    func retranslateMenu(dishes: [Dish], to language: String) async throws -> [Dish] {
        let dishArray = dishes.map { dish -> [String: Any] in
            var d: [String: Any] = [
                "name": dish.name,
                "price": dish.price ?? "",
                "category": dish.category ?? "",
                "ingredients": dish.ingredients,
                "allergenIds": dish.allergenIds
            ]
            if let desc = dish.description { d["description"] = desc }
            return d
        }

        let jsonData = try JSONSerialization.data(withJSONObject: dishArray)
        let dishJSON = String(data: jsonData, encoding: .utf8) ?? "[]"

        let result: HTTPSCallableResult
        do {
            result = try await functions.httpsCallable("retranslateMenu").call([
                "dishesJSON": dishJSON,
                "targetLanguage": language
            ])
        } catch {
            let nsError = error as NSError
            throw OpenAIError.serverError(nsError.localizedDescription)
        }

        guard let dishDicts = result.data as? [[String: Any]] else {
            throw OpenAIError.invalidResponse
        }

        let jsonResult = try JSONSerialization.data(withJSONObject: dishDicts)
        let rawDishes = try JSONDecoder().decode([DishResponse].self, from: jsonResult)

        return rawDishes.map { raw in
            Dish(
                name: raw.name,
                description: raw.description,
                price: raw.price,
                category: raw.category,
                ingredients: raw.ingredients,
                allergenIds: raw.allergenIds
            )
        }
    }

    private func parseMenuResponse(dict: [String: Any], userLanguage: String) throws -> ScannedMenu {
        guard let restaurant = dict["restaurant"] as? String,
              let dishDicts = dict["dishes"] as? [[String: Any]] else {
            throw OpenAIError.unreadableMenu
        }

        guard !dishDicts.isEmpty else {
            throw OpenAIError.unreadableMenu
        }

        let jsonData = try JSONSerialization.data(withJSONObject: dishDicts)
        let rawDishes = try JSONDecoder().decode([DishResponse].self, from: jsonData)

        let dishes = rawDishes.map { raw in
            Dish(
                name: raw.name,
                description: raw.description,
                price: raw.price,
                category: raw.category,
                ingredients: raw.ingredients,
                allergenIds: raw.allergenIds
            )
        }

        let categoryIcon = dict["categoryIcon"] as? String ?? "restaurant"
        let icon = Self.categoryIcons.contains(categoryIcon) ? categoryIcon : "restaurant"

        return ScannedMenu(restaurant: restaurant, dishes: dishes, categoryIcon: icon, menuLanguage: userLanguage)
    }
}

private struct DishResponse: Decodable {
    let name: String
    let description: String?
    let price: String?
    let category: String?
    let ingredients: [String]
    let allergenIds: [String]
}
