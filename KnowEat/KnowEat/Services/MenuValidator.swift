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
            pattern: #"[\$€£¥₺₱₩]\s*\d+[.,]?\d{0,2}|\d+[.,]\d{2}\s*[\$€£¥₺₱₩]|\d+[.,]\d{2}"#
        )
    }()

    private static let integerPriceRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"\b\d{2,4}\b"#
        )
    }()

    static func validate(_ ocrText: String) throws {
        let lines = ocrText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).count < 15 || lines.count < 2 {
            throw MenuValidationError.tooLittleText
        }

        if isDefinitelyNotMenu(ocrText, lines: lines) {
            throw MenuValidationError.productLabel
        }
    }

    // MARK: - Negative-only validation

    private static func isDefinitelyNotMenu(_ text: String, lines: [String]) -> Bool {
        let lower = text.lowercased()

        let labelIndicators = [
            "nutrition facts", "nutritional information", "información nutricional",
            "informazioni nutrizionali", "valori nutrizionali", "valeurs nutritionnelles",
            "serving size", "tamaño de porción",
            "calories per serving", "calorías por porción",
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
        let labelHits = labelIndicators.filter { lower.contains($0) }.count
        if labelHits >= 3 { return true }

        let hasIngredientHeader = ["ingredients:", "ingredientes:", "ingredienti:",
                                   "composition:", "composición:", "composizione:"]
            .contains(where: { lower.contains($0) })
        if hasIngredientHeader {
            let packagingIndicators = [
                "per 100g", "per serving", "por porción", "per porzione",
                "kcal", "kj", "protein", "proteína", "proteine",
                "carbohydrate", "carbohidrato", "carboidrat",
                "fiber", "fibra", "sodium", "sodio",
                "vitamin", "vitamina",
                "emulsifier", "stabilizer", "preservative", "conservante",
            ]
            let packagingHits = packagingIndicators.filter { lower.contains($0) }.count
            if packagingHits >= 2 { return true }
        }

        let bottleIndicators = [
            "alcohol by volume", "% vol",
            "grape variety", "variedad de uva", "vitigno",
            "denomination of origin", "denominación de origen", "denominazione di origine",
            "d.o.c.g.", "i.g.t.", "i.g.p.",
            "winery", "bodega", "cantina",
            "distilled", "destilado", "distillato",
            "barrel aged", "single malt",
            "brewed by", "birrificio", "brewery",
            "tasting notes", "notas de cata", "note di degustazione",
        ]
        let bottleHits = bottleIndicators.filter { lower.contains($0) }.count
        if bottleHits >= 3 { return true }

        let deliveryAppIndicators = [
            "add to cart", "añadir al carrito", "aggiungi al carrello",
            "checkout", "order now", "ordenar ahora",
            "your order", "tu pedido", "il tuo ordine",
            "delivery fee", "costo de envío", "spese di consegna",
            "min order", "pedido mínimo",
        ]
        let deliveryHits = deliveryAppIndicators.filter { lower.contains($0) }.count
        if deliveryHits >= 2 { return true }

        let receiptIndicators = [
            "subtotal", "total:", "receipt",
            "invoice", "payment method", "credit card", "debit card",
            "recibo", "factura",
            "scontrino", "ricevuta",
            "transaction", "transacción", "transazione",
            "amount due", "monto a pagar", "importo dovuto",
        ]
        let receiptHits = receiptIndicators.filter { lower.contains($0) }.count
        if receiptHits >= 3 { return true }

        return false
    }
}
