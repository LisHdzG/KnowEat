//
//  FoundationModelAnalyzer.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation
import FoundationModels

// MARK: - Generable Structs (structured output from on-device LLM)

@Generable
struct GeneratedMenu {
    @Guide(description: "Name of the restaurant if visible in the menu, otherwise 'Unknown'")
    var restaurant: String

    @Guide(description: "A category icon for this restaurant type. Must be one of: beer, dinner, fried-rice, lasagna, lunch-bag, nachos, pancake, pasta, pastry, pizza-slice, ramen, restaurant, rice, salad, sausage, shrimp, taco")
    var categoryIcon: String

    @Guide(description: "All dishes found in the menu text")
    var dishes: [GeneratedDish]
}

@Generable
struct GeneratedDish {
    @Guide(description: "The EXACT original name of the dish as written on the menu. Keep the original language. For example: 'Arepa de Carne Mechada', 'Tequeños', 'Empanada de Jamón y Queso'. NEVER replace the name with a description or translation.")
    var name: String

    @Guide(description: "A brief translated description or explanation of the dish in the user's language. If the menu already provides a description or ingredient list for this dish, translate that. If not, briefly describe what the dish typically is.")
    var dishDescription: String

    @Guide(description: "Price as shown on the menu, including currency symbol. For example: '$120', '€15.50'")
    var price: String

    @Guide(description: "Category: Appetizer, Main Course, Dessert, Drink, Salad, Soup, Side, Pizza, Pasta, Sandwich, or Other")
    var category: String

    @Guide(description: "Ingredients EXPLICITLY listed or described on the menu for this dish. Only include what the menu actually says. If the menu says nothing about ingredients, leave this empty.")
    var ingredients: [String]

    @Guide(description: "Ingredients NOT written on the menu but commonly known to be in this type of dish. For example, if the menu just says 'Tequeños' with no ingredients listed, infer: white cheese, wheat flour dough, oil. If the menu already lists all ingredients, leave this empty.")
    var inferredIngredients: [String]

    @Guide(description: "Allergen IDs for this dish based on ALL ingredients (both explicit and inferred). Use ONLY these exact IDs: gluten, dairy, eggs, fish, crustaceans, peanuts, soy, tree_nuts, celery, mustard, sesame, sulfites, lupins, mollusks, lactose, fructose, histamine, fodmap. CRITICAL RULES: Any dish with cheese, milk, cream, or butter MUST include both 'dairy' and 'lactose'. Any dish with mayonnaise or aioli MUST include 'eggs'. Any dish with bread, flour, pasta, or dough (except corn dough) MUST include 'gluten'. Beer ONLY contains 'gluten', nothing else. Do NOT invent allergens that are not related to the ingredients.")
    var allergenIds: [String]
}

// MARK: - Analyzer Service

enum FoundationModelError: LocalizedError {
    case modelNotAvailable
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "On-device AI model is not available on this device."
        case .generationFailed(let message):
            return "AI analysis failed: \(message)"
        }
    }
}

final class FoundationModelAnalyzer {
    static let shared = FoundationModelAnalyzer()

    private static let validIcons: Set<String> = [
        "beer", "dinner", "fried-rice", "lasagna", "lunch-bag", "nachos",
        "pancake", "pasta", "pastry", "pizza-slice", "ramen", "restaurant",
        "rice", "salad", "sausage", "shrimp", "taco"
    ]

    private static let validAllergenIds: Set<String> = [
        "gluten", "dairy", "eggs", "fish", "crustaceans", "peanuts",
        "soy", "tree_nuts", "celery", "mustard", "sesame", "sulfites",
        "lupins", "mollusks", "lactose", "fructose", "histamine", "fodmap"
    ]

    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    func analyze(ocrText: String, userLanguage: String) async throws -> ScannedMenu {
        guard isAvailable else {
            throw FoundationModelError.modelNotAvailable
        }

        let session = LanguageModelSession(
            instructions: """
            You are an expert food analyst and allergen specialist. \
            Your job is to analyze restaurant menu text and extract structured information. \
            \
            CRITICAL RULES: \
            1. The dish name MUST be the EXACT original name from the menu in its original language. \
            NEVER replace the name with a translation or description. \
            For example, if the menu says "Tequeños", the name must be "Tequeños", NOT "Fried cheese sticks". \
            If the menu says "Arepa Reina Pepiada", the name must be "Arepa Reina Pepiada". \
            2. Extract EVERY SINGLE dish as a SEPARATE entry. If a menu section like "Arepas" lists \
            "Carne Mechada", "Pollo Mechado", "Llanera", those are 3 separate dishes: \
            "Arepa de Carne Mechada", "Arepa de Pollo Mechado", "Arepa Llanera". \
            Do NOT group them into one entry. \
            3. If the menu provides ingredients or a description for a dish, use those exact ingredients. \
            If the menu does NOT provide ingredients, infer the typical common ingredients based on culinary knowledge. \
            4. Translate dish descriptions to \(userLanguage) but KEEP the original dish name unchanged. \
            5. Include drinks and beverages as separate entries too.
            """
        )

        let prompt = """
        Analyze this restaurant menu text extracted via OCR. \
        List EVERY individual dish separately — do NOT group or summarize multiple dishes into one entry. \
        Each variation or flavor must be its own entry.

        MENU TEXT:
        \(ocrText)
        """

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedMenu.self)
            return convertToScannedMenu(response.content, userLanguage: userLanguage)
        } catch {
            throw FoundationModelError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Translation

    @Generable
    struct TranslatedDish {
        @Guide(description: "The dish description translated to the target language")
        var translatedDescription: String
    }

    func translateMenu(dishes: [Dish], restaurant: String, to language: String) async throws -> (restaurant: String, dishes: [Dish]) {
        guard isAvailable else {
            throw FoundationModelError.modelNotAvailable
        }

        let session = LanguageModelSession(
            instructions: """
            You are a professional translator specializing in food and restaurant menus. \
            Translate dish descriptions to \(language). \
            Keep dish names in their original language — only translate the descriptions.
            """
        )

        var translatedDishes: [Dish] = []

        for dish in dishes {
            let descriptionToTranslate = dish.description ?? dish.name
            do {
                let response = try await session.respond(
                    to: "Translate this dish description to \(language): \"\(descriptionToTranslate)\"",
                    generating: TranslatedDish.self
                )
                translatedDishes.append(Dish(
                    name: dish.name,
                    description: response.content.translatedDescription,
                    price: dish.price,
                    category: dish.category,
                    ingredients: dish.ingredients,
                    allergenIds: dish.allergenIds,
                    inferredIngredients: dish.inferredIngredients
                ))
            } catch {
                translatedDishes.append(dish)
            }
        }

        return (restaurant: restaurant, dishes: translatedDishes)
    }

    private func convertToScannedMenu(_ generated: GeneratedMenu, userLanguage: String) -> ScannedMenu {
        let icon = Self.validIcons.contains(generated.categoryIcon) ? generated.categoryIcon : "restaurant"

        let dishes = generated.dishes.map { gd in
            let llmAllergens = Set(gd.allergenIds.filter { Self.validAllergenIds.contains($0) })

            let allIngredientText = (gd.ingredients + gd.inferredIngredients)
                .joined(separator: " ")
                .lowercased()
            let localAllergens = Self.detectAllergensLocally(in: allIngredientText)

            let mergedAllergens = Array(llmAllergens.union(localAllergens)).sorted()

            return Dish(
                name: gd.name,
                description: gd.dishDescription.isEmpty ? nil : gd.dishDescription,
                price: gd.price.isEmpty ? nil : gd.price,
                category: gd.category.isEmpty ? nil : gd.category,
                ingredients: gd.ingredients,
                allergenIds: mergedAllergens,
                inferredIngredients: gd.inferredIngredients
            )
        }

        return ScannedMenu(
            restaurant: generated.restaurant,
            dishes: dishes,
            categoryIcon: icon,
            menuLanguage: userLanguage
        )
    }

    // MARK: - Local Allergen Verification (second layer)

    private static func detectAllergensLocally(in text: String) -> Set<String> {
        var found: Set<String> = []
        for (allergenId, keywords) in ingredientAllergenMap {
            if keywords.contains(where: { text.contains($0) }) {
                found.insert(allergenId)
            }
        }
        return found
    }

    private static let ingredientAllergenMap: [String: [String]] = [
        "gluten": ["wheat", "flour", "bread", "pasta", "barley", "rye", "oat", "semolina", "couscous", "noodle", "dough", "pastry", "cracker", "trigo", "harina", "avena", "cebada", "centeno", "farina", "orzo", "segale", "beer", "cerveza", "birra"],
        "dairy": ["milk", "cheese", "cream", "butter", "yogurt", "mozzarella", "parmesan", "cheddar", "ricotta", "mascarpone", "brie", "feta", "whey", "ghee", "paneer", "leche", "queso", "crema", "mantequilla", "yogur", "nata", "latte", "formaggio", "burro", "panna"],
        "eggs": ["egg", "mayonnaise", "meringue", "aioli", "huevo", "mayonesa", "uovo", "uova", "maionese"],
        "fish": ["fish", "salmon", "tuna", "cod", "anchovy", "sardine", "bass", "trout", "halibut", "swordfish", "mackerel", "pescado", "atún", "bacalao", "anchoa", "sardina", "trucha", "pesce", "tonno", "merluzzo", "acciuga"],
        "crustaceans": ["shrimp", "prawn", "crab", "lobster", "crawfish", "langoustine", "gamba", "cangrejo", "langosta", "gambero", "granchio", "aragosta", "gambas"],
        "peanuts": ["peanut", "cacahuete", "arachide"],
        "soy": ["soy", "soja", "tofu", "edamame", "tempeh", "miso"],
        "tree_nuts": ["almond", "walnut", "cashew", "pistachio", "pecan", "hazelnut", "macadamia", "chestnut", "pine nut", "almendra", "nuez", "avellana", "pistacho", "mandorla", "noce", "nocciola", "pistacchio"],
        "celery": ["celery", "celeriac", "apio", "sedano"],
        "mustard": ["mustard", "mostaza", "senape"],
        "sesame": ["sesame", "tahini", "sesamo"],
        "sulfites": ["wine", "vinegar", "sulfite", "vino", "vinagre", "aceto"],
        "lupins": ["lupin", "lupini", "altramuz"],
        "mollusks": ["mussel", "clam", "oyster", "squid", "octopus", "scallop", "calamari", "snail", "almeja", "ostra", "calamar", "pulpo", "cozza", "vongola", "ostrica", "polpo"],
        "lactose": ["milk", "cheese", "cream", "butter", "yogurt", "ice cream", "leche", "queso", "crema", "mantequilla", "yogur", "helado", "latte", "formaggio", "burro", "gelato"],
        "fructose": ["honey", "apple", "pear", "mango", "agave", "miel", "manzana", "pera", "miele", "mela"],
        "histamine": ["wine", "aged cheese", "fermented", "cured", "smoked", "vinegar", "vino", "ahumado", "curado", "fermentado", "affumicato", "stagionato"],
        "fodmap": ["garlic", "onion", "wheat", "apple", "pear", "ajo", "cebolla", "trigo", "manzana", "aglio", "cipolla"]
    ]
}
