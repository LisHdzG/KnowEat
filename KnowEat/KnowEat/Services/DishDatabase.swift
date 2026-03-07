//
//  DishDatabase.swift
//  KnowEat
//

import Foundation

final class DishDatabase {
    static let shared = DishDatabase()

    private var entries: [DishEntry] = []

    private struct DishEntry: Decodable {
        let names: [String]
        let ingredients: [String]
        let allergens: [String]
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "common_dishes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DishEntry].self, from: data)
        else { return }
        entries = decoded
    }

    func allergens(forDishNamed name: String) -> Set<String> {
        guard let entry = findEntry(for: name) else { return [] }
        return Set(entry.allergens)
    }

    func knownIngredients(forDishNamed name: String) -> [String] {
        guard let entry = findEntry(for: name) else { return [] }
        return entry.ingredients
    }

    func isKnownDish(_ name: String) -> Bool {
        findEntry(for: name) != nil
    }

    struct AllergenValidation {
        let confirmed: [String]
        let suggested: [String]
    }

    func validateAllergens(dishName: String, llmAllergens: [String]) -> AllergenValidation {
        guard let entry = findEntry(for: dishName) else {
            return AllergenValidation(confirmed: [], suggested: llmAllergens)
        }

        let dbAllergens = Set(entry.allergens)
        let llmSet = Set(llmAllergens)

        let confirmed = Array(llmSet.intersection(dbAllergens)).sorted()
        let suggested = Array(llmSet.subtracting(dbAllergens)).sorted()

        return AllergenValidation(confirmed: confirmed, suggested: suggested)
    }

    // MARK: - Matching

    private func findEntry(for name: String) -> DishEntry? {
        let normalized = normalize(name)

        for entry in entries {
            if entry.names.contains(where: { normalize($0) == normalized }) {
                return entry
            }
        }

        for entry in entries {
            if entry.names.contains(where: { normalized.contains(normalize($0)) && normalize($0).count >= 4 }) {
                return entry
            }
        }

        for entry in entries {
            if entry.names.contains(where: { normalize($0).contains(normalized) && normalized.count >= 4 }) {
                return entry
            }
        }

        for entry in entries {
            if entry.names.contains(where: { fuzzyMatch(normalize($0), normalized) }) {
                return entry
            }
        }

        return nil
    }

    private func fuzzyMatch(_ a: String, _ b: String) -> Bool {
        guard a.count >= 4 && b.count >= 4 else { return false }

        let shorter = a.count <= b.count ? a : b
        let longer = a.count > b.count ? a : b

        guard shorter.count >= 4 else { return false }

        let distance = levenshteinDistance(shorter, longer)
        let threshold = max(1, shorter.count / 4)
        return distance <= threshold
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,
                    curr[j - 1] + 1,
                    prev[j - 1] + cost
                )
            }
            prev = curr
        }

        return prev[n]
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
