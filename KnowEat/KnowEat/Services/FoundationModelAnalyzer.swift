//
//  FoundationModelAnalyzer.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation
import FoundationModels

// MARK: - Generable Structs (Pass 1: Extraction — always in English)

@Generable
struct GeneratedMenu {
    @Guide(description: "Restaurant name from branding/logo/header. 'Unknown' if not visible. 'NOT_A_MENU' if not a food menu.")
    var restaurant: String

    @Guide(description: "Icon: beer, dinner, fried-rice, lasagna, lunch-bag, nachos, pancake, pasta, pastry, pizza-slice, ramen, restaurant, rice, salad, sausage, shrimp, taco")
    var categoryIcon: String

    @Guide(description: "Every dish and drink, in the same order as the original text. Empty if not a menu.")
    var dishes: [GeneratedDish]
}

@Generable
struct GeneratedDish {
    @Guide(description: "The dish name exactly as printed on the menu, in the menu's original language. Do NOT include ingredients or descriptions in this field.")
    var name: String

    @Guide(description: "English description of this dish. Include any subtitle or secondary text from the menu that describes this dish.")
    var dishDescription: String

    @Guide(description: "true if a customer can order this item. false for section headers, categories, subtitles, translations, restaurant name, or decorative text.")
    var isActualDish: Bool

    @Guide(description: "Ingredients explicitly written on the menu for this dish, each translated to English. Empty array if the menu does not list ingredients for this dish.")
    var ingredients: [String]

    @Guide(description: "Common ingredients this dish typically has based on culinary knowledge, in English. Empty array if unsure.")
    var inferredIngredients: [String]

    @Guide(description: "Allergen IDs from explicit ingredients. Valid: gluten, dairy, eggs, fish, crustaceans, peanuts, soy, tree_nuts, celery, mustard, sesame, sulfites, lupins, mollusks, lactose, fructose, histamine, fodmap, meat, poultry, pork, alcohol")
    var allergenIds: [String]

    @Guide(description: "Allergen IDs from inferred ingredients only. Same valid IDs. Empty if none.")
    var suggestedAllergenIds: [String]
}

// MARK: - Generable Structs (Pass 2: Per-dish translation)

@Generable
struct DishTranslation {
    @Guide(description: "The dish name translated to the target language.")
    var translatedName: String

    @Guide(description: "The dish description translated to the target language.")
    var translatedDescription: String

    @Guide(description: "Each ingredient translated to the target language, same count and order.")
    var translatedIngredients: [String]
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

    private static let maxOCRCharacters = 12000

    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    enum AnalysisPhase: Sendable {
        case extracting
        case translating(current: Int, total: Int)
    }

    // MARK: - Analysis (two-pass: extract in English, then translate per-dish)

    func analyze(
        ocrText: String,
        userLanguage: String,
        onPhaseChange: (@Sendable (AnalysisPhase) -> Void)? = nil
    ) async throws -> ScannedMenu {
        guard isAvailable else {
            throw FoundationModelError.modelNotAvailable
        }

        // --- PASS 1: Extract menu content — always in English ---
        let extractSession = LanguageModelSession(
            instructions: """
            You are a restaurant menu reader. ALL output MUST be in English. \
            \
            VALIDATE: If the text is NOT a restaurant food menu (product label, \
            nutrition facts, receipt, invoice, bottle, delivery app, book, random text), \
            set restaurant to "NOT_A_MENU" with empty dishes. \
            \
            HOW TO READ A MENU LINE BY LINE: \
            Each dish typically occupies 1-3 lines: \
            LINE A: The dish name (often with a price on the same line). \
            LINE B (optional): A subtitle, description, or translation of Line A. \
            This is NOT a separate dish. Put this in dishDescription. \
            LINE C (optional): Ingredient details for the dish on Line A. \
            Put these into the ingredients array, translated to English. \
            \
            Many menus are BILINGUAL: they print the name in one language \
            and a translation on the next line. Both refer to the SAME dish. \
            Use the FIRST line as name, the second as dishDescription. \
            \
            KEY RULES: \
            - name: EXACTLY as written on the menu, original language. \
            Do NOT append ingredients or descriptions to the name field. \
            - dishDescription: English description. Include subtitles from the menu. \
            - ingredients: ONLY ingredients explicitly listed on the menu for this dish, \
            translated to English. Do NOT break the dish name into ingredients. \
            Empty array if none listed. \
            - inferredIngredients: Typical ingredients from culinary knowledge, in English. \
            - isActualDish: true ONLY for orderable items. \
            - The restaurant name is NEVER a dish. \
            - Extract dishes in the EXACT order they appear.
            """
        )

        onPhaseChange?(.extracting)

        let cleanedText = Self.preprocessOCRText(ocrText)

        let truncatedText = cleanedText.count > Self.maxOCRCharacters
            ? String(cleanedText.prefix(Self.maxOCRCharacters))
            : cleanedText

        let extractPrompt = """
        Read this menu and extract every dish. \
        Write all descriptions and ingredients in English. \
        Subtitle lines below a dish name are descriptions, NOT separate dishes. \
        \
        TEXT: \
        \(truncatedText)
        """

        let generated: GeneratedMenu
        do {
            let response = try await extractSession.respond(to: extractPrompt, generating: GeneratedMenu.self)
            generated = response.content
        } catch {
            throw FoundationModelError.generationFailed(error.localizedDescription)
        }

        var menu = try buildScannedMenu(from: generated, ocrText: cleanedText)

        // --- PASS 2: Translate each dish individually ---
        if userLanguage != "English" && !menu.dishes.isEmpty {
            menu.dishes = await translateDishesIndividually(menu.dishes, to: userLanguage, onPhaseChange: onPhaseChange)
        }

        return menu
    }

    // MARK: - Per-Dish Translation (one AI call per dish — maximum reliability)

    private func translateDishesIndividually(
        _ dishes: [Dish],
        to language: String,
        onPhaseChange: (@Sendable (AnalysisPhase) -> Void)? = nil
    ) async -> [Dish] {
        let session = LanguageModelSession(
            instructions: """
            You are a food translator. \
            Translate dish names, descriptions, and ingredients to \(language). \
            Use proper culinary terms in \(language).
            """
        )

        var result: [Dish] = []
        let total = dishes.count

        for (index, dish) in dishes.enumerated() {
            onPhaseChange?(.translating(current: index + 1, total: total))
            let ingredientList = dish.ingredients.isEmpty
                ? "none"
                : dish.ingredients.joined(separator: ", ")
            let desc = dish.description ?? ""

            let prompt = """
            Translate to \(language): \
            name: \(dish.name) | \
            description: \(desc) | \
            ingredients: \(ingredientList)
            """

            do {
                let response = try await session.respond(to: prompt, generating: DishTranslation.self)
                let t = response.content

                let tName = t.translatedName.trimmingCharacters(in: .whitespacesAndNewlines)
                let effectiveName: String? = if tName.isEmpty
                    || tName.lowercased() == dish.name.lowercased() {
                    nil
                } else {
                    tName
                }

                let tDesc = t.translatedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let tIngr = t.translatedIngredients.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                result.append(Dish(
                    from: dish,
                    translatedName: effectiveName,
                    translatedDescription: tDesc.isEmpty ? dish.description : tDesc,
                    translatedIngredients: tIngr.isEmpty ? dish.ingredients : tIngr,
                    translatedInferredIngredients: dish.inferredIngredients
                ))
            } catch {
                result.append(dish)
            }
        }

        return result
    }

    // MARK: - Build ScannedMenu (post-processing)

    private func buildScannedMenu(from generated: GeneratedMenu, ocrText: String) throws -> ScannedMenu {
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

            let explicitText = (gd.ingredients + [gd.dishDescription])
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

        let restaurantLower = generated.restaurant.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let ocrValidated = candidateDishes.filter { dish in
            let dishLower = dish.name.lowercased()
                .folding(options: .diacriticInsensitive, locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !restaurantLower.isEmpty && restaurantLower != "unknown"
                && (dishLower == restaurantLower || restaurantLower.contains(dishLower) || dishLower.contains(restaurantLower)) {
                return false
            }
            return Self.dishNameFoundInOCR(dish.name, ocrText: ocrText)
        }

        let dishes = Self.deduplicateDishes(ocrValidated)

        if dishes.isEmpty {
            throw FoundationModelError.notAMenu
        }

        return ScannedMenu(
            restaurant: "Unknown",
            dishes: dishes,
            categoryIcon: icon,
            menuLanguage: "Unknown"
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
            // Italian categories (simple and compound)
            "antipasti", "antipasto", "primi", "primi piatti", "secondi", "secondi piatti",
            "contorni", "dolci", "dessert", "desserts", "bevande", "bibite",
            "antipasti di mare", "antipasti di terra", "antipasti misti",
            "primi di mare", "primi di terra", "primi piatti di mare", "primi piatti di terra",
            "secondi di mare", "secondi di terra", "secondi piatti di mare", "secondi piatti di terra",
            "piatti di mare", "piatti di terra", "piatti principali",
            "dolci della tradizione", "dolci della tradizione napoletana",
            "dolci della casa", "dolci homemade",
            "birre", "birra", "liquori", "liquore", "amari",
            "vini rossi", "vini bianchi", "vini della casa", "vini al bicchiere",
            "vini", "vino", "vinos",
            "contorni e insalate", "pizze e focacce",
            "zuppe e minestre", "paste fresche", "paste al forno",
            "crudi di mare", "fritti", "grigliate", "grigliata",
            "aperitivi", "digestivi", "caffetteria",
            "- side dishes -", "- sweets -", "- drinks -", "- beers -", "- liquors -",
            "- first of earth -", "- seconds of the sea -", "- earth seconds -",
            "first of earth", "seconds of the sea", "earth seconds",
            // Spanish categories
            "entrantes", "entradas", "sopas", "ensaladas", "platos fuertes",
            "platos principales", "postres", "bebidas", "aperitivos",
            "antojitos", "tacos", "quesadillas", "volcanes",
            "especialidades", "para compartir", "para empezar",
            "extras", "acompañamientos", "guarniciones",
            "aguas", "refrescos", "cervezas", "vinos", "cocktails", "cócteles",
            // English categories
            "appetizers", "starters", "soups", "salads", "main courses",
            "main dishes", "sides", "side dishes", "drinks", "beverages",
            "wines", "cocktails", "beers", "spirits",
            "small plates", "large plates", "shareable", "shareables",
            "flight bites", "atmospheric spirits", "crew brews",
            "worldly wines", "zero-proof cocktails",
            // French categories
            "entrées", "plats", "hors d'oeuvres", "boissons",
            "nos apéritifs", "nos bières", "les eaux", "les softs",
            "nos producteurs", "les planches apéro",
            "fromage et desserts", "fromages", "formules",
            // Turkish categories
            "başlangıçlar", "ana yemekler", "tatlılar", "içecekler",
            "çorbalar", "salatalar", "mezeler",
            // Generic structural
            "pasta", "pizze", "pizzas", "insalate", "zuppe",
            "carni", "pesce", "risotti", "focacce",
            "nuestros platos", "nuestra carta", "i nostri piatti", "la nostra carta",
            "our dishes", "our menu", "today's specials",
            "del día", "del giorno", "of the day",
            "brunch", "breakfast", "lunch", "dinner", "cena", "pranzo", "colazione",
            "desayuno", "almuerzo", "comida",
            // Subtitles / translations of categories
            "traditional neapolitan desserts", "sparkling or still water",
            "normative sugli allergeni",
        ]
        if junkExact.contains(lower) { return true }

        let junkContains = [
            "servizio", "coperto", "cover charge", "service charge",
            "www.", "http",
            "facebook", "instagram", "tiktok", "tripadvisor", "twitter",
            "follow us", "síguenos", "seguici",
            "iva inclusa", "iva incluida", "tax included",
            "google maps", "touchprint",
            "la nostra pasta contiene", "allergeni sono indicati",
            "copyright",
            "add to cart", "añadir al carrito", "aggiungi al carrello",
            "delivery fee", "costo de envío",
            "minimum order", "pedido mínimo", "ordine minimo",
            "nutrition facts", "información nutricional",
            "serving size", "net weight", "peso neto",
            "manufactured by", "fabricado por", "prodotto da",
            "best before", "use by", "exp date",
            "alcohol by volume",
            "denomination of origin", "denominación de origen",
            "screenshot", "captura de pantalla",
            "normative sugli allergeni", "dear customers",
            "si avvisa la gentile clientela",
            "please ask our staff",
            "precios con iva", "servicio a domicilio",
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
        if words.count <= 3 && !letters.isEmpty && letters == letters.uppercased() {
            let categoryHeaders: Set<String> = [
                "antipasti", "antipasto", "primi", "secondi", "contorni", "dolci",
                "dessert", "bevande", "bibite", "vini", "cocktails", "birre", "liquori",
                "entrantes", "sopas", "ensaladas", "postres", "bebidas", "tacos",
                "appetizers", "starters", "soups", "salads", "sides", "drinks",
                "pizze", "pizzas", "insalate", "zuppe", "risotti", "focacce",
                "carni", "pesce", "fritti", "grigliate", "aperitivi", "digestivi",
                "extras", "especialidades", "quesadillas", "volcanes",
            ]
            if categoryHeaders.contains(lower) { return true }
        }

        let stripped = lower.trimmingCharacters(in: CharacterSet(charactersIn: "-–—· "))
        if stripped != lower && junkExact.contains(stripped) { return true }

        let categoryPrefixes = [
            "antipasti ", "primi ", "secondi ", "piatti ",
            "dolci ", "crudi ", "fritti ",
        ]
        if categoryPrefixes.contains(where: { lower.hasPrefix($0) }) {
            let foodIndicators = ["con ", "alla ", "al ", "alle ", "allo ", "e ", "di pesce", "fritto", "fritte", "marinato", "arrosto"]
            let looksLikeDish = foodIndicators.contains(where: { lower.contains($0) }) && words.count >= 3
            if !looksLikeDish { return true }
        }

        let letterChars = name.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let totalChars = name.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        if !totalChars.isEmpty && letterChars.count < totalChars.count / 2 { return true }

        if letters.count >= 3 {
            let vowels: Set<Character> = ["a","e","i","o","u","á","é","í","ó","ú","à","è","ì","ò","ù","ä","ö","ü","â","ê","î","ô","û"]
            let consonants = letters.lowercased().filter { !vowels.contains($0) }
            let vowelCount = letters.lowercased().filter { vowels.contains($0) }.count
            if vowelCount == 0 && consonants.count >= 3 { return true }

            var maxConsecutiveConsonants = 0
            var currentRun = 0
            for ch in letters.lowercased() {
                if vowels.contains(ch) {
                    currentRun = 0
                } else {
                    currentRun += 1
                    maxConsecutiveConsonants = max(maxConsecutiveConsonants, currentRun)
                }
            }
            if maxConsecutiveConsonants >= 5 { return true }
        }

        return false
    }

    private static func sanitizeRestaurantName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "unknown" { return "Unknown" }

        let letterCount = trimmed.filter { $0.isLetter }.count
        if letterCount == 0 { return "Unknown" }

        let nonSpaceCount = trimmed.filter { !$0.isWhitespace }.count
        if nonSpaceCount > 0 && letterCount < nonSpaceCount / 2 { return "Unknown" }

        let stripped = trimmed.replacingOccurrences(of: " ", with: "")
        if stripped.range(of: #"^\d{1,2}[:.]\d{2}$"#, options: .regularExpression) != nil {
            return "Unknown"
        }
        if stripped.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == ":" || $0 == "-" || $0 == "/" }) {
            return "Unknown"
        }

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
            if ["facebook.com", "instagram.com", "tripadvisor.com", "google.com"]
                .contains(where: { lower.contains($0) }) { return false }
            if ["google maps", "touchprint", "copyright", "todos los derechos",
                "screenshot", "captura de pantalla",
                "uber eats", "doordash", "grubhub", "deliveroo", "just eat",
                "rappi", "didi food", "glovo",
                "nutrition facts", "nutritional information",
                "información nutricional", "informazioni nutrizionali"]
                .contains(where: { lower.contains($0) }) { return false }
            if lower.hasPrefix("p.iva") || lower.hasPrefix("c.f.") { return false }
            return true
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
        let words = Set(
            text.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .map { $0.lowercased() }
                .filter { !$0.isEmpty }
        )
        for (allergenId, keywords) in allergenKeywordMap {
            for keyword in keywords {
                if keyword.contains(" ") {
                    if text.contains(keyword) {
                        found.insert(allergenId)
                        break
                    }
                } else {
                    if words.contains(keyword) {
                        found.insert(allergenId)
                        break
                    }
                }
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
            "leche", "queso", "mantequilla", "yogur", "nata",
            "formaggio", "panna"
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
            "leche", "queso", "mantequilla", "yogur", "helado",
            "formaggio", "gelato"
        ],
        "fructose": ["honey", "apple", "pear", "mango", "agave", "miel", "manzana"],
        "histamine": [
            "wine", "aged cheese", "fermented", "cured", "smoked", "vinegar",
            "vino", "ahumado", "curado", "fermentado", "affumicato", "stagionato",
            "salame", "prosciutto", "ciccioli", "lardati"
        ],
        "fodmap": ["garlic", "onion", "wheat", "apple", "ajo", "cebolla", "trigo", "manzana", "aglio", "cipolla"],
        "meat": [
            "beef", "steak", "veal", "lamb", "pork", "bacon", "sausage", "salami",
            "prosciutto", "bresaola", "chorizo", "pepperoni", "mortadella", "pancetta",
            "carne", "carne de res", "ternera", "cordero", "cerdo", "jamón", "tocino", "salchicha",
            "manzo", "vitello", "agnello", "maiale",
            "meatball", "burger", "patty", "ribs", "sirloin",
            "albóndigas", "hamburguesa", "costillas", "lomo", "solomillo",
            "polpette", "filetto", "bistecca"
        ],
        "poultry": [
            "chicken", "turkey", "duck", "goose", "quail", "hen",
            "pollo", "pavo", "pato", "gallina",
            "pollo", "tacchino", "anatra", "oca", "quaglia"
        ],
        "pork": [
            "pork", "bacon", "sausage", "salami", "prosciutto", "pancetta",
            "chorizo", "pepperoni", "mortadella", "lard", "guanciale", "coppa",
            "cerdo", "jamón", "tocino", "salchicha",
            "maiale", "lardo", "speck"
        ],
        "alcohol": [
            "wine", "beer", "cocktail", "liquor", "rum", "vodka", "whisky", "tequila",
            "brandy", "champagne", "prosecco", "sangria", "margarita", "mojito",
            "vino", "cerveza", "cóctel", "licor", "ron",
            "birra", "liquore", "grappa", "amaro", "limoncello", "spritz"
        ]
    ]
}
