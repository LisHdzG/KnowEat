//
//  FoundationModelAnalyzer.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation
import FoundationModels

// MARK: - Generable Structs

@Generable
struct GeneratedMenu {
    @Guide(description: "Restaurant name from branding/logo text. Use 'Unknown' if not visible.")
    var restaurant: String

    @Guide(description: "Icon: beer, dinner, fried-rice, lasagna, lunch-bag, nachos, pancake, pasta, pastry, pizza-slice, ramen, restaurant, rice, salad, sausage, shrimp, taco")
    var categoryIcon: String

    @Guide(description: "Every individual dish and drink extracted from the menu")
    var dishes: [GeneratedDish]
}

@Generable
struct GeneratedDish {
    @Guide(description: "Short dish name in original language (max 8 words). Must be a real, recognizable food or drink item. Never a description, address, phone, or decoration. Single-word names are OK only for well-known dishes (e.g. Lasagna, Carbonara, Tiramisù, Arancino).")
    var name: String

    @Guide(description: "Brief description translated to the user's language explaining what the dish is and its main components.")
    var dishDescription: String

    @Guide(description: "Price with currency symbol as shown on the menu. Empty if not visible.")
    var price: String

    @Guide(description: "Culinary category assigned by AI based on the type of dish. Use standardized categories: Appetizers, Soups, Salads, Pasta, Pizza, Rice, Meat, Fish & Seafood, Vegetarian, Sandwiches, Burgers, Fried, Desserts, Drinks, Sides. Pick the best match. Use 'Other' only if nothing fits.")
    var category: String

    @Guide(description: "Ingredients EXPLICITLY written on the menu for this dish. Only what the menu text says. Empty array if none listed.")
    var ingredients: [String]

    @Guide(description: "Ingredients NOT on the menu but commonly present in this dish based on culinary knowledge. ALWAYS infer likely ingredients even if some are listed. For example, if menu says 'Carbonara: guanciale, pecorino' you should still infer 'pasta, eggs, black pepper'. If you truly cannot recognize the dish at all, put 'Unrecognized dish' as the only item.")
    var inferredIngredients: [String]

    @Guide(description: "Allergen IDs from ALL ingredients (explicit + inferred). Only use: gluten, dairy, eggs, fish, crustaceans, peanuts, soy, tree_nuts, celery, mustard, sesame, sulfites, lupins, mollusks, lactose, fructose, histamine, fodmap")
    var allergenIds: [String]
}

// MARK: - Errors

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

// MARK: - Analyzer

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

    // MARK: - Analysis

    func analyze(ocrText: String, userLanguage: String) async throws -> ScannedMenu {
        guard isAvailable else {
            throw FoundationModelError.modelNotAvailable
        }

        let session = LanguageModelSession(
            instructions: """
            You are an expert restaurant menu reader. You receive text extracted from a menu photo via OCR. \
            The text may have OCR errors — use your food knowledge to fix them. \
            \
            Your job: \
            1. Find the restaurant name if visible (logo, header, branding). If not clear, say "Unknown". \
            2. Classify each dish into a standardized culinary category based on what the dish IS, \
            NOT based on what the menu's section headers say. Use these categories: \
            Appetizers, Soups, Salads, Pasta, Pizza, Rice, Meat, Fish & Seafood, Vegetarian, \
            Sandwiches, Burgers, Fried, Desserts, Drinks, Sides. Use "Other" only if nothing fits. \
            For example: "Spaghetti alla Carbonara" → "Pasta", "Pizza Margherita" → "Pizza", \
            "Arancino" → "Fried", "Tiramisù" → "Desserts", "Birra Peroni" → "Drinks". \
            3. Extract EVERY individual dish and drink that is a REAL, recognizable food or beverage item. \
            \
            QUALITY RULES (critical): \
            - ONLY include entries that are clearly a dish or drink. A valid entry must be a recognizable \
            food item that a diner could order. \
            - NEVER include: addresses, phone numbers, social media handles, slogans, decorative text, \
            page numbers, photographer credits, "Google Maps", "TouchPrint", dates, watermarks, \
            website URLs, QR labels, copyright notices, "Menu" alone, allergen disclaimers, \
            "Coperto", "Cover charge", or service notes. \
            - If an OCR line is garbled, unreadable, or you cannot determine it is a real dish, SKIP it. \
            Do not guess random food names from garbage text. \
            - Single-word entries are ONLY valid if they are well-known dish names \
            (e.g. Lasagna, Carbonara, Tiramisù, Arancino, Bruschetta, Polenta, Risotto). \
            Reject vague single words like "Special", "Classic", "Grande", "Piccola". \
            - Two-word entries must clearly be a dish (e.g. "Pizza Margherita", "Insalata Verde"). \
            Reject fragments like "Con Aggiunta", "E Provola", "Al Forno" alone. \
            \
            INGREDIENT RULES: \
            - If a dish has ingredients listed on the menu, include them ALL as explicit ingredients. \
            - ALWAYS use your culinary knowledge to infer ADDITIONAL ingredients the dish likely contains \
            that are NOT written on the menu. Put those in inferredIngredients. \
            For example: "Carbonara" with listed "guanciale, pecorino" → inferredIngredients: [pasta, eggs, black pepper]. \
            For example: "Margherita" with no ingredients listed → inferredIngredients: [pizza dough, tomato sauce, mozzarella, basil, olive oil]. \
            - If you recognize the dish but no ingredients are listed, infer ALL its typical ingredients. \
            - If you truly cannot recognize a dish at all, set inferredIngredients to ["Unrecognized dish"]. \
            \
            NAMING RULES: \
            - If a section lists multiple items (e.g. under "Empanadas": Carne Mechada, Pollo, Queso), \
            each item is its OWN dish. Use a natural name: "Empanada de Carne Mechada". \
            - Keep dish names SHORT (max 8 words) in the ORIGINAL menu language. \
            - Translate ONLY the dishDescription to \(userLanguage). Use proper culinary translations. \
            - The dishDescription should briefly explain what the dish is (e.g. "Pasta with eggs, cured pork cheek and pecorino cheese").
            """
        )

        let cleanedText = Self.preprocessOCRText(ocrText)

        let prompt = """
        Read this menu and extract every dish and drink. \
        Find the categories, then list each item under its category. \
        For each dish, list its explicit ingredients and infer any missing common ones.

        MENU TEXT:
        \(cleanedText)
        """

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedMenu.self)
            return buildScannedMenu(from: response.content, userLanguage: userLanguage)
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
            You are a professional food translator. \
            Translate dish descriptions accurately to \(language). \
            Use correct culinary terms — not literal translations. \
            Keep dish names in their original language.
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

    // MARK: - Build ScannedMenu (post-processing)

    private func buildScannedMenu(from generated: GeneratedMenu, userLanguage: String) -> ScannedMenu {
        let icon = Self.validIcons.contains(generated.categoryIcon) ? generated.categoryIcon : "restaurant"

        let dishes = generated.dishes.compactMap { gd -> Dish? in
            let trimmedName = gd.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            guard !Self.isJunkEntry(trimmedName) else { return nil }

            let finalName = trimmedName.count > 60
                ? String(trimmedName.split(separator: " ").prefix(8).joined(separator: " "))
                : trimmedName

            let llmAllergens = Set(gd.allergenIds.filter { Self.validAllergenIds.contains($0) })

            let allText = (gd.ingredients + gd.inferredIngredients + [finalName, gd.dishDescription])
                .joined(separator: " ")
                .lowercased()
            let localAllergens = Self.detectAllergensLocally(in: allText)

            let mergedAllergens = Array(llmAllergens.union(localAllergens)).sorted()

            return Dish(
                name: finalName,
                description: gd.dishDescription.isEmpty ? nil : gd.dishDescription,
                price: gd.price.isEmpty ? nil : gd.price,
                category: gd.category.isEmpty ? nil : gd.category,
                ingredients: gd.ingredients,
                allergenIds: mergedAllergens,
                inferredIngredients: gd.inferredIngredients
            )
        }

        let restaurant = Self.sanitizeRestaurantName(generated.restaurant)

        return ScannedMenu(
            restaurant: restaurant,
            dishes: dishes,
            categoryIcon: icon,
            menuLanguage: userLanguage
        )
    }

    // MARK: - Junk Filtering

    private static func isJunkEntry(_ name: String) -> Bool {
        let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lower.count < 2 { return true }

        let junkExact: Set<String> = [
            "menù", "menu", "carta", "the menu", "la carta", "conto", "receipt",
            "prezzario", "prezzi", "listino", "price list",
            "speciale", "special", "classiche", "classico", "particolare",
            "grande", "piccola", "media", "small", "medium", "large",
            "con aggiunta", "aggiunta", "variazione",
            "google maps", "touchprint", "foto", "image",
            "sala interna", "sala esterna", "asporto", "takeaway",
            "allergeni", "allergens", "contiene glutine",
            "n.b.", "nota bene", "note"
        ]
        if junkExact.contains(lower) { return true }

        let junkContains = [
            "servizio", "coperto", "cover charge", "service charge",
            "www.", ".com", ".it", ".es", ".org", "http",
            "facebook", "instagram", "tiktok", "tripadvisor", "twitter",
            "follow us", "síguenos", "seguici",
            "iva inclusa", "iva incluida", "tax included",
            "tel:", "tel.", "horario", "orario",
            "google maps", "touchprint",
            "tutti i gusti", "prezzi vari",
            "la nostra pasta contiene", "allergeni sono indicati",
            "protegidas por derechos", "fecha de la imagen",
            "zte blade", "copyright"
        ]
        if junkContains.contains(where: { lower.contains($0) }) { return true }

        let nonSpace = name.filter { !$0.isWhitespace }
        let nonAlpha = nonSpace.filter { !$0.isLetter }
        if !nonSpace.isEmpty && nonAlpha.count == nonSpace.count { return true }

        let words = name.split(separator: " ")
        if words.count == 1 && lower.count < 4 { return true }

        let digits = name.filter { $0.isNumber }
        if digits.count > 5 { return true }

        if lower.hasPrefix("+") || lower.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" || $0 == "+" }) {
            return true
        }

        return false
    }

    private static func sanitizeRestaurantName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "unknown" { return "Unknown" }
        if !trimmed.contains(where: { $0.isLetter }) { return "Unknown" }
        let junk = ["menù", "menu", "la carta", "the menu", "restaurant", "ristorante", "restaurante"]
        if junk.contains(trimmed.lowercased()) { return "Unknown" }
        if trimmed.count > 40 { return String(trimmed.prefix(40)) }
        return trimmed
    }

    // MARK: - OCR Pre-processing

    private static func preprocessOCRText(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        lines = lines.filter { line in
            let lower = line.lowercased()
            if lower.contains("www.") || lower.contains("http") { return false }
            if lower.contains(".com") || lower.contains(".org") || lower.contains(".it") || lower.contains(".es") { return false }
            if ["facebook", "instagram", "tiktok", "tripadvisor", "twitter",
                "follow us", "síguenos", "seguici", "whatsapp"]
                .contains(where: { lower.contains($0) }) { return false }
            if lower.hasPrefix("tel") || lower.hasPrefix("+") { return false }
            let digits = line.filter { $0.isNumber }
            if digits.count > 8 && !line.contains("$") && !line.contains("€") && !line.contains("£") { return false }
            if ["google maps", "touchprint", "zte blade", "fecha de la imagen",
                "protegidas por derechos", "las imágenes pueden",
                "foto -", "copyright", "todos los derechos"]
                .contains(where: { lower.contains($0) }) { return false }
            if lower.hasPrefix("via ") || lower.hasPrefix("calle ") || lower.hasPrefix("c/") { return false }
            if lower.hasPrefix("p.iva") || lower.hasPrefix("c.f.") { return false }
            return true
        }

        lines = lines.map { line in
            var f = line
            let fixes: [(String, String)] = [
                ("COPER TO", "COPERTO"), ("SER VIZIO", "SERVIZIO"),
                ("SERV IZIO", "SERVIZIO"), ("CO PER TO", "COPERTO"),
            ]
            for (wrong, right) in fixes { f = f.replacingOccurrences(of: wrong, with: right) }
            return f
        }

        lines = lines.filter { line in
            let lower = line.lowercased()
            return !["servizio e coperto", "servicio y cubierto", "cover charge", "service charge",
                      "ogni aggiunta o variazione", "sala interna coperto", "la nostra pasta contiene glutine",
                      "allergeni sono indicati"]
                .contains(where: { lower.contains($0) })
        }

        lines = lines.filter { line in
            let stripped = line.replacingOccurrences(of: " ", with: "")
            if stripped.allSatisfy({ $0.isPunctuation || $0.isSymbol }) && !stripped.isEmpty { return false }
            if line.count == 1 { return false }
            return true
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Local Allergen Detection (safety net)

    private static func detectAllergensLocally(in text: String) -> Set<String> {
        var found: Set<String> = []
        for (allergenId, keywords) in allergenKeywordMap {
            if keywords.contains(where: { text.contains($0) }) {
                found.insert(allergenId)
            }
        }
        return found
    }

    private static let allergenKeywordMap: [String: [String]] = [
        "gluten": [
            "wheat", "flour", "bread", "pasta", "barley", "rye", "oat", "semolina", "couscous",
            "noodle", "dough", "pastry", "cracker", "trigo", "harina", "avena", "cebada", "centeno",
            "farina", "orzo", "segale", "beer", "cerveza", "birra",
            "spaghetti", "gnocchi", "penne", "rigatoni", "fettuccine", "linguine", "tagliatelle",
            "lasagna", "ravioli", "tortellini", "pizza", "focaccia", "bruschetta", "crostini",
            "ziti", "fusilli", "pappardelle", "cannelloni"
        ],
        "dairy": [
            "milk", "cheese", "cream", "butter", "yogurt", "mozzarella", "parmesan", "parmigiano",
            "ricotta", "mascarpone", "brie", "feta", "whey", "ghee", "paneer",
            "provola", "provolone", "pecorino", "gorgonzola", "burrata", "scamorza",
            "leche", "queso", "crema", "mantequilla", "yogur", "nata",
            "latte", "formaggio", "burro", "panna"
        ],
        "eggs": [
            "egg", "mayonnaise", "meringue", "aioli", "carbonara",
            "huevo", "mayonesa", "uovo", "uova", "maionese", "frittata"
        ],
        "fish": [
            "fish", "salmon", "tuna", "cod", "anchovy", "sardine", "bass", "trout",
            "halibut", "swordfish", "mackerel", "orata", "branzino", "baccalà",
            "pescado", "atún", "bacalao", "anchoa", "sardina", "trucha",
            "pesce", "tonno", "merluzzo", "acciuga", "alici", "pesce spada"
        ],
        "crustaceans": [
            "shrimp", "prawn", "crab", "lobster", "crawfish", "langoustine",
            "gamberi", "gamba", "cangrejo", "langosta", "gambero", "aragosta", "gambas", "scampi"
        ],
        "peanuts": ["peanut", "cacahuete", "arachide", "maní"],
        "soy": ["soy", "soja", "tofu", "edamame", "tempeh", "miso"],
        "tree_nuts": [
            "almond", "walnut", "cashew", "pistachio", "pecan", "hazelnut", "macadamia",
            "chestnut", "pine nut", "almendra", "nuez", "avellana", "pistacho",
            "mandorla", "noce", "nocciola", "pistacchio", "pinoli"
        ],
        "celery": ["celery", "celeriac", "apio", "sedano"],
        "mustard": ["mustard", "mostaza", "senape"],
        "sesame": ["sesame", "tahini", "sesamo"],
        "sulfites": ["wine", "vinegar", "sulfite", "vino", "vinagre", "aceto", "marsala"],
        "lupins": ["lupin", "lupini", "altramuz"],
        "mollusks": [
            "mussel", "clam", "oyster", "squid", "octopus", "scallop", "calamari", "snail",
            "almeja", "ostra", "calamar", "pulpo",
            "cozza", "cozze", "vongola", "vongole", "ostrica", "polpo", "calamaro",
            "frutti di mare", "seppia", "totano"
        ],
        "lactose": [
            "milk", "cheese", "cream", "butter", "yogurt", "ice cream",
            "provola", "provolone", "mozzarella", "ricotta", "pecorino", "parmigiano", "burrata",
            "leche", "queso", "crema", "mantequilla", "yogur", "helado",
            "latte", "formaggio", "burro", "gelato"
        ],
        "fructose": ["honey", "apple", "pear", "mango", "agave", "miel", "manzana", "pera", "miele", "mela"],
        "histamine": [
            "wine", "aged cheese", "fermented", "cured", "smoked", "vinegar",
            "vino", "ahumado", "curado", "fermentado", "affumicato", "stagionato",
            "salame", "prosciutto", "ciccioli", "lardati"
        ],
        "fodmap": ["garlic", "onion", "wheat", "apple", "pear", "ajo", "cebolla", "trigo", "manzana", "aglio", "cipolla"]
    ]
}
