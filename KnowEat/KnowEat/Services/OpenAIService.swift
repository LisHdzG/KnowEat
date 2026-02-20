//
//  OpenAIService.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation
import UIKit

enum OpenAIError: LocalizedError {
    case invalidAPIKey
    case encodingFailed
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please set your OpenAI key in APIConfig."
        case .encodingFailed:
            return "Failed to encode the menu images."
        case .invalidResponse:
            return "Could not understand the API response."
        case .serverError(let message):
            return message
        }
    }
}

@MainActor
final class OpenAIService {
    static let shared = OpenAIService()

    private let allergenIDs = [
        "gluten", "crustaceans", "eggs", "fish", "peanuts",
        "soy", "dairy", "tree_nuts", "celery", "mustard",
        "sesame", "sulfites", "lupins", "mollusks"
    ]

    func analyzeMenu(images: [UIImage], userLanguage: String) async throws -> ScannedMenu {
        guard !APIConfig.openAIKey.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        let base64Images = try images.compactMap { image -> String in
            guard let data = image.jpegData(compressionQuality: 0.7) else {
                throw OpenAIError.encodingFailed
            }
            return data.base64EncodedString()
        }

        let systemPrompt = buildSystemPrompt(userLanguage: userLanguage)
        let request = try buildRequest(base64Images: base64Images, systemPrompt: systemPrompt)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.serverError("API error (\(httpResponse.statusCode)): \(body)")
        }

        return try parseResponse(data: data)
    }

    func retranslateMenu(dishes: [Dish], to language: String) async throws -> [Dish] {
        guard !APIConfig.openAIKey.isEmpty else { throw OpenAIError.invalidAPIKey }

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

        let systemPrompt = """
        You are a translation assistant. Translate menu dishes to \(language).
        For each dish:
        - "name": translate the dish name to \(language)
        - "description": keep EXACTLY as is (original name from menu)
        - "price": keep EXACTLY as is
        - "category": translate to \(language) with original in parentheses
        - "ingredients": translate all to \(language)
        - "allergenIds": keep EXACTLY as is
        Return ONLY a valid JSON array. No markdown, no code fences, no extra text.
        """

        let body: [String: Any] = [
            "model": APIConfig.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": dishJSON]
            ],
            "max_tokens": 4096,
            "temperature": 0.1
        ]

        let jsonBody = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: APIConfig.openAIBaseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonBody
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.serverError("API error: \(errBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let contentData = cleaned.data(using: .utf8) else { throw OpenAIError.invalidResponse }

        let rawDishes = try JSONDecoder().decode([DishResponse].self, from: contentData)

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

    private static let categoryIcons = [
        "beer", "dinner", "fried-rice", "lasagna", "lunch-bag", "nachos",
        "pancake", "pasta", "pastry", "pizza-slice", "ramen", "restaurant",
        "rice", "salad", "sausage", "shrimp", "taco"
    ]

    private func buildSystemPrompt(userLanguage: String) -> String {
        let ids = allergenIDs.joined(separator: ", ")
        let icons = Self.categoryIcons.joined(separator: ", ")
        return """
        You are a menu analysis assistant. Analyze the restaurant menu image(s) and return ONLY valid JSON with this exact structure:
        {
          "restaurant": "Name of the restaurant if visible, otherwise 'Unknown'",
          "categoryIcon": "best matching icon for this restaurant type",
          "menuLanguage": "detected language of the menu",
          "dishes": [
            {
              "name": "Dish name translated to \(userLanguage)",
              "description": "Original dish name as written on the menu",
              "price": "Price if visible",
              "category": "Menu section translated to \(userLanguage) with original in parentheses",
              "ingredients": ["ingredient1", "ingredient2"],
              "allergenIds": ["id1", "id2"]
            }
          ]
        }

        Rules:
        - LANGUAGE: All dish names, categories, and ingredients MUST be translated to \(userLanguage). Keep the original name in the description field.
        - For ingredients: list the most likely ingredients even if not explicitly stated on the menu. Use your culinary knowledge. Translate them to \(userLanguage).
        - For allergenIds: use ONLY these IDs: \(ids)
        - For categoryIcon: pick the SINGLE best matching icon from this list based on the restaurant's cuisine type: \(icons). If none fits well, use "restaurant".
        - For menuLanguage: detect the original language of the menu text and return its name in English (e.g. "Italian", "Japanese", "Spanish").
        - For category: translate the menu section heading to \(userLanguage) and include the original in parentheses (e.g. "Land Appetizers (Antipasti di Terra)").
        - For description: always put the original dish name as written on the menu (in its original language).
        - Include ALL dishes visible in the menu image(s).
        - Return ONLY the JSON, no markdown formatting, no code fences, no extra text.
        """
    }

    private func buildRequest(base64Images: [String], systemPrompt: String) throws -> URLRequest {
        var imageContents: [[String: Any]] = []
        for base64 in base64Images {
            imageContents.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64)",
                    "detail": "high"
                ]
            ])
        }

        let userContent: [[String: Any]] = [
            ["type": "text", "text": "Analyze this restaurant menu and return the structured JSON."]
        ] + imageContents

        let body: [String: Any] = [
            "model": APIConfig.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "max_tokens": 4096,
            "temperature": 0.1
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: APIConfig.openAIBaseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60

        return request
    }

    private func parseResponse(data: Data) throws -> ScannedMenu {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let contentData = cleaned.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        let menuResponse = try JSONDecoder().decode(MenuAPIResponse.self, from: contentData)

        let dishes = menuResponse.dishes.map { raw in
            Dish(
                name: raw.name,
                description: raw.description,
                price: raw.price,
                category: raw.category,
                ingredients: raw.ingredients,
                allergenIds: raw.allergenIds
            )
        }

        let icon = Self.categoryIcons.contains(menuResponse.categoryIcon ?? "")
            ? menuResponse.categoryIcon! : "restaurant"

        let language = menuResponse.menuLanguage ?? "Unknown"

        return ScannedMenu(restaurant: menuResponse.restaurant, dishes: dishes, categoryIcon: icon, menuLanguage: language)
    }
}

private struct MenuAPIResponse: Decodable {
    let restaurant: String
    let categoryIcon: String?
    let menuLanguage: String?
    let dishes: [DishResponse]
}

private struct DishResponse: Decodable {
    let name: String
    let description: String?
    let price: String?
    let category: String?
    let ingredients: [String]
    let allergenIds: [String]
}
