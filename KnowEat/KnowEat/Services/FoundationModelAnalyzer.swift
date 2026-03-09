//
//  FoundationModelAnalyzer.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation
import FoundationModels

// MARK: - Generable Structs (Pass 1: Strict extraction)

@Generable
struct GeneratedMenu {
    @Guide(description: "Restaurant name from the top 1-3 lines of the menu (branding/logo/header). 'Unknown' if not clearly visible. 'NOT_A_MENU' if the text is not a restaurant food menu.")
    var restaurant: String

    @Guide(description: "Best icon for the overall menu type. Choose one: beer, dinner, fried-rice, lasagna, lunch-bag, nachos, pancake, pasta, pastry, pizza-slice, ramen, restaurant, rice, salad, sausage, shrimp, taco")
    var categoryIcon: String

    @Guide(description: "Every orderable dish or drink item, in the exact order they appear in the text. Empty array if not a menu.")
    var dishes: [GeneratedDish]
}

@Generable
struct GeneratedDish {
    @Guide(description: """
    The dish name EXACTLY as it appears in the original OCR text, preserving the original language. \
    This field is used for bounding-box matching in the UI. \
    RULES: Short (1–4 words). NEVER contains commas. \
    NEVER put ingredient lists or descriptions here. \
    NEVER put category headings (Antipasti, Starters, Pizzas, Drinks…) here.
    """)
    var name: String

    @Guide(description: """
    English translation of the dish name. \
    If the original name is already in English, repeat it here. \
    This field is used for ingredient and allergen database lookups. \
    Same short format as 'name' — no commas, no ingredient lists.
    """)
    var englishName: String

    @Guide(description: """
    English translation of any description or ingredient text written on the menu FOR THIS DISH. \
    Empty string if the menu writes nothing. DO NOT invent or hallucinate a description.
    """)
    var dishDescription: String

    @Guide(description: """
    true → the item is orderable by a customer. \
    false → it is a section heading, category label, restaurant name, subtitle, \
    decorative text, or a bilingual translation line of the previous dish.
    """)
    var isActualDish: Bool

    @Guide(description: """
    Ingredients explicitly written on the menu for this dish, each translated to English. \
    Empty array if the menu does not list ingredients for this dish. \
    Do NOT include the dish name itself as an ingredient.
    """)
    var ingredients: [String]

    @Guide(description: "Typical ingredients this dish usually contains based on culinary knowledge, in English. Empty array if genuinely unsure.")
    var inferredIngredients: [String]

    @Guide(description: """
    Allergen IDs from EXPLICIT ingredients only. \
    Valid IDs: gluten, dairy, eggs, fish, crustaceans, peanuts, soy, tree_nuts, \
    celery, mustard, sesame, sulfites, lupins, mollusks, lactose, fructose, \
    histamine, fodmap, meat, poultry, pork, alcohol
    """)
    var allergenIds: [String]

    @Guide(description: "Allergen IDs from INFERRED ingredients only. Same valid IDs. Empty if none inferred.")
    var suggestedAllergenIds: [String]
}

// MARK: - Generable Structs (Pass 2: Per-dish user-language translation)

@Generable
struct DishTranslation {
    @Guide(description: "The dish name translated to the target language.")
    var translatedName: String

    @Guide(description: "The dish description translated to the target language.")
    var translatedDescription: String

    @Guide(description: "Each ingredient translated to the target language, same count and order as input.")
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

    private static let maxOCRCharacters = 12_000

    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    enum AnalysisPhase: Sendable {
        case extracting
        case translating(current: Int, total: Int)
    }

    // MARK: - Main Entry Point

    func analyze(
        ocrText: String,
        userLanguage: String,
        onPhaseChange: (@Sendable (AnalysisPhase) -> Void)? = nil
    ) async throws -> ScannedMenu {
        guard isAvailable else {
            throw FoundationModelError.modelNotAvailable
        }

        onPhaseChange?(.extracting)

        let cleanedText = Self.preprocessOCRText(ocrText)
        let truncated = cleanedText.count > Self.maxOCRCharacters
            ? String(cleanedText.prefix(Self.maxOCRCharacters))
            : cleanedText

        // PASS 1 ── Strict extraction (always in English for allergen analysis)
        let extractSession = LanguageModelSession(
            instructions: Self.extractionSystemPrompt
        )

        let extractPrompt = """
        Read this menu and extract every orderable item following the system rules exactly.

        ANTI-CONFUSION REMINDERS:
        • The restaurant name is in the FIRST 1-3 lines and has no price.
        • Section headings (Antipasti, Starters, Pizzas, Drinks, Bebidas…) are NOT dishes — set isActualDish=false.
        • Bilingual menus often repeat the dish name in a second language on the next line — that is ONE dish, NOT two.
        • If a line contains commas or conjunctions (and, with, con, e, mit, avec), it is a description/ingredients line. Put it in dishDescription, NOT in name.
        • name must be short (1-4 words) and match the exact OCR text.
        • englishName must be the English translation (or copy of name if already English).
        • dishDescription must be in English. Leave empty if the menu writes nothing.

        RAW OCR TEXT:
        \(truncated)
        """

        let generated: GeneratedMenu
        do {
            let response = try await extractSession.respond(to: extractPrompt, generating: GeneratedMenu.self)
            generated = response.content
        } catch {
            throw FoundationModelError.generationFailed(error.localizedDescription)
        }

        var menu = try buildScannedMenu(from: generated, ocrText: cleanedText)

        // PASS 2 ── Per-dish translation into user's native language (FROM English — more reliable)
        if userLanguage != "English", !menu.dishes.isEmpty {
            menu.dishes = await translateDishesIndividually(menu.dishes, to: userLanguage, onPhaseChange: onPhaseChange)
        }

        return menu
    }

    // MARK: - System Prompt (Pass 1)

    private static let extractionSystemPrompt = """
    You are a strict, highly accurate culinary data extraction system. \
    You receive raw OCR text from a restaurant menu.

    YOUR WORKFLOW & LANGUAGE RULES:
    1. The input text may be in ANY language (e.g., Italian, Spanish, Korean, Japanese).
    2. Extract the exact original dish name for 'name' — this is used for bounding-box \
       UI matching and MUST match the OCR text precisely.
    3. Always output an English translation in 'englishName' and 'dishDescription' \
       so the allergen and ingredient databases can analyze them.

    ANTI-CONFUSION RULES (CRITICAL):
    RESTAURANT NAME: Almost always in the first 1-3 lines of the text. \
    It stands alone with no price. Once identified, never use it as a dish.

    CATEGORY HEADINGS: Lines like "Starters", "Antipasti", "Primi Piatti", "Postres", \
    "Pizzas", "Drinks", "Bevande", "Bebidas", "Platos Fuertes", "Secondi Piatti". \
    These are section separators → set isActualDish=false.

    DISH NAME vs. INGREDIENTS RULE (most important):
    • A dish name (name field) is SHORT — 1 to 4 words — and NEVER contains commas.
    • If a line contains commas (',') or culinary conjunctions ('and', 'with', 'con', \
      'e', 'mit', 'avec', 'y', 'og'), it is ALWAYS a description/ingredients line. \
      Put it in dishDescription. NEVER put comma-separated text in the name field.
    • If a dish has no description written on the menu, leave dishDescription EMPTY. \
      Do NOT invent or hallucinate a description.

    BILINGUAL MENUS:
    • Many menus print the dish name in one language, then repeat it in a second \
      language on the very next line. Both refer to the SAME dish — they are NOT two \
      separate dishes. Use the first line as 'name'. Use the second line as 'dishDescription' \
      if it adds context, otherwise leave it empty.

    OUTPUT: Follow the structured format exactly. All descriptions and ingredients in English.
    """

    // MARK: - Pass 2: Per-Dish Translation

    private func translateDishesIndividually(
        _ dishes: [Dish],
        to language: String,
        onPhaseChange: (@Sendable (AnalysisPhase) -> Void)? = nil
    ) async -> [Dish] {
        let session = LanguageModelSession(
            instructions: """
            You are a food translator. Translate dish names, descriptions, \
            and ingredients to \(language). Use proper culinary terms in \(language). \
            Translate only — do not add, remove, or explain.
            """
        )

        var result: [Dish] = []
        let total = dishes.count

        for (index, dish) in dishes.enumerated() {
            onPhaseChange?(.translating(current: index + 1, total: total))

            // Translate FROM English (englishName / dishDescription already in English)
            let sourceName = dish.englishName ?? dish.name
            let sourceDesc = dish.description ?? ""
            let ingredientList = dish.ingredients.isEmpty
                ? "none"
                : dish.ingredients.joined(separator: ", ")

            let prompt = """
            Translate to \(language):
            name: \(sourceName) | description: \(sourceDesc) | ingredients: \(ingredientList)
            """

            do {
                let response = try await session.respond(to: prompt, generating: DishTranslation.self)
                let t = response.content

                let tName = t.translatedName.trimmingCharacters(in: .whitespacesAndNewlines)
                let effectiveName: String? = if tName.isEmpty
                    || tName.lowercased() == sourceName.lowercased() {
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

    // MARK: - Build ScannedMenu

    private func buildScannedMenu(from generated: GeneratedMenu, ocrText: String) throws -> ScannedMenu {
        if generated.restaurant.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "NOT_A_MENU" {
            throw FoundationModelError.notAMenu
        }

        let icon = Self.validIcons.contains(generated.categoryIcon) ? generated.categoryIcon : "restaurant"

        let candidateDishes = generated.dishes.compactMap { gd -> Dish? in
            guard gd.isActualDish else { return nil }

            let trimmedName = gd.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            guard !Self.isJunkEntry(trimmedName) else { return nil }

            let finalName = trimmedName.count > 60
                ? String(trimmedName.split(separator: " ").prefix(8).joined(separator: " "))
                : trimmedName

            let trimmedEnglish = gd.englishName.trimmingCharacters(in: .whitespacesAndNewlines)
            let englishName: String? = (trimmedEnglish.isEmpty || trimmedEnglish.lowercased() == finalName.lowercased())
                ? nil
                : trimmedEnglish

            // Use the English name for allergen/DB lookups (more reliable keyword matching)
            let lookupName = englishName ?? finalName
            let lookupText = (gd.ingredients + [gd.dishDescription]).joined(separator: " ").lowercased()

            // Layer 1: LLM-declared allergens (validated against known IDs)
            let llmConfirmed = Set(gd.allergenIds.filter { Self.validAllergenIds.contains($0) })

            // Layer 2: Local keyword scan on explicit text (English is best for this)
            let explicitLocalAllergens = Self.detectAllergensLocally(in: lookupText)

            // Layer 3: DishDatabase lookup using English name
            let dbAllergens = DishDatabase.shared.allergens(forDishNamed: lookupName)

            let confirmedAllergens = Array(llmConfirmed.union(explicitLocalAllergens).union(dbAllergens)).sorted()

            // Suggested allergens from inferred ingredients (LLM + local scan)
            let inferredText = gd.inferredIngredients.joined(separator: " ").lowercased()
            let inferredLocalAllergens = Self.detectAllergensLocally(in: inferredText)
            let llmSuggested = Set(gd.suggestedAllergenIds.filter { Self.validAllergenIds.contains($0) })
            let suggestedAllergens = Array(
                llmSuggested.union(inferredLocalAllergens).subtracting(confirmedAllergens)
            ).sorted()

            return Dish(
                name: finalName,
                englishName: englishName,
                description: gd.dishDescription.isEmpty ? nil : gd.dishDescription,
                price: nil,
                category: nil,
                ingredients: gd.ingredients,
                allergenIds: confirmedAllergens,
                inferredIngredients: gd.inferredIngredients,
                suggestedAllergenIds: suggestedAllergens
            )
        }

        // Anti-hallucination: only keep dishes whose name exists in the original OCR
        let restaurantNorm = generated.restaurant.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let ocrValidated = candidateDishes.filter { dish in
            let dishNorm = dish.name.lowercased()
                .folding(options: .diacriticInsensitive, locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Exclude if the dish name is basically the restaurant name
            if !restaurantNorm.isEmpty && restaurantNorm != "unknown"
                && (dishNorm == restaurantNorm
                    || restaurantNorm.contains(dishNorm)
                    || dishNorm.contains(restaurantNorm)) {
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

        let matchCount = significantWords.filter { normalizedOCR.contains($0) }.count

        if significantWords.count <= 2 {
            return matchCount == significantWords.count
        }
        return matchCount >= (significantWords.count * 2 + 2) / 3
    }

    private static let ocrStopWords: Set<String> = [
        "di", "al", "alla", "alle", "allo", "agli", "del", "della", "delle", "dello", "dei",
        "con", "fra", "tra", "per", "sul", "sulla", "sulle",
        "de", "la", "el", "los", "las", "un", "una", "por", "para", "sin",
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
            // Italian section categories
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
            // Spanish section categories
            "entrantes", "entradas", "sopas", "ensaladas", "platos fuertes",
            "platos principales", "postres", "bebidas", "aperitivos",
            "antojitos", "tacos", "quesadillas", "volcanes",
            "especialidades", "para compartir", "para empezar",
            "extras", "acompañamientos", "guarniciones",
            "aguas", "refrescos", "cervezas", "vinos", "cocktails", "cócteles",
            // English section categories
            "appetizers", "starters", "soups", "salads", "main courses",
            "main dishes", "sides", "side dishes", "drinks", "beverages",
            "wines", "cocktails", "beers", "spirits",
            "small plates", "large plates", "shareable", "shareables",
            "flight bites", "atmospheric spirits", "crew brews",
            "worldly wines", "zero-proof cocktails",
            // French section categories
            "entrées", "plats", "hors d'oeuvres", "boissons",
            "nos apéritifs", "nos bières", "les eaux", "les softs",
            "nos producteurs", "les planches apéro",
            "fromage et desserts", "fromages", "formules",
            // Turkish section categories
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

        // All non-letter characters → noise
        let nonSpace = name.filter { !$0.isWhitespace }
        let nonAlpha = nonSpace.filter { !$0.isLetter }
        if !nonSpace.isEmpty && nonAlpha.count == nonSpace.count { return true }

        // Single word shorter than 4 characters (usually noise)
        let words = name.split(separator: " ")
        if words.count == 1 && lower.count < 4 { return true }

        // Too many digits (phone number / tracking code)
        let digits = name.filter { $0.isNumber }
        if digits.count > 5 { return true }

        // Looks like a phone number or code
        if lower.hasPrefix("+") || lower.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" || $0 == "+" }) {
            return true
        }

        // Low letter ratio → mostly symbols
        let letters = name.filter { $0.isLetter }
        let totalChars = name.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        if !totalChars.isEmpty && letters.count < totalChars.count / 2 { return true }

        // Consonant cluster check (likely OCR noise)
        if letters.count >= 3 {
            let vowels: Set<Character> = ["a","e","i","o","u","á","é","í","ó","ú","à","è","ì","ò","ù","ä","ö","ü","â","ê","î","ô","û"]
            let vowelCount = letters.lowercased().filter { vowels.contains($0) }.count
            if vowelCount == 0 { return true }

            var maxRun = 0; var run = 0
            for ch in letters.lowercased() {
                if vowels.contains(ch) { run = 0 } else { run += 1; maxRun = max(maxRun, run) }
            }
            if maxRun >= 5 { return true }
        }

        return false
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

    // MARK: - Local Allergen Detection (safety net — English-optimized)

    private static func detectAllergensLocally(in text: String) -> Set<String> {
        var found: Set<String> = []
        let words = Set(
            text.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .map { $0.lowercased() }
                .filter { !$0.isEmpty }
        )
        for (allergenId, keywords) in allergenKeywordMap {
            for keyword in keywords {
                let matched = keyword.contains(" ")
                    ? text.contains(keyword)
                    : words.contains(keyword)
                if matched { found.insert(allergenId); break }
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
            "tacchino", "anatra", "oca", "quaglia"
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
