//
//  MenuValidator.swift
//  KnowEat
//

import Foundation
import NaturalLanguage

enum MenuValidationError: LocalizedError {
    case notAMenu
    case productLabel
    case tooLittleText

    var errorDescription: String? {
        switch self {
        case .notAMenu:
            return "This doesn't appear to be a restaurant menu. Please photograph a food menu with dish names."
        case .productLabel:
            return "This looks like a product label, not a restaurant menu. Please photograph a food menu instead."
        case .tooLittleText:
            return "Not enough text was detected. Please take a clearer photo of the full menu."
        }
    }
}

// MARK: - MenuValidator

enum MenuValidator {

    private static let scoreThreshold = 70
    private static let yAxisTolerance: Double = 0.03

    // MARK: - Public API

    static func validate(_ ocrText: String, regions: [TextRegion]) throws {
        let lines = ocrText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).count < 15 || lines.count < 2 {
            throw MenuValidationError.tooLittleText
        }

        if let rejection = hardReject(ocrText) {
            throw rejection
        }

        let score = computeScore(text: ocrText, regions: regions)
        if score < scoreThreshold {
            throw MenuValidationError.notAMenu
        }
    }

    // MARK: - Scoring Engine

    private static func computeScore(text: String, regions: [TextRegion]) -> Int {
        let s1 = tabularStructureScore(regions)
        let s2 = priceDensityScore(regions)
        let s3 = dictionaryMatchScore(text)
        let s4 = nlpAnalysisScore(text)
        let penalty = receiptPenalty(text, regions)
        return max(0, s1 + s2 + s3 + s4 + penalty)
    }

    // MARK: - Step 2A · Tabular Structure (+40 max)
    // Text on the left sharing the same Y-axis with a price on the right (or immediately below).

    private static func tabularStructureScore(_ regions: [TextRegion]) -> Int {
        let byImage = Dictionary(grouping: regions, by: \.imageIndex)
        var pairCount = 0

        for (_, group) in byImage {
            let prices = group.filter { isPriceRegion($0.text) }
            let descriptions = group.filter { !isPriceRegion($0.text) && $0.text.count > 3 }

            for price in prices {
                let priceCenterY = price.y + price.height / 2.0

                for desc in descriptions {
                    let descCenterY = desc.y + desc.height / 2.0

                    let sameRow = abs(priceCenterY - descCenterY) < yAxisTolerance
                    let priceToTheRight = price.x > desc.x

                    let priceDirectlyBelow = price.y < desc.y
                        && (desc.y - (price.y + price.height)) < yAxisTolerance * 2
                        && abs(price.x - desc.x) < 0.20

                    if (sameRow && priceToTheRight) || priceDirectlyBelow {
                        pairCount += 1
                        break
                    }
                }
            }
        }

        if pairCount >= 4 { return 40 }
        if pairCount >= 3 { return 35 }
        if pairCount >= 2 { return 25 }
        if pairCount >= 1 { return 15 }
        return 0
    }

    // MARK: - Step 2B · Price / Currency Density (+30 max)
    // High concentration of numbers and currency symbols at the edges of bounding boxes.

    private static func priceDensityScore(_ regions: [TextRegion]) -> Int {
        guard !regions.isEmpty else { return 0 }

        let withPrice = regions.filter { containsPrice($0.text) }
        let ratio = Double(withPrice.count) / Double(regions.count)

        let atRightEdge = withPrice.filter { ($0.x + $0.width) > 0.55 }
        let edgeRatio = Double(atRightEdge.count) / Double(regions.count)

        if ratio > 0.15 && edgeRatio > 0.08 { return 30 }
        if ratio > 0.12 { return 25 }
        if ratio > 0.08 { return 20 }
        if ratio > 0.04 { return 10 }
        return 0
    }

    // MARK: - Step 4 · Multilingual Dictionary Match (+20 max)
    // O(1) intersection of OCR words against an embedded Set of ~250 food/menu keywords.

    private static func dictionaryMatchScore(_ text: String) -> Int {
        let normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)

        let matchCount = menuKeywords.filter { normalized.contains($0) }.count

        if matchCount >= 5 { return 20 }
        if matchCount >= 3 { return 15 }
        if matchCount >= 2 { return 10 }
        if matchCount >= 1 { return 5 }
        return 0
    }

    // MARK: - Step 3 · NLP Analysis (+10 max)
    // Noun/adjective density via NLTagger + mixed-language detection via NLLanguageRecognizer.

    private static func nlpAnalysisScore(_ text: String) -> Int {
        var points = 0

        // --- Lexical class analysis (NLTagger) ---
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var nouns = 0
        var verbs = 0
        var totalWords = 0

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, _ in
            totalWords += 1
            if tag == .noun { nouns += 1 }
            else if tag == .verb { verbs += 1 }
            return true
        }

        if totalWords > 0 {
            let nounRatio = Double(nouns) / Double(totalWords)
            let verbRatio = Double(verbs) / Double(totalWords)

            if nounRatio > 0.40 && verbRatio < 0.10 { points += 7 }
            else if nounRatio > 0.30 && verbRatio < 0.15 { points += 5 }
            else if nounRatio > 0.25 && verbRatio < 0.20 { points += 3 }
        }

        // --- Mixed-language heuristic (NLLanguageRecognizer) ---
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
        let significantLanguages = hypotheses.filter { $0.value > 0.1 }.count
        if significantLanguages >= 2 {
            points += 3
        }

        return min(points, 10)
    }

    // MARK: - Step 5 · Receipt / Invoice Penalty (-50 max)
    // Keywords concentrated at the bottom of the document penalize the score.

    private static let receiptKeywords: Set<String> = [
        // EN
        "tax", "total:", "subtotal", "invoice", "receipt",
        "payment method", "credit card", "debit card", "change due",
        "visa", "mastercard", "amex", "american express",
        "gratuity", "tip included", "card ending", "amount due",
        // ES
        "iva", "factura", "recibo", "impuesto", "pago con tarjeta",
        "propina incluida", "metodo de pago",
        // IT
        "scontrino", "ricevuta", "pagamento", "carta di credito",
        "mancia", "importo dovuto",
        // FR
        "recu", "paiement", "tva", "carte bancaire",
        "pourboire", "montant du",
        // DE
        "rechnung", "quittung", "zahlung", "trinkgeld",
        // General
        "transaction", "transaccion", "transazione",
    ]

    private static func receiptPenalty(_ text: String, _ regions: [TextRegion]) -> Int {
        let lower = text.lowercased()

        // Vision coords: Y=0 bottom, Y=1 top → bottom 35% of page
        let bottomRegions = regions.filter { $0.y < 0.35 }
        let bottomText = bottomRegions.map { $0.text.lowercased() }.joined(separator: " ")

        let bottomHits = receiptKeywords.filter { bottomText.contains($0) }.count
        let totalHits = receiptKeywords.filter { lower.contains($0) }.count

        if bottomHits >= 3 { return -50 }
        if bottomHits >= 2 && totalHits >= 4 { return -40 }
        if totalHits >= 5 { return -30 }
        return 0
    }

    // MARK: - Hard Rejections (non-menu documents)

    private static func hardReject(_ text: String) -> MenuValidationError? {
        let lower = text.lowercased()

        // Nutrition / product labels
        let labelIndicators = [
            "nutrition facts", "nutritional information", "informacion nutricional",
            "informazioni nutrizionali", "valori nutrizionali", "valeurs nutritionnelles",
            "serving size", "tamano de porcion",
            "calories per serving", "calorias por porcion",
            "daily value", "valor diario", "valore giornaliero",
            "total fat", "grasa total", "grassi totali",
            "total carbohydrate", "carbohidratos totales",
            "net weight", "peso neto", "peso netto", "net wt",
            "manufactured by", "fabricado por", "prodotto da",
            "best before", "consumir preferentemente", "da consumarsi",
            "storage instructions", "conservar en",
            "use by", "sell by", "exp date", "lot number",
            "distributed by", "distribuido por",
            "keep refrigerated", "mantener refrigerado",
        ]
        if labelIndicators.filter({ lower.contains($0) }).count >= 3 {
            return .productLabel
        }

        // "Ingredients:" header + packaging indicators
        let hasIngredientHeader = [
            "ingredients:", "ingredientes:", "ingredienti:",
            "composition:", "composicion:", "composizione:",
        ].contains { lower.contains($0) }

        if hasIngredientHeader {
            let packaging = [
                "per 100g", "per serving", "por porcion", "per porzione",
                "kcal", "kj", "protein", "proteina", "proteine",
                "carbohydrate", "carbohidrato", "carboidrat",
                "fiber", "fibra", "sodium", "sodio",
                "vitamin", "vitamina",
                "emulsifier", "stabilizer", "preservative", "conservante",
            ]
            if packaging.filter({ lower.contains($0) }).count >= 2 {
                return .productLabel
            }
        }

        // Bottle / wine labels
        let bottleIndicators = [
            "alcohol by volume", "% vol",
            "grape variety", "variedad de uva", "vitigno",
            "denomination of origin", "denominacion de origen", "denominazione di origine",
            "d.o.c.g.", "i.g.t.", "i.g.p.",
            "winery", "bodega", "cantina",
            "distilled", "destilado", "distillato",
            "barrel aged", "single malt",
            "brewed by", "birrificio", "brewery",
            "tasting notes", "notas de cata", "note di degustazione",
        ]
        if bottleIndicators.filter({ lower.contains($0) }).count >= 3 {
            return .productLabel
        }

        // Delivery apps
        let deliveryIndicators = [
            "add to cart", "anadir al carrito", "aggiungi al carrello",
            "checkout", "order now", "ordenar ahora",
            "your order", "tu pedido", "il tuo ordine",
            "delivery fee", "costo de envio", "spese di consegna",
            "min order", "pedido minimo",
        ]
        if deliveryIndicators.filter({ lower.contains($0) }).count >= 2 {
            return .productLabel
        }

        return nil
    }

    // MARK: - Price Detection Helpers

    private static let pricePattern: NSRegularExpression = {
        // Matches: $12.50 | €15,00 | 12.50€ | 12.50 | 1,500.00 | ₩15,000
        try! NSRegularExpression(
            pattern: #"[\$€£¥₺₱₩₹฿₫₴]\s*\d{1,3}([.,]\d{3})*[.,]?\d{0,2}|\d{1,3}([.,]\d{3})*[.,]\d{2}\s*[\$€£¥₺₱₩₹฿₫₴]?|\d+[.,]\d{2}"#
        )
    }()

    private static let phoneDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
    }()

    private static func containsPrice(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return pricePattern.firstMatch(in: text, range: range) != nil
    }

    /// A region whose primary content is a price (short text dominated by a numeric/currency pattern).
    /// Uses NSDataDetector to exclude phone numbers that resemble prices.
    private static func isPriceRegion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 15 else { return false }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard pricePattern.firstMatch(in: trimmed, range: range) != nil else { return false }

        if let detector = phoneDetector,
           detector.firstMatch(in: trimmed, range: range) != nil {
            return false
        }
        return true
    }

    // MARK: - Multilingual Menu Keywords (~250 terms, 15 languages)

    private static let menuKeywords: Set<String> = {
        let raw: [String] = [
            // ── Structure: EN ──
            "appetizer", "starter", "entree",
            "main course", "side dish",
            "dessert", "beverage", "specials", "daily special",
            "prix fixe", "tasting menu", "a la carte", "happy hour",

            // ── Structure: ES ──
            "entrante", "aperitivo",
            "plato principal", "acompanamiento",
            "postre", "bebida", "especialidad", "del dia", "carta",

            // ── Structure: FR ──
            "plat principal", "garniture", "boisson",
            "specialite", "du jour", "formule",

            // ── Structure: IT ──
            "antipasto", "antipasti", "primo", "primi piatti",
            "secondo", "secondi", "contorno", "contorni",
            "dolce", "dolci", "specialita", "del giorno", "piatto",

            // ── Structure: DE ──
            "vorspeise", "hauptgericht", "beilage", "nachspeise",
            "getranke", "tagesangebot", "speisekarte",

            // ── Structure: PT ──
            "entrada", "prato principal", "acompanhamento",
            "sobremesa", "cardapio",

            // ── Structure: JA ──
            "メニュー", "前菜", "メイン", "デザート", "ドリンク",
            "一品料理", "セット", "おすすめ",

            // ── Structure: KO ──
            "메뉴", "전채", "메인요리", "디저트", "음료", "밑반찬", "추천",

            // ── Structure: ZH ──
            "菜单", "菜單", "主菜", "甜点", "饮料", "凉菜", "热菜", "招牌菜",

            // ── Structure: TH ──
            "เมนู", "อาหารเรียกน้ำย่อย", "ของหวาน", "เครื่องดื่ม",

            // ── Structure: AR ──
            "مقبلات", "الطبق الرئيسي", "حلويات", "مشروبات", "قائمة الطعام",

            // ── Structure: TR ──
            "baslangic", "ana yemek", "tatli", "icecek", "menu",

            // ── Structure: NL ──
            "voorgerecht", "hoofdgerecht", "nagerecht", "bijgerecht",

            // ── Structure: RU ──
            "закуска", "закуски", "горячее", "напиток", "меню",

            // ── Universal food types ──
            "soup", "salad", "pasta", "pizza", "sushi", "sashimi",
            "burger", "steak", "sandwich", "taco", "burrito",
            "risotto", "curry", "kebab", "falafel", "hummus",
            "paella", "ramen", "tempura", "wonton",

            // ── Soups & salads (multilingual) ──
            "sopa", "ensalada", "soupe", "salade",
            "zuppa", "insalata", "suppe", "salat",

            // ── Italian dishes ──
            "margherita", "carbonara", "bolognese", "pesto",
            "bruschetta", "carpaccio", "caprese", "prosciutto",
            "gnocchi", "lasagna", "fettuccine", "penne", "ravioli",
            "tortellini", "tiramisu", "panna cotta", "gelato",

            // ── Japanese dishes ──
            "maki", "nigiri", "edamame", "gyoza", "udon",
            "yakitori", "teriyaki", "tonkatsu",
            "okonomiyaki", "takoyaki", "katsu",

            // ── Thai dishes ──
            "pad thai", "tom yum", "satay",
            "som tam", "tom kha", "massaman", "panang",

            // ── Indian dishes ──
            "biryani", "tikka masala", "naan", "samosa", "tandoori",
            "paneer", "masala", "vindaloo", "korma", "dosa",

            // ── Mexican dishes ──
            "quesadilla", "enchilada", "guacamole", "nachos", "churros",
            "tamale", "pozole", "elote",

            // ── Spanish dishes ──
            "gazpacho", "ceviche", "empanada",
            "tapas", "pintxos", "croqueta", "jamon",
            "patatas bravas", "chorizo",

            // ── French dishes ──
            "creme brulee", "croissant", "quiche", "ratatouille", "crepe",

            // ── Middle Eastern dishes ──
            "couscous", "tagine", "shawarma",
            "fattoush", "tabbouleh", "baba ganoush", "kibbeh",

            // ── Korean dishes ──
            "bibimbap", "kimchi", "bulgogi",
            "japchae", "tteokbokki", "sundubu",

            // ── Turkish dishes ──
            "baklava", "borek", "doner",
            "kofte", "pide", "lahmacun", "manti",

            // ── Vietnamese dishes ──
            "banh mi",

            // ── Greek dishes ──
            "moussaka", "souvlaki", "tzatziki", "gyro",

            // ── Cooking methods: EN ──
            "grilled", "fried", "baked", "roasted", "steamed",
            "sauteed", "braised", "smoked", "marinated",

            // ── Cooking methods: ES ──
            "a la plancha", "frito", "al horno", "asado", "al vapor",

            // ── Cooking methods: IT ──
            "alla griglia", "fritto", "al forno", "arrosto",

            // ── Cooking methods: FR ──
            "grille", "au four", "roti",

            // ── Specialty ingredients ──
            "mozzarella", "parmesan", "parmigiano", "gorgonzola",
            "burrata", "ricotta", "truffle", "foie gras",

            // ── Drinks section indicators ──
            "cocktail", "mocktail", "smoothie",
            "espresso", "cappuccino",
            "wine list", "carta de vinos", "lista dei vini",
        ]

        return Set(raw.map {
            $0.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        })
    }()
}
