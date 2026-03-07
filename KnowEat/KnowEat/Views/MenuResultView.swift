//
//  MenuResultView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct MenuResultView: View {
    let menu: ScannedMenu
    let analyzedDishes: [AnalyzedDish]
    let allergens: [Allergen]
    let filterGroups: [DietaryFilterGroup]
    var onSave: ((ScannedMenu) -> Void)? = nil
    var onDismiss: () -> Void = {}
    var isPushed: Bool = false

    @Environment(UserProfileStore.self) private var profileStore
    @Environment(MenuStore.self) private var menuStore
    @Environment(\.dismiss) private var dismiss
    @State private var showNamePrompt = false
    @State private var alertNameInput = ""
    @State private var searchText = ""
    @State private var showDisclaimer = true
    @State private var displayMenu: ScannedMenu?
    @State private var displayDishes: [AnalyzedDish]?
    @State private var showDietaryEditor = false
    @State private var currentFilterGroups: [DietaryFilterGroup]?

    private var strings: AppStrings {
        AppStrings(profileStore.profile?.nativeLanguage ?? "English")
    }
    private var canSave: Bool {
        onSave != nil && (profileStore.profile?.saveHistory ?? true)
    }
    private var activeMenu: ScannedMenu { displayMenu ?? menu }
    private var activeDishes: [AnalyzedDish] { displayDishes ?? analyzedDishes }

    private var filteredDishes: [AnalyzedDish] {
        var result = activeDishes.filter {
            !$0.dish.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                item.dish.name.lowercased().contains(query) ||
                (item.dish.description?.lowercased().contains(query) ?? false) ||
                item.dish.ingredients.contains { $0.lowercased().contains(query) }
            }
        }

        return result
    }

    var body: some View {
        Group {
            if isPushed {
                mainContent
            } else {
                NavigationStack {
                    mainContent
                }
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                        .padding(.horizontal, 24)

                    if showDisclaimer {
                        disclaimerBanner
                            .padding(.horizontal, 24)
                    }

                    ActiveFiltersCard(
                        groups: currentFilterGroups ?? filterGroups,
                        showChevron: true,
                        onTap: { showDietaryEditor = true }
                    )
                    .padding(.horizontal, 24)

                    dishList
                        .padding(.horizontal, 24)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemBackground))
        .searchable(text: $searchText, prompt: strings.searchDishes)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPushed {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(strings.close)
                }
            }
            if canSave {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        handleSave()
                    } label: {
                        Text(strings.save)
                            .font(.interMedium(size: 16))
                    }
                    .tint(Color("PrimaryOrange"))
                    .accessibilityLabel(strings.saveMenu)
                    .accessibilityHint(strings.saveMenuHint)
                }
            }
        }
        .sheet(isPresented: $showDietaryEditor) {
            DietaryProfileEditorView {
                reAnalyzeWithUpdatedProfile()
            }
        }
        .alert(strings.restaurantNameTitle, isPresented: $showNamePrompt) {
            TextField(strings.enterRestaurantName, text: $alertNameInput)
                .onChange(of: alertNameInput) { _, newValue in
                    if newValue.count > 20 { alertNameInput = String(newValue.prefix(20)) }
                }
            Button(strings.save) {
                let name = alertNameInput.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    var renamedMenu = activeMenu
                    renamedMenu.restaurant = name
                    onSave?(renamedMenu)
                }
            }
            Button(strings.cancel, role: .cancel) {
                alertNameInput = ""
            }
        } message: {
            Text(strings.couldntDetectName)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            let name = activeMenu.restaurant.trimmingCharacters(in: .whitespacesAndNewlines)
            let isUnknown = name.isEmpty || name.lowercased() == "unknown"

            if !isUnknown {
                Text(name)
                    .font(.interSemiBold(size: 28))
                    .foregroundStyle(Color("PrimaryOrange"))
            }

            Text(strings.dishesFound(activeDishes.count))
                .font(.interRegular(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Disclaimer

    private var disclaimerBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(strings.analyzedOnDevice)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(strings.confirmWithStaff)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(strings.analysisNoticeA11y)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) { showDisclaimer = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.quaternary)
            }
            .accessibilityLabel(strings.dismissDisclaimer)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Dish List

    private var dishList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredDishes.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            } else {
                ForEach(filteredDishes) { item in
                    DishCard(item: item, allergens: allergens, strings: strings, menu: activeMenu)
                }
            }
        }
    }

    // MARK: - Save

    private func handleSave() {
        let m = activeMenu
        let name = m.restaurant.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUnknown = name.isEmpty || name.lowercased() == "unknown"

        if isUnknown {
            alertNameInput = ""
            showNamePrompt = true
        } else {
            onSave?(m)
        }
    }

    private func reAnalyzeWithUpdatedProfile() {
        guard let profile = profileStore.profile else { return }
        let menuToAnalyze = activeMenu
        displayDishes = AllergenChecker.analyze(menu: menuToAnalyze, profile: profile)

        let vm = HomeViewModel()
        currentFilterGroups = vm.groupedFilters(for: profile)
    }
}

// MARK: - Dish Card

private struct DishCard: View {
    let item: AnalyzedDish
    let allergens: [Allergen]
    let strings: AppStrings
    let menu: ScannedMenu

    @State private var showLocation = false

    private var canShowLocation: Bool {
        !item.dish.textRegionIndices.isEmpty && !menu.imageFileNames.isEmpty
    }

    private var accentColor: Color {
        if item.isSafe { return .green }
        if item.isDanger { return .red }
        return .orange
    }

    private var isUnrecognizedDish: Bool {
        item.dish.inferredIngredients.contains(where: {
            $0.lowercased().contains("unrecognized")
        })
    }

    private var hasExplicitIngredients: Bool {
        !item.dish.ingredients.isEmpty
    }

    private var hasInferredIngredients: Bool {
        !item.dish.inferredIngredients.isEmpty && !isUnrecognizedDish
    }

    private func nameFor(_ id: String) -> String {
        strings.localizedAllergenName(id)
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 5)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(item.dish.name)
                        .font(.interSemiBold(size: 16))

                    Spacer()

                    if canShowLocation {
                        Image(systemName: "eye")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color("PrimaryOrange").opacity(0.6))
                    }
                }

                if let description = item.dish.description, !description.isEmpty {
                    Text(description)
                        .font(.interRegular(size: 13))
                        .foregroundStyle(.secondary)
                }

                if hasExplicitIngredients {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(strings.ingredientsLabel, systemImage: "list.bullet")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                        ingredientsText
                            .font(.interRegular(size: 12))
                            .lineLimit(3)
                    }
                    .padding(.top, 2)
                } else if isUnrecognizedDish {
                    Label {
                        Text(strings.unknownDishWarning)
                            .font(.interRegular(size: 11))
                    } icon: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.orange.opacity(0.8))
                    .padding(.top, 2)
                } else {
                    Label {
                        Text(strings.noIngredientsDetected)
                            .font(.interRegular(size: 11))
                    } icon: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.gray)
                    .padding(.top, 2)
                }

                if hasInferredIngredients {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                            .padding(.top, 3)
                        inferredIngredientsText
                            .font(.interRegular(size: 11))
                            .lineLimit(2)
                    }
                    .foregroundStyle(.secondary.opacity(0.6))
                }

                if !item.isSafe {
                    Divider()
                    VStack(alignment: .leading, spacing: 3) {
                        if item.isDanger {
                            Label {
                                Text(dangerSummary)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                        }
                        if item.isAdvisory {
                            Label {
                                Text(advisorySummary)
                            } icon: {
                                Image(systemName: "info.circle.fill")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                        }
                        if item.hasSuggested {
                            Label {
                                Text(suggestedSummary)
                            } icon: {
                                Image(systemName: "sparkles")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.purple.opacity(0.8))
                        }
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            if canShowLocation {
                showLocation = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dishAccessibilityLabel)
        .accessibilityHint(canShowLocation ? strings.viewOnMenu : dishAccessibilityHint)
        .sheet(isPresented: $showLocation) {
            DishLocationView(item: item, allergens: allergens, menu: menu, strings: strings)
        }
    }

    private var dishAccessibilityLabel: String {
        var label = "\(item.dish.name)"
        if isUnrecognizedDish {
            label += ". \(strings.unknownDishWarning)"
        } else if !hasExplicitIngredients && hasInferredIngredients {
            label += ". \(strings.ingredientsNotListed): \(item.dish.inferredIngredients.joined(separator: ", "))"
        }
        if item.isSafe {
            label += ", safe"
        } else if item.isDanger {
            label += ", \(dangerSummary)"
        } else if item.isAdvisory {
            label += ", \(advisorySummary)"
        }
        return label
    }

    private var dishAccessibilityHint: String {
        if isUnrecognizedDish || !hasExplicitIngredients {
            return strings.ingredientsNotListed
        }
        return ""
    }

    // MARK: - Warning Summaries

    private var dangerSummary: String {
        var parts: [String] = []
        if !item.matchedAllergenIds.isEmpty {
            parts.append(item.matchedAllergenIds.map { nameFor($0) }.joined(separator: ", "))
        }
        if !item.matchedConditionIds.isEmpty {
            parts.append(item.matchedConditionIds.map { nameFor($0) }.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private var advisorySummary: String {
        var parts: [String] = []
        if !item.matchedIntoleranceIds.isEmpty {
            parts.append(item.matchedIntoleranceIds.map { nameFor($0) }.joined(separator: ", "))
        }
        if !item.matchedDietIds.isEmpty {
            parts.append(item.matchedDietIds.map { nameFor($0) }.joined(separator: ", "))
        }
        if !item.matchedSituationIds.isEmpty {
            parts.append(item.matchedSituationIds.map { nameFor($0) }.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private var suggestedSummary: String {
        let names = item.suggestedMatchedIds.map { nameFor($0) }.joined(separator: ", ")
        return strings.aiSuggestsMayContain(names)
    }

    // MARK: - Ingredients Text

    private var inferredIngredientsText: Text {
        let base = Color.secondary.opacity(0.6)
        let inferred = item.dish.inferredIngredients
        var result = Text("")
        for (i, ingredient) in inferred.enumerated() {
            let color: Color = isIngredientFlagged(ingredient) ? accentColor : base
            result = Text("\(result)\(Text(ingredient).foregroundColor(color))")
            if i < inferred.count - 1 {
                result = Text("\(result)\(Text(", ").foregroundColor(base))")
            }
        }
        return result
    }

    private var ingredientsText: Text {
        let safe = Color.secondary.opacity(0.7)
        let ingredients = item.dish.ingredients
        var result = Text("")
        for (i, ingredient) in ingredients.enumerated() {
            let color: Color = isIngredientFlagged(ingredient) ? accentColor : safe
            result = Text("\(result)\(Text(ingredient).foregroundColor(color))")
            if i < ingredients.count - 1 {
                result = Text("\(result)\(Text(", ").foregroundColor(safe))")
            }
        }
        return result
    }

    private func isIngredientFlagged(_ ingredient: String) -> Bool {
        let lower = ingredient.lowercased()
        let allMatchedIds = item.dangerIds + item.advisoryIds
        return allMatchedIds.contains { id in
            (Self.keywords[id] ?? []).contains { lower.contains($0) }
        }
    }

    private static let keywords: [String: [String]] = [
        "gluten": ["wheat", "flour", "bread", "pasta", "barley", "rye", "oat", "semolina", "couscous", "noodle", "dough", "pastry", "cracker", "trigo", "harina", "pan", "avena", "cebada", "centeno", "grano", "farina", "orzo", "segale"],
        "dairy": ["milk", "cheese", "cream", "butter", "yogurt", "mozzarella", "parmesan", "cheddar", "ricotta", "mascarpone", "brie", "feta", "whey", "ghee", "paneer", "leche", "queso", "crema", "mantequilla", "yogur", "nata", "latte", "formaggio", "burro", "panna"],
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
        "lactose": ["milk", "cheese", "cream", "butter", "yogurt", "ice cream", "leche", "queso", "crema", "mantequilla", "yogur", "helado", "latte", "formaggio", "burro", "gelato"],
        "fructose": ["honey", "apple", "pear", "mango", "agave", "miel", "manzana", "pera", "miele", "mela"],
        "histamine": ["wine", "aged cheese", "fermented", "cured", "smoked", "vinegar", "vino", "ahumado", "curado", "fermentado", "affumicato", "stagionato"],
        "fodmap": ["garlic", "onion", "wheat", "apple", "pear", "ajo", "cebolla", "trigo", "manzana", "aglio", "cipolla"],
        "meat": ["beef", "steak", "veal", "lamb", "pork", "ham", "bacon", "sausage", "salami", "prosciutto", "bresaola", "chorizo", "pepperoni", "mortadella", "pancetta", "carne", "res", "ternera", "cordero", "cerdo", "jamón", "tocino", "salchicha", "manzo", "vitello", "agnello", "maiale", "meatball", "burger", "ribs", "loin", "filet", "albóndigas", "hamburguesa", "costillas", "lomo", "polpette", "bistecca"],
        "poultry": ["chicken", "turkey", "duck", "goose", "quail", "pollo", "pavo", "pato", "gallina", "tacchino", "anatra", "oca", "quaglia"],
        "pork": ["pork", "ham", "bacon", "sausage", "salami", "prosciutto", "pancetta", "chorizo", "pepperoni", "mortadella", "lard", "guanciale", "cerdo", "jamón", "tocino", "salchicha", "manteca", "maiale", "lardo", "speck"],
        "alcohol": ["wine", "beer", "cocktail", "liquor", "rum", "vodka", "whisky", "gin", "tequila", "brandy", "champagne", "prosecco", "sangria", "vino", "cerveza", "birra", "liquore", "grappa", "amaro", "spritz"]
    ]
}
