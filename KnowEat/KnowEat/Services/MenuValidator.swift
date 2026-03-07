//
//  MenuValidator.swift
//  KnowEat
//

import Foundation

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

enum MenuValidator {

    private static let priceRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"[\$€£¥]\s*\d+[.,]?\d{0,2}|\d+[.,]\d{2}\s*[\$€£¥]|\d+[.,]\d{2}"#
        )
    }()

    static func validate(_ ocrText: String) throws {
        let lines = ocrText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 || lines.count < 2 {
            throw MenuValidationError.tooLittleText
        }

        if looksLikeProductLabel(ocrText) {
            throw MenuValidationError.productLabel
        }

        if looksLikeBeverageLabel(ocrText) {
            throw MenuValidationError.productLabel
        }

        if looksLikeIngredientList(ocrText, lines: lines) {
            throw MenuValidationError.productLabel
        }

        if looksLikeScreenshot(ocrText) {
            throw MenuValidationError.notAMenu
        }

        if looksLikeReceipt(ocrText) {
            throw MenuValidationError.notAMenu
        }

        if !hasMenuEvidence(ocrText, lines: lines) {
            throw MenuValidationError.notAMenu
        }
    }

    // MARK: - Product Label Detection

    private static func looksLikeProductLabel(_ text: String) -> Bool {
        let lower = text.lowercased()

        let labelIndicators = [
            "nutrition facts", "nutritional information", "información nutricional",
            "informazioni nutrizionali", "valori nutrizionali", "valeurs nutritionnelles",
            "serving size", "tamaño de porción", "porzione",
            "calories per serving", "calorías por porción",
            "daily value", "valor diario", "valore giornaliero",
            "total fat", "grasa total", "grassi totali",
            "total carbohydrate", "carbohidratos totales",
            "net weight", "peso neto", "peso netto", "net wt",
            "manufactured by", "fabricado por", "prodotto da",
            "best before", "consumir preferentemente", "da consumarsi",
            "storage instructions", "conservar en", "conservare",
            "ingredients:", "ingredientes:", "ingredienti:",
            "contains:", "may contain", "produced in a facility",
            "contiene:", "puede contener", "può contenere",
            "allergen information", "información sobre alérgenos",
            "use by", "sell by", "exp date", "lot number", "batch",
            "distributed by", "distribuido por", "importado por",
            "keep refrigerated", "mantener refrigerado", "conservare in frigo",
        ]

        let matchCount = labelIndicators.filter { lower.contains($0) }.count
        return matchCount >= 2
    }

    // MARK: - Beverage / Bottle Label Detection

    private static func looksLikeBeverageLabel(_ text: String) -> Bool {
        let lower = text.lowercased()

        let bottleIndicators = [
            "abv", "alc.", "alcohol by volume", "vol.", "% vol",
            "grape variety", "variedad de uva", "vitigno",
            "vintage", "cosecha", "vendemmia", "annata",
            "aged in", "envejecido en", "invecchiato in",
            "denomination of origin", "denominación de origen", "denominazione di origine",
            "d.o.", "d.o.c.", "d.o.c.g.", "i.g.t.", "i.g.p.",
            "winery", "bodega", "cantina", "vineyard", "viñedo", "vigneto",
            "distilled", "destilado", "distillato",
            "barrel aged", "single malt", "blended",
            "brewed by", "cervecería", "birrificio", "brewery",
            "hops", "lúpulo", "luppolo", "ibu",
            "tasting notes", "notas de cata", "note di degustazione",
            "750 ml", "500 ml", "330 ml", "375 ml", "1.5 l",
            "serve chilled", "servir frío", "servire freddo",
            "sulfites", "contains sulfites", "contiene solfiti",
        ]

        let matchCount = bottleIndicators.filter { lower.contains($0) }.count
        return matchCount >= 2
    }

    // MARK: - Ingredient List Detection (cereal boxes, packaged food)

    private static func looksLikeIngredientList(_ text: String, lines: [String]) -> Bool {
        let lower = text.lowercased()

        let hasIngredientHeader = ["ingredients:", "ingredientes:", "ingredienti:",
                                   "composition:", "composición:", "composizione:"]
            .contains(where: { lower.contains($0) })

        guard hasIngredientHeader else { return false }

        let packagingIndicators = [
            "per 100g", "per serving", "por porción", "per porzione",
            "energy", "kcal", "kj", "protein", "proteína", "proteine",
            "carbohydrate", "carbohidrato", "carboidrat",
            "fiber", "fibra", "sodium", "sodio",
            "vitamin", "vitamina", "iron", "hierro", "ferro",
            "calcium", "calcio", "potassium", "potasio",
            "% daily", "% valor diario",
            "emulsifier", "emulsionante", "stabilizer", "estabilizante",
            "preservative", "conservante", "artificial",
            "e100", "e101", "e102", "e110", "e120", "e150", "e160",
            "e200", "e202", "e211", "e220", "e250", "e270", "e300",
            "e322", "e330", "e400", "e410", "e412", "e415", "e440",
            "e471", "e500", "e621",
        ]

        let packagingHits = packagingIndicators.filter { lower.contains($0) }.count

        let commaHeavyLines = lines.filter { line in
            let commas = line.filter { $0 == "," }.count
            return commas >= 4
        }.count

        return packagingHits >= 1 || commaHeavyLines >= 2
    }

    // MARK: - Screenshot Detection

    private static func looksLikeScreenshot(_ text: String) -> Bool {
        let lower = text.lowercased()

        let screenshotIndicators = [
            "screenshot", "captura de pantalla", "schermata",
            "battery", "batería", "batteria",
            "wi-fi", "wifi", "signal", "airplane mode",
            "notifications", "notificaciones", "notifiche",
            "settings", "configuración", "impostazioni",
            "home screen", "pantalla de inicio",
            "search bar", "barra de búsqueda",
            "app store", "play store", "google play",
            "whatsapp", "telegram", "messenger",
            "uber eats", "doordash", "grubhub", "deliveroo", "just eat",
            "rappi", "didi food", "glovo",
            "add to cart", "añadir al carrito", "aggiungi al carrello",
            "checkout", "pagar", "order now", "ordenar ahora",
            "your order", "tu pedido", "il tuo ordine",
            "delivery fee", "costo de envío", "spese di consegna",
            "rated", "reviews", "reseñas", "recensioni",
            "open now", "abierto ahora", "aperto ora",
            "see menu", "ver menú", "vedi menu",
        ]

        let matchCount = screenshotIndicators.filter { lower.contains($0) }.count

        if matchCount >= 2 { return true }

        let deliveryAppIndicators = [
            "add to cart", "añadir al carrito", "aggiungi al carrello",
            "delivery fee", "costo de envío",
            "your order", "tu pedido",
            "min order", "pedido mínimo",
        ]
        let isDeliveryApp = deliveryAppIndicators.filter { lower.contains($0) }.count >= 1
            && lower.contains("$") || lower.contains("€")

        return isDeliveryApp
    }

    // MARK: - Receipt Detection

    private static func looksLikeReceipt(_ text: String) -> Bool {
        let lower = text.lowercased()

        let receiptIndicators = [
            "subtotal", "total:", "tax", "change", "receipt",
            "invoice", "payment", "credit card", "debit card",
            "recibo", "factura", "cambio", "efectivo", "tarjeta",
            "scontrino", "ricevuta", "totale:", "resto", "contanti",
            "ticket", "caja", "cajero",
            "transaction", "transacción", "transazione",
            "amount due", "monto a pagar", "importo dovuto",
            "tip", "propina", "mancia",
            "order #", "pedido #", "ordine #",
        ]

        return receiptIndicators.filter({ lower.contains($0) }).count >= 2
    }

    // MARK: - Positive Menu Evidence

    private static func hasMenuEvidence(_ text: String, lines: [String]) -> Bool {
        let lower = text.lowercased()

        let priceCount = priceRegex.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )

        let menuKeywords = [
            "menu", "menú", "menù", "carta", "appetizer", "appetizers",
            "entrée", "entree", "main course", "dessert", "desserts",
            "drinks", "beverages", "starters", "sides",
            "antipasti", "antipasto", "primi", "secondi", "contorni", "dolci", "bevande",
            "entrantes", "postres", "bebidas", "ensaladas", "carnes", "mariscos",
            "platos fuertes", "plato del día", "especialidades",
            "hors d'oeuvres", "entrées", "plats", "boissons",
        ]
        let hasMenuKeyword = menuKeywords.contains(where: { lower.contains($0) })

        let foodKeywords = [
            "chicken", "beef", "pork", "fish", "salmon", "shrimp", "lamb",
            "pasta", "rice", "bread", "salad", "soup", "pizza", "sushi",
            "burger", "sandwich", "steak", "fries", "sauce", "cheese",
            "grilled", "fried", "baked", "roasted",
            "pollo", "carne", "cerdo", "pescado", "arroz", "ensalada",
            "sopa", "hamburguesa", "tacos", "queso", "frijoles",
            "asado", "frito", "al horno",
            "vitello", "manzo", "maiale", "insalata", "zuppa", "riso",
            "formaggio", "prosciutto", "mozzarella", "risotto",
            "poisson", "poulet", "boeuf", "salade", "soupe", "fromage",
        ]
        let foodCount = foodKeywords.filter { lower.contains($0) }.count

        let linesWithPrices = lines.filter { line in
            let range = NSRange(line.startIndex..., in: line)
            return priceRegex.firstMatch(in: line, range: range) != nil
        }.count

        let hasStructuralEvidence = linesWithPrices >= 3 && foodCount >= 1

        if hasStructuralEvidence { return true }
        if priceCount >= 5 { return true }
        if hasMenuKeyword && foodCount >= 2 { return true }
        if linesWithPrices >= 2 && foodCount >= 2 { return true }
        if foodCount >= 4 { return true }
        if priceCount >= 2 && hasMenuKeyword && foodCount >= 1 { return true }

        return false
    }
}
