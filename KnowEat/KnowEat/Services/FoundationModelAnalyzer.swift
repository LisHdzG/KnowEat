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
    @Guide(description: "Restaurant name from branding/logo/header text. Use 'Unknown' if not visible. Use 'NOT_A_MENU' if the text is clearly NOT a restaurant food menu.")
    var restaurant: String

    @Guide(description: "Icon: beer, dinner, fried-rice, lasagna, lunch-bag, nachos, pancake, pasta, pastry, pizza-slice, ramen, restaurant, rice, salad, sausage, shrimp, taco")
    var categoryIcon: String

    @Guide(description: "Every dish and drink extracted from the menu, in the same order as the original text. Empty array if this is not a menu.")
    var dishes: [GeneratedDish]
}

@Generable
struct GeneratedDish {
    @Guide(description: "Dish name exactly as written on the menu, in the original language. Max 8 words.")
    var name: String

    @Guide(description: "Brief description translated to the user's language explaining what the dish is and its main components.")
    var dishDescription: String

    @Guide(description: "true if this is a real orderable food or drink item. false if it is a section header, category title, restaurant name, subtitle, decoration, or any non-orderable text.")
    var isActualDish: Bool

    @Guide(description: "Ingredients written on the menu for this dish, translated to English. Empty array if none listed.")
    var ingredients: [String]

    @Guide(description: "Common ingredients this dish typically contains but NOT written on the menu, in English. Empty array if you truly cannot infer any.")
    var inferredIngredients: [String]

    @Guide(description: "Allergen/content IDs based ONLY on explicit ingredients listed on the menu. Valid IDs: gluten, dairy, eggs, fish, crustaceans, peanuts, soy, tree_nuts, celery, mustard, sesame, sulfites, lupins, mollusks, lactose, fructose, histamine, fodmap, meat, poultry, pork, alcohol")
    var allergenIds: [String]

    @Guide(description: "Allergen/content IDs that MAY apply based on inferred ingredients (AI suggestion, not confirmed). Same valid IDs as allergenIds. Empty array if no inferences.")
    var suggestedAllergenIds: [String]
}

// MARK: - Errors

enum FoundationModelError: LocalizedError {
    case modelNotAvailable
    case generationFailed(String)
    case notAMenu

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "On-device AI model is not available on this device."
        case .generationFailed(let message):
            return "AI analysis failed: \(message)"
        case .notAMenu:
            return "The image does not appear to be a restaurant menu."
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
        "lupins", "mollusks", "lactose", "fructose", "histamine", "fodmap",
        "meat", "poultry", "pork", "alcohol"
    ]

    private static let maxOCRCharacters = 6000

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
            You are a restaurant menu reader. You receive OCR text extracted from a photo. \
            \
            STEP 1 — VALIDATE: \
            Determine if this text is from a restaurant food menu. \
            A restaurant menu lists multiple food or drink items that diners can order. \
            If the text is NOT a menu (e.g. a product label, ingredient list on packaging, \
            nutrition facts, receipt, invoice, bottle/wine label, cereal box, \
            screenshot from a delivery app, book page, random text, \
            or any non-menu document), set restaurant to "NOT_A_MENU" and return an \
            empty dishes array. Do NOT invent dishes from non-menu text. \
            \
            STEP 2 — EXTRACT (only if it IS a menu): \
            1. Find the restaurant name from headers, logos, or branding. "Unknown" if not visible. \
            2. Extract every dish and drink that is clearly written in the menu. \
            \
            CRITICAL ORDER RULE: \
            Extract dishes in the EXACT sequential order they appear line by line in the text. \
            Do NOT reorder, group, or sort them. The first dish in the text must be the first \
            in the array, the second dish must be second, and so on. \
            \
            DISH vs NON-DISH RULE: \
            - Set isActualDish to true ONLY for real orderable food/drink items. \
            - Set isActualDish to false for: section headers, category titles (e.g. "ANTIPASTI", \
            "Entrantes", "Desserts", "PIZZAS", "BEBIDAS"), restaurant names, subtitles, \
            decorative text, slogans, prices without a dish, or any non-orderable text. \
            - A dish must be something a customer can order and eat/drink. \
            - Category headers typically appear in ALL CAPS or as standalone lines without a price. \
            \
            CRITICAL EXTRACTION RULES: \
            - Extract ONLY items explicitly written in the text. NEVER invent or fabricate dishes. \
            - Keep dish names EXACTLY as written in the original language of the menu. \
            - Fix obvious OCR typos using food knowledge, but do not change dish names significantly. \
            - Skip non-food text: addresses, phone numbers, URLs, slogans, decorative text, \
            allergen disclaimers, service charges, cover charges, section dividers. \
            - Translate the dishDescription to \(userLanguage). \
            - Write ALL ingredient names in English, regardless of the menu language. \
            \
            INGREDIENT RULES: \
            - List ingredients explicitly written on the menu for each dish (translated to English). \
            - Infer common additional ingredients the dish typically contains (in English). \
            - If you cannot recognize a dish at all, set inferredIngredients to ["Unrecognized dish"]. \
            \
            ALLERGEN RULES: \
            - allergenIds: ONLY from ingredients explicitly listed on the menu. \
            - suggestedAllergenIds: From inferred ingredients (AI suggestion, not confirmed).
            """
        )

        let cleanedText = Self.preprocessOCRText(ocrText)

        let truncatedText = cleanedText.count > Self.maxOCRCharacters
            ? String(cleanedText.prefix(Self.maxOCRCharacters))
            : cleanedText

        let prompt = """
        Analyze this text. If it is a restaurant menu, extract all dishes and drinks \
        in the order they appear. If it is NOT a menu, return empty results.

        TEXT:
        \(truncatedText)
        """

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedMenu.self)
            return try buildScannedMenu(from: response.content, ocrText: cleanedText, userLanguage: userLanguage)
        } catch is FoundationModelError {
            throw FoundationModelError.notAMenu
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
                    price: nil,
                    category: nil,
                    ingredients: dish.ingredients,
                    allergenIds: dish.allergenIds,
                    inferredIngredients: dish.inferredIngredients,
                    suggestedAllergenIds: dish.suggestedAllergenIds,
                    textRegionIndices: dish.textRegionIndices
                ))
            } catch {
                translatedDishes.append(dish)
            }
        }

        return (restaurant: restaurant, dishes: translatedDishes)
    }

    // MARK: - Build ScannedMenu (post-processing)

    private func buildScannedMenu(from generated: GeneratedMenu, ocrText: String, userLanguage: String) throws -> ScannedMenu {
        if generated.restaurant.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "NOT_A_MENU" {
            throw FoundationModelError.notAMenu
        }

        let icon = Self.validIcons.contains(generated.categoryIcon) ? generated.categoryIcon : "restaurant"

        let candidateDishes = generated.dishes.compactMap { gd -> Dish? in
            guard gd.isActualDish else { return nil }
            let trimmedName = gd.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            guard !Self.isJunkEntry(trimmedName) else { return nil }

            let finalName = trimmedName.count > 60
                ? String(trimmedName.split(separator: " ").prefix(8).joined(separator: " "))
                : trimmedName

            let explicitText = (gd.ingredients + [finalName, gd.dishDescription])
                .joined(separator: " ").lowercased()
            let explicitLocalAllergens = Self.detectAllergensLocally(in: explicitText)

            let llmConfirmed = Set(gd.allergenIds.filter { Self.validAllergenIds.contains($0) })
            let dbAllergens = DishDatabase.shared.allergens(forDishNamed: finalName)

            let confirmedAllergens = Array(llmConfirmed.union(explicitLocalAllergens).union(dbAllergens)).sorted()

            let inferredText = gd.inferredIngredients.joined(separator: " ").lowercased()
            let inferredLocalAllergens = Self.detectAllergensLocally(in: inferredText)
            let llmSuggested = Set(gd.suggestedAllergenIds.filter { Self.validAllergenIds.contains($0) })

            let allSuggested = llmSuggested.union(inferredLocalAllergens)
                .subtracting(confirmedAllergens)
            let suggestedAllergens = Array(allSuggested).sorted()

            return Dish(
                name: finalName,
                description: gd.dishDescription.isEmpty ? nil : gd.dishDescription,
                price: nil,
                category: nil,
                ingredients: gd.ingredients,
                allergenIds: confirmedAllergens,
                inferredIngredients: gd.inferredIngredients,
                suggestedAllergenIds: suggestedAllergens
            )
        }

        let ocrValidated = candidateDishes.filter { dish in
            Self.dishNameFoundInOCR(dish.name, ocrText: ocrText)
        }

        let dishes = Self.deduplicateDishes(ocrValidated)

        if dishes.isEmpty {
            throw FoundationModelError.notAMenu
        }

        let restaurant = Self.sanitizeRestaurantName(generated.restaurant)

        return ScannedMenu(
            restaurant: restaurant,
            dishes: dishes,
            categoryIcon: icon,
            menuLanguage: userLanguage
        )
    }

    // MARK: - OCR Cross-Validation (anti-hallucination)

    private static func dishNameFoundInOCR(_ dishName: String, ocrText: String) -> Bool {
        let normalize: (String) -> String = { s in
            s.lowercased()
             .folding(options: .diacriticInsensitive, locale: nil)
             .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let normalizedOCR = normalize(ocrText)
        let normalizedName = normalize(dishName)

        if normalizedOCR.contains(normalizedName) { return true }

        let significantWords = normalizedName
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !ocrStopWords.contains($0) }

        guard !significantWords.isEmpty else { return false }

        let matchCount = significantWords.filter { word in
            normalizedOCR.contains(word)
        }.count

        if significantWords.count <= 2 {
            return matchCount == significantWords.count
        }

        let threshold = (significantWords.count * 2 + 2) / 3
        return matchCount >= threshold
    }

    private static let ocrStopWords: Set<String> = [
        "di", "al", "alla", "alle", "allo", "agli", "del", "della", "delle", "dello", "dei",
        "con", "fra", "tra", "per", "sul", "sulla", "sulle",
        "de", "la", "el", "los", "las", "un", "una", "con", "por", "para", "sin",
        "the", "and", "with", "in", "on", "or", "of", "for",
        "le", "les", "du", "des", "au", "aux", "et",
        "e", "o", "y", "a", "em", "no", "na", "do", "da",
    ]

    // MARK: - Deduplication

    private static func deduplicateDishes(_ dishes: [Dish]) -> [Dish] {
        var seen = Set<String>()
        return dishes.filter { dish in
            let key = dish.name.lowercased()
                .folding(options: .diacriticInsensitive, locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return seen.insert(key).inserted
        }
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
            "n.b.", "nota bene", "note",
            "delivery", "pick up", "dine in", "para llevar",
            "orden", "order", "pedido",
            "extra", "add-on", "topping", "supplement",
            "regular", "xl", "xxl", "combo", "upgrade",
            // Category headers commonly misread as dishes
            "antipasti", "antipasto", "primi", "primi piatti", "secondi", "secondi piatti",
            "contorni", "dolci", "dessert", "desserts", "bevande", "bibite",
            "entrantes", "entradas", "sopas", "ensaladas", "platos fuertes",
            "platos principales", "postres", "bebidas", "aperitivos",
            "appetizers", "starters", "soups", "salads", "main courses",
            "main dishes", "sides", "side dishes", "drinks", "beverages",
            "wines", "vini", "vinos", "cocktails", "cócteles",
            "pasta", "pizze", "pizzas", "insalate", "zuppe",
            "carni", "pesce", "risotti", "focacce",
            "entrées", "plats", "hors d'oeuvres",
            "nuestros platos", "nuestra carta", "i nostri piatti", "la nostra carta",
            "our dishes", "our menu", "today's specials",
            "del día", "del giorno", "of the day",
            "brunch", "breakfast", "lunch", "dinner", "cena", "pranzo", "colazione",
            "desayuno", "almuerzo", "comida",
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
            "zte blade", "copyright",
            "add to cart", "añadir al carrito", "aggiungi",
            "delivery fee", "costo de envío",
            "minimum order", "pedido mínimo", "ordine minimo",
            "nutrition facts", "nutritional", "información nutricional",
            "calories", "calorías", "calorie",
            "serving size", "net weight", "peso neto",
            "ingredients:", "ingredientes:", "ingredienti:",
            "manufactured by", "fabricado por", "prodotto da",
            "best before", "use by", "exp date",
            "abv", "% vol", "alcohol by volume",
            "denomination of origin", "denominación de origen",
            "grape variety", "vitigno", "variedad de uva",
            "tasting notes", "notas de cata",
            "brewed by", "distilled", "brewery", "winery",
            "screenshot", "captura de pantalla",
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

        let letters = name.filter { $0.isLetter }
        if words.count <= 2 && !letters.isEmpty && letters == letters.uppercased() {
            let categoryHeaders: Set<String> = [
                "antipasti", "antipasto", "primi", "secondi", "contorni", "dolci",
                "dessert", "bevande", "bibite", "vini", "cocktails",
                "entrantes", "sopas", "ensaladas", "postres", "bebidas",
                "appetizers", "starters", "soups", "salads", "sides", "drinks",
                "pizze", "pizzas", "insalate", "zuppe", "risotti", "focacce",
                "carni", "pesce",
            ]
            if categoryHeaders.contains(lower) { return true }
        }

        return false
    }

    private static func sanitizeRestaurantName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "unknown" { return "Unknown" }
        if !trimmed.contains(where: { $0.isLetter }) { return "Unknown" }
        let lower = trimmed.lowercased()
        let genericNames: Set<String> = [
            "menù", "menu", "la carta", "the menu", "restaurant", "ristorante", "restaurante",
            "antipasti", "primi", "secondi", "dolci", "dessert", "bevande", "bibite",
            "entrantes", "entradas", "platos", "postres", "bebidas",
            "appetizers", "starters", "main courses", "drinks",
            "pizze", "pizzas", "insalate", "zuppe", "pasta",
            "our menu", "nuestra carta", "la nostra carta",
        ]
        if genericNames.contains(lower) { return "Unknown" }
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
                "follow us", "síguenos", "seguici", "whatsapp",
                "youtube", "pinterest", "snapchat", "linkedin"]
                .contains(where: { lower.contains($0) }) { return false }
            if lower.hasPrefix("tel") || lower.hasPrefix("+") { return false }
            let digits = line.filter { $0.isNumber }
            if digits.count > 8 && !line.contains("$") && !line.contains("€") && !line.contains("£") { return false }
            if ["google maps", "touchprint", "zte blade", "fecha de la imagen",
                "protegidas por derechos", "las imágenes pueden",
                "foto -", "copyright", "todos los derechos",
                "screenshot", "captura de pantalla", "schermata",
                "add to cart", "añadir al carrito", "aggiungi al carrello",
                "delivery fee", "costo de envío", "spese di consegna",
                "uber eats", "doordash", "grubhub", "deliveroo", "just eat",
                "rappi", "didi food", "glovo", "postmates",
                "your order", "tu pedido", "il tuo ordine",
                "checkout", "order now", "ordenar ahora",
                "nutrition facts", "nutritional information",
                "información nutricional", "informazioni nutrizionali",
                "serving size", "tamaño de porción",
                "calories per serving", "daily value",
                "net weight", "peso neto", "peso netto",
                "manufactured by", "fabricado por", "prodotto da",
                "best before", "consumir preferentemente",
                "abv", "alcohol by volume", "% vol",
                "grape variety", "variedad de uva", "vitigno",
                "tasting notes", "notas de cata",
                "denomination of origin", "denominación de origen",
                "d.o.c", "d.o.c.g", "i.g.t", "i.g.p"]
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
                      "allergeni sono indicati",
                      "contains sulfites", "contiene solfiti", "contiene sulfitos",
                      "may contain traces", "puede contener trazas", "può contenere tracce",
                      "produced in a facility", "elaborado en una planta",
                      "allergen warning", "aviso de alérgenos", "avvertenza allergeni",
                      "ask your server", "pregunte a su mesero", "chiedere al cameriere"]
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
        "fodmap": ["garlic", "onion", "wheat", "apple", "pear", "ajo", "cebolla", "trigo", "manzana", "aglio", "cipolla"],
        "meat": [
            "beef", "steak", "veal", "lamb", "pork", "ham", "bacon", "sausage", "salami",
            "prosciutto", "bresaola", "chorizo", "pepperoni", "mortadella", "pancetta",
            "carne", "res", "ternera", "cordero", "cerdo", "jamón", "tocino", "salchicha",
            "manzo", "vitello", "agnello", "maiale", "prosciutto",
            "meatball", "burger", "patty", "ribs", "loin", "sirloin", "filet",
            "albóndigas", "hamburguesa", "costillas", "lomo", "solomillo",
            "polpette", "costola", "filetto", "bistecca"
        ],
        "poultry": [
            "chicken", "turkey", "duck", "goose", "quail", "hen",
            "pollo", "pavo", "pato", "gallina",
            "pollo", "tacchino", "anatra", "oca", "quaglia"
        ],
        "pork": [
            "pork", "ham", "bacon", "sausage", "salami", "prosciutto", "pancetta",
            "chorizo", "pepperoni", "mortadella", "lard", "guanciale", "coppa",
            "cerdo", "jamón", "tocino", "salchicha", "manteca",
            "maiale", "lardo", "speck"
        ],
        "alcohol": [
            "wine", "beer", "cocktail", "liquor", "rum", "vodka", "whisky", "gin", "tequila",
            "brandy", "champagne", "prosecco", "sangria", "margarita", "mojito",
            "vino", "cerveza", "cóctel", "licor", "ron",
            "birra", "liquore", "grappa", "amaro", "limoncello", "spritz"
        ]
    ]
}
