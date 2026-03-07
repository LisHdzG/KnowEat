//
//  OfflineMenuAnalyzer.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

final class OfflineMenuAnalyzer {
    static let shared = OfflineMenuAnalyzer()

    private let priceRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"[\$€£]\s*\d+[.,]?\d{0,2}|\d+[.,]\d{2}\s*[\$€£]|\d+[.,]\d{2}\s*€?"#)
    }()

    func analyze(ocrText: String, userLanguage: String) -> ScannedMenu {
        let lines = ocrText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !isGarbageLine($0) }

        let rawEntries = extractDishEntries(from: lines)
        let dishes = rawEntries.map { buildDish(from: $0) }
        let restaurant = guessRestaurant(from: lines, dishEntries: rawEntries)

        return ScannedMenu(
            restaurant: restaurant,
            dishes: dishes,
            categoryIcon: "restaurant",
            menuLanguage: userLanguage
        )
    }

    // MARK: - Entry Extraction

    private struct RawEntry {
        var name: String
        var description: String?
        var price: String?
        var category: String?
    }

    private func extractDishEntries(from lines: [String]) -> [RawEntry] {
        var entries: [RawEntry] = []
        var currentCategory: String?
        var i = 0

        while i < lines.count {
            let line = lines[i]

            if looksLikeCategory(line, nextLine: i + 1 < lines.count ? lines[i + 1] : nil) {
                currentCategory = line
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .localizedCapitalized
                i += 1
                continue
            }

            if looksLikeDish(line) {
                var entry = RawEntry(name: extractName(from: line), category: currentCategory)
                entry.price = extractPrice(from: line)

                if i + 1 < lines.count, looksLikeDescription(lines[i + 1]) {
                    entry.description = lines[i + 1]
                    i += 1
                }

                entries.append(entry)
            }
            i += 1
        }

        return entries
    }

    private func buildDish(from entry: RawEntry) -> Dish {
        let textToAnalyze = [entry.name, entry.description ?? ""]
            .joined(separator: " ")
            .lowercased()

        let detectedAllergens = detectAllergens(in: textToAnalyze)
        let inferredIngredients = extractIngredientHints(from: textToAnalyze)

        let dbAllergens = DishDatabase.shared.allergens(forDishNamed: entry.name)
        let confirmedAllergens = Array(Set(detectedAllergens).union(dbAllergens)).sorted()

        let knownIngredients = DishDatabase.shared.knownIngredients(forDishNamed: entry.name)
        let knownText = knownIngredients.joined(separator: " ").lowercased()
        let suggestedFromKnown = detectAllergens(in: knownText)
        let suggested = Array(Set(suggestedFromKnown).subtracting(confirmedAllergens)).sorted()

        return Dish(
            name: entry.name,
            description: entry.description,
            price: nil,
            category: nil,
            ingredients: inferredIngredients,
            allergenIds: confirmedAllergens,
            suggestedAllergenIds: suggested
        )
    }

    // MARK: - Line Classification

    private func hasPrice(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return priceRegex.firstMatch(in: text, range: range) != nil
    }

    private func firstPriceMatch(in text: String) -> NSTextCheckingResult? {
        let range = NSRange(text.startIndex..., in: text)
        return priceRegex.firstMatch(in: text, range: range)
    }

    private func looksLikeCategory(_ line: String, nextLine: String?) -> Bool {
        let clean = line.replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)

        if clean.count > 30 || clean.count < 3 { return false }
        if hasPrice(clean) { return false }

        let isAllCaps = clean == clean.uppercased() && clean != clean.lowercased() && clean.count >= 3
        let knownCategories = [
            "appetizer", "starter", "entrée", "entree", "entrada", "antipasti", "antipasto",
            "main", "principal", "secondo", "secondi", "plato fuerte",
            "dessert", "postre", "dolci", "dolce",
            "drink", "beverage", "bebida", "bevande",
            "salad", "ensalada", "insalata",
            "soup", "sopa", "zuppa",
            "side", "acompañamiento", "contorno",
            "pizza", "pasta", "sandwich", "burger"
        ]
        let lower = clean.lowercased()
        let matchesKnown = knownCategories.contains { lower.contains($0) }

        return isAllCaps || matchesKnown
    }

    private func looksLikeDish(_ line: String) -> Bool {
        if line.count < 3 { return false }
        if looksLikeCategory(line, nextLine: nil) { return false }
        if isGarbageLine(line) { return false }

        let words = line.split(separator: " ")
        let wordCount = words.count

        if hasPrice(line) {
            let nameOnly = extractName(from: line)
            return !nameOnly.isEmpty && nameOnly.count >= 3 && !isGarbageLine(nameOnly)
        }

        if wordCount == 1 {
            let lower = line.lowercased()
            return Self.knownSingleWordDishes.contains(where: { lower.contains($0) })
        }

        return wordCount >= 2 && wordCount <= 12 && line.first?.isUppercase == true
    }

    private func isGarbageLine(_ line: String) -> Bool {
        let lower = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.count < 2 { return true }

        let garbagePatterns = [
            "google maps", "touchprint", "zte blade", "foto -",
            "fecha de la imagen", "protegidas por derechos",
            "las imágenes pueden", "copyright",
            "www.", ".com", ".it", ".es", "http",
            "facebook", "instagram", "tel:", "tel.",
            "con aggiunta", "ogni aggiunta", "variazione",
            "coperto", "servizio", "cover charge",
            "sala interna", "sala esterna", "asporto",
            "allergeni sono", "contiene glutine",
            "prezzi vari", "tutti i gusti", "n.b.",
            "via ", "p.iva", "c.f."
        ]
        if garbagePatterns.contains(where: { lower.contains($0) }) { return true }

        let junkExact: Set<String> = [
            "menù", "menu", "carta", "prezzario", "speciale",
            "classiche", "grande", "piccola", "media",
            "aggiunta", "note", "small", "medium", "large"
        ]
        if junkExact.contains(lower) { return true }

        if lower.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" || $0 == "+" || $0 == "." }) {
            return true
        }

        let digits = line.filter { $0.isNumber }
        if digits.count > 5 && !line.contains("€") && !line.contains("$") { return true }

        return false
    }

    private static let knownSingleWordDishes: Set<String> = [
        "lasagna", "carbonara", "tiramisù", "tiramisu", "bruschetta", "polenta",
        "risotto", "arancino", "arancini", "focaccia", "piadina", "calzone",
        "gnocchi", "ravioli", "tortellini", "cannelloni", "bresaola",
        "carpaccio", "prosciutto", "caprese", "minestrone", "ribollita",
        "ossobuco", "saltimbocca", "parmigiana", "crostini", "gazpacho",
        "paella", "churros", "empanada", "taco", "burrito", "quesadilla",
        "guacamole", "nachos", "enchilada", "falafel", "hummus", "kebab",
        "gyoza", "ramen", "sushi", "tempura", "edamame", "couscous",
        "croissant", "quiche", "ratatouille", "crêpe", "fondue",
        "hamburger", "cheeseburger", "hotdog", "hot-dog", "sandwich",
        "frittatina", "crocchè", "mozzarelline", "supplì"
    ]

    private func looksLikeDescription(_ line: String) -> Bool {
        if hasPrice(line) { return false }
        if looksLikeCategory(line, nextLine: nil) { return false }
        if isGarbageLine(line) { return false }
        let wordCount = line.split(separator: " ").count
        return (wordCount >= 3 && line.first?.isLowercase == true) || line.contains(",")
    }

    private func extractName(from line: String) -> String {
        var name = line
        if let match = firstPriceMatch(in: name),
           let range = Range(match.range, in: name) {
            name = String(name[name.startIndex..<range.lowerBound])
        }
        return name
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-–—…"))
            .trimmingCharacters(in: .whitespaces)
    }

    private func extractPrice(from line: String) -> String? {
        guard let match = firstPriceMatch(in: line),
              let range = Range(match.range, in: line) else { return nil }
        return String(line[range]).trimmingCharacters(in: .whitespaces)
    }

    private func guessRestaurant(from lines: [String], dishEntries: [RawEntry]) -> String {
        let dishNames = Set(dishEntries.map { $0.name.lowercased() })
        for line in lines.prefix(3) {
            let clean = line.trimmingCharacters(in: .whitespaces)
            if clean.count >= 3 && clean.count <= 40
                && !dishNames.contains(clean.lowercased())
                && !hasPrice(clean)
                && !looksLikeCategory(clean, nextLine: nil) {
                return clean
            }
        }
        return "Unknown"
    }


    // MARK: - Allergen Detection

    private static func wordSet(from text: String) -> Set<String> {
        Set(text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { !$0.isEmpty })
    }

    private static func matchesKeyword(_ keyword: String, words: Set<String>, fullText: String) -> Bool {
        if keyword.contains(" ") {
            return fullText.contains(keyword)
        }
        return words.contains(keyword)
    }

    private func detectAllergens(in text: String) -> [String] {
        let words = Self.wordSet(from: text)
        var found: [String] = []
        for (allergenId, keywords) in Self.allergenKeywords {
            if keywords.contains(where: { Self.matchesKeyword($0, words: words, fullText: text) }) {
                found.append(allergenId)
            }
        }
        return found
    }

    private func extractIngredientHints(from text: String) -> [String] {
        let words = Self.wordSet(from: text)
        var ingredients: [String] = []
        for (_, keywords) in Self.allergenKeywords {
            for keyword in keywords where Self.matchesKeyword(keyword, words: words, fullText: text) {
                let capitalized = keyword.prefix(1).uppercased() + keyword.dropFirst()
                if !ingredients.contains(capitalized) {
                    ingredients.append(capitalized)
                }
            }
        }
        return ingredients
    }

    // MARK: - Keyword Database

    private static let allergenKeywords: [String: [String]] = [
        "gluten": ["wheat", "flour", "bread", "pasta", "barley", "rye", "oat", "semolina", "couscous", "noodle", "dough", "pastry", "cracker", "trigo", "harina", "avena", "cebada", "centeno", "grano", "farina", "orzo", "segale"],
        "dairy": ["milk", "cheese", "cream", "butter", "yogurt", "mozzarella", "parmesan", "cheddar", "ricotta", "mascarpone", "brie", "feta", "whey", "ghee", "paneer", "leche", "queso", "mantequilla", "yogur", "nata", "formaggio", "panna"],
        "eggs": ["egg", "mayonnaise", "meringue", "aioli", "huevo", "mayonesa", "uovo", "uova", "maionese"],
        "fish": ["fish", "salmon", "tuna", "cod", "anchovy", "sardine", "bass", "trout", "halibut", "swordfish", "mackerel", "pescado", "salmón", "atún", "bacalao", "anchoa", "sardina", "trucha", "pesce", "tonno", "merluzzo", "acciuga"],
        "crustaceans": ["shrimp", "prawn", "crab", "lobster", "crawfish", "langoustine", "camarón", "gamba", "cangrejo", "langosta", "gambero", "granchio", "aragosta", "gambas"],
        "peanuts": ["peanut", "cacahuete", "maní", "arachide"],
        "soy": ["soy", "soja", "tofu", "edamame", "tempeh", "miso"],
        "tree_nuts": ["almond", "walnut", "cashew", "pistachio", "pecan", "hazelnut", "macadamia", "chestnut", "pine nut", "almendra", "nuez", "avellana", "castaña", "pistacho", "mandorla", "noce", "nocciola", "pistacchio", "castagna"],
        "celery": ["celery", "celeriac", "apio", "sedano"],
        "mustard": ["mustard", "mostaza", "senape"],
        "sesame": ["sesame", "tahini", "sésamo", "sesamo"],
        "sulfites": ["wine", "vinegar", "sulfite", "vino", "vinagre", "aceto"],
        "lupins": ["lupin", "lupini", "altramuz"],
        "mollusks": ["mussel", "clam", "oyster", "squid", "octopus", "scallop", "calamari", "snail", "mejillón", "almeja", "ostra", "calamar", "pulpo", "cozza", "vongola", "ostrica", "polpo", "capesante"],
        "lactose": ["milk", "cheese", "cream", "butter", "yogurt", "ice cream", "leche", "queso", "mantequilla", "yogur", "helado", "formaggio", "gelato"],
        "fructose": ["honey", "apple", "pear", "mango", "agave", "miel", "manzana"],
        "histamine": ["wine", "aged cheese", "fermented", "cured", "smoked", "vinegar", "vino", "ahumado", "curado", "fermentado", "affumicato", "stagionato"],
        "fodmap": ["garlic", "onion", "wheat", "apple", "ajo", "cebolla", "trigo", "manzana", "aglio", "cipolla"],
        "meat": ["beef", "steak", "veal", "lamb", "pork", "bacon", "sausage", "salami", "prosciutto", "bresaola", "chorizo", "pepperoni", "mortadella", "pancetta", "carne", "carne de res", "ternera", "cordero", "cerdo", "jamón", "tocino", "manzo", "vitello", "agnello", "maiale", "meatball", "burger", "ribs", "polpette", "bistecca"],
        "poultry": ["chicken", "turkey", "duck", "goose", "quail", "pollo", "pavo", "pato", "gallina", "tacchino", "anatra", "oca"],
        "pork": ["pork", "bacon", "sausage", "salami", "prosciutto", "pancetta", "chorizo", "pepperoni", "mortadella", "lard", "guanciale", "cerdo", "jamón", "tocino", "maiale", "lardo", "speck"],
        "alcohol": ["wine", "beer", "cocktail", "liquor", "rum", "vodka", "whisky", "tequila", "brandy", "champagne", "prosecco", "sangria", "vino", "cerveza", "birra", "liquore", "grappa", "amaro", "spritz"]
    ]
}
