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
    @State private var displayMenu: ScannedMenu?
    @State private var displayDishes: [AnalyzedDish]?
    @State private var showDietaryEditor = false
    @State private var showLegend = false
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

                    legendExpandableSection
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

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

    // MARK: - Legend Desplegable

    private var legendExpandableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showLegend.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 12))
                    Text(strings.legendButton)
                        .font(.interRegular(size: 13))
                    Spacer()
                    Image(systemName: showLegend ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tint(.secondary)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(showLegend ? strings.legendTitle : "\(strings.legendButton), \(strings.legendTitle)")
            .accessibilityHint(showLegend ? "Collapses the color guide" : "Expands the color guide")

            if showLegend {
                legendCardContent
                    .padding(.top, 8)
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            }
        }
    }

    private var legendCardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(color: .green, icon: "checkmark.circle.fill", text: strings.legendSafe)
            legendRow(color: .orange, icon: "info.circle.fill", text: strings.legendAdvisory)
            legendRow(color: .red, icon: "exclamationmark.triangle.fill", text: strings.legendDanger)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground.withAlphaComponent(0.5)))
        )
    }

    private func legendRow(color: Color, icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(text)
                .font(.interRegular(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                    DishCard(item: item, allergens: allergens, strings: strings, menu: activeMenu, onShowLegend: { showLegend = true })
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
    var onShowLegend: (() -> Void)? = nil

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

    private func nameFor(_ id: String) -> String {
        strings.localizedAllergenName(id)
    }

    private let iconWidth: CGFloat = 16
    private let rowSpacing: CGFloat = 8

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Columna 1: Solo barra de color (sin icono)
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 5)
                .padding(.top, 14)

            // Columna 2: Contenido principal (alineación consistente)
            VStack(alignment: .leading, spacing: rowSpacing) {
                // Nombre del plato
                Text(item.dish.name)
                    .font(.interSemiBold(size: 16))
                    .lineLimit(nil)

                if let translated = item.dish.translatedName, !translated.isEmpty {
                    Text(translated)
                        .font(.interRegular(size: 13))
                        .foregroundStyle(Color("PrimaryOrange").opacity(0.8))
                }

                if let description = item.dish.description, !description.isEmpty {
                    Text(description)
                        .font(.interRegular(size: 13))
                        .foregroundStyle(.secondary)
                }

                // Bloque de ingredientes/estado (iconos con ancho fijo para alineación)
                if hasExplicitIngredients {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: iconWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(strings.ingredientsLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                            ingredientsText
                                .font(.interRegular(size: 12))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else if isUnrecognizedDish {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange.opacity(0.8))
                            .frame(width: iconWidth, alignment: .leading)
                        Text(strings.unknownDishWarning)
                            .font(.interRegular(size: 11))
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.gray)
                            .frame(width: iconWidth, alignment: .leading)
                        Text(strings.noIngredientsDetected)
                            .font(.interRegular(size: 11))
                            .foregroundStyle(.gray)
                    }
                }

                if !item.isSafe {
                    Divider()
                        .padding(.vertical, 2)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: item.isDanger ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(item.isDanger ? .red : .orange)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            if item.isDanger {
                                Text(dangerSummary)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.red)
                                    .lineLimit(nil)
                            }
                            if item.isAdvisory {
                                Text(advisorySummary)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.orange)
                                    .lineLimit(nil)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
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
            } else {
                onShowLegend?()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dishAccessibilityLabel)
        .accessibilityHint(canShowLocation ? strings.viewOnMenu : dishAccessibilityHint)
        .sheet(isPresented: $showLocation) {
            DishLocationView(item: item, allergens: allergens, menu: menu, strings: strings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var dishAccessibilityLabel: String {
        var label = "\(item.dish.name)"
        if isUnrecognizedDish {
            label += ". \(strings.unknownDishWarning)"
        } else if !hasExplicitIngredients {
            label += ". \(strings.noIngredientsDetected)"
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
            return strings.noIngredientsDetected
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

    // MARK: - Ingredients Text

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
        let ingredientWords = Set(
            ingredient.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )
        let allMatchedIds = item.dangerIds + item.advisoryIds
        return allMatchedIds.contains { id in
            (Self.keywords[id] ?? []).contains { keyword in
                if keyword.contains(" ") {
                    return ingredient.lowercased().contains(keyword)
                }
                return ingredientWords.contains(keyword)
            }
        }
    }

    private static let keywords: [String: [String]] = [
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
        "meat": ["beef", "steak", "veal", "lamb", "pork", "bacon", "sausage", "salami", "prosciutto", "bresaola", "chorizo", "pepperoni", "mortadella", "pancetta", "carne", "carne de res", "ternera", "cordero", "cerdo", "jamón", "tocino", "salchicha", "manzo", "vitello", "agnello", "maiale", "meatball", "burger", "ribs", "albóndigas", "hamburguesa", "costillas", "lomo", "polpette", "bistecca"],
        "poultry": ["chicken", "turkey", "duck", "goose", "quail", "pollo", "pavo", "pato", "gallina", "tacchino", "anatra", "oca", "quaglia"],
        "pork": ["pork", "bacon", "sausage", "salami", "prosciutto", "pancetta", "chorizo", "pepperoni", "mortadella", "lard", "guanciale", "cerdo", "jamón", "tocino", "salchicha", "maiale", "lardo", "speck"],
        "alcohol": ["wine", "beer", "cocktail", "liquor", "rum", "vodka", "whisky", "tequila", "brandy", "champagne", "prosecco", "sangria", "vino", "cerveza", "birra", "liquore", "grappa", "amaro", "spritz"]
    ]
}
