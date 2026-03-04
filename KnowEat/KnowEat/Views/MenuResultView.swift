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
    @State private var selectedCategoryIndex = 0
    @State private var showDisclaimer = true
    @State private var showLanguagePicker = false
    @State private var selectedLanguage = ""
    @State private var displayMenu: ScannedMenu?
    @State private var displayDishes: [AnalyzedDish]?
    @State private var isTranslating = false
    @State private var translationError: String?
    @State private var showDietaryEditor = false
    @State private var currentFilterGroups: [DietaryFilterGroup]?

    private let availableLanguages = ["English", "Español", "Italiano"]
    private var canSave: Bool {
        onSave != nil && (profileStore.profile?.saveHistory ?? true)
    }
    private var isReadOnly: Bool { !canSave }
    private var activeMenu: ScannedMenu { displayMenu ?? menu }
    private var activeDishes: [AnalyzedDish] { displayDishes ?? analyzedDishes }

    private var categories: [String] {
        let cats = Set(activeDishes.compactMap { $0.dish.category })
        return ["All"] + cats.sorted()
    }

    private var selectedCategory: String? {
        guard selectedCategoryIndex > 0, selectedCategoryIndex < categories.count else { return nil }
        return categories[selectedCategoryIndex]
    }

    private var filteredDishes: [AnalyzedDish] {
        var result = activeDishes.filter {
            !$0.dish.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if let category = selectedCategory {
            result = result.filter { $0.dish.category == category }
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

    private var groupedByCategory: [(String, [AnalyzedDish])] {
        let dict = Dictionary(grouping: filteredDishes) { item in
            item.dish.category ?? "Other"
        }
        return dict.sorted { $0.key < $1.key }
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
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerOverlay(
                selectedLanguage: $selectedLanguage,
                languages: availableLanguages,
                isPresented: $showLanguagePicker,
                presentedAsSheet: true
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isTranslating) {
            LoaderView(phrases: [
                "Translating dishes…",
                "Adapting ingredients…",
                "Updating your menu…",
                "Almost ready…"
            ])
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if categories.count > 2 {
                categoryPicker
            }

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
        .searchable(text: $searchText, prompt: "Search dishes...")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPushed {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(Color("SecondaryGray"))
                    .accessibilityLabel("Close")
                    .accessibilityHint("Dismisses the menu results and returns to the previous screen")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isReadOnly {
                    Button {
                        showLanguagePicker = true
                    } label: {
                        Image(systemName: "character.bubble")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .tint(Color("PrimaryOrange"))
                    .accessibilityLabel("Change language")
                    .accessibilityHint("Opens the language picker to translate the menu")
                } else {
                    Button {
                        handleSave()
                    } label: {
                        Text("Save")
                            .font(.interMedium(size: 16))
                    }
                    .tint(Color("PrimaryOrange"))
                    .accessibilityLabel("Save menu")
                    .accessibilityHint("Saves this menu to your recent menus list")
                }
            }
        }
        .onAppear {
            if selectedLanguage.isEmpty {
                let menuLang = menu.menuLanguage
                if menuLang != "Unknown" && !menuLang.isEmpty {
                    selectedLanguage = menuLang
                } else {
                    selectedLanguage = profileStore.profile?.nativeLanguage ?? "English"
                }
            }
        }
        .onChange(of: selectedLanguage) { oldValue, newValue in
            guard !oldValue.isEmpty, oldValue != newValue else { return }
            handleRetranslation(to: newValue)
        }
        .sheet(isPresented: $showDietaryEditor) {
            DietaryProfileEditorView {
                reAnalyzeWithUpdatedProfile()
            }
        }
        .alert("Restaurant Name", isPresented: $showNamePrompt) {
            TextField("Enter restaurant name", text: $alertNameInput)
                .onChange(of: alertNameInput) { _, newValue in
                    if newValue.count > 20 { alertNameInput = String(newValue.prefix(20)) }
                }
            Button("Save") {
                let name = alertNameInput.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    let savedMenu = ScannedMenu(restaurant: name, dishes: activeMenu.dishes, categoryIcon: activeMenu.categoryIcon, menuLanguage: activeMenu.menuLanguage)
                    onSave?(savedMenu)
                }
            }
            Button("Cancel", role: .cancel) {
                alertNameInput = ""
            }
        } message: {
            Text("We couldn't detect the restaurant name. Please enter it to save this menu.")
        }
        .alert("Translation Error", isPresented: .init(
            get: { translationError != nil },
            set: { if !$0 { translationError = nil } }
        )) {
            Button("OK") { translationError = nil }
        } message: {
            Text(translationError ?? "")
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

            Text("\(activeDishes.count) dishes found")
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
                Text("Analyzed on your device")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Always confirm with staff for severe allergies.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Analysis notice. Menu was analyzed on your device. Always confirm with staff for severe allergies.")

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) { showDisclaimer = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.quaternary)
            }
            .accessibilityLabel("Dismiss disclaimer")
            .accessibilityHint("Hides the analysis notice banner")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories.indices, id: \.self) { index in
                        let title = index == 0 ? "All" : (
                            categories[index].components(separatedBy: "(").first?
                                .trimmingCharacters(in: .whitespaces) ?? categories[index]
                        )

                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                selectedCategoryIndex = index
                            }
                        } label: {
                            Text(title)
                                .font(.system(size: 14, weight: selectedCategoryIndex == index ? .semibold : .regular))
                                .foregroundStyle(selectedCategoryIndex == index ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedCategoryIndex == index ? Color("PrimaryOrange") : Color(.systemGray6))
                                )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .accessibilityLabel(title)
                        .accessibilityHint(selectedCategoryIndex == index ? "Selected. Filtering by \(title)" : "Filters dishes to show only \(title)")
                        .accessibilityAddTraits(selectedCategoryIndex == index ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }
            .background(Color(.systemBackground))
            .onChange(of: selectedCategoryIndex) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    // MARK: - Dish List

    private var dishList: some View {
        VStack(alignment: .leading, spacing: 24) {
            if filteredDishes.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            } else {
                ForEach(groupedByCategory, id: \.0) { category, dishes in
                    VStack(alignment: .leading, spacing: 12) {
                        if selectedCategory == nil {
                            Text(category.uppercased())
                                .font(.interSemiBold(size: 14))
                                .foregroundStyle(.primary)
                                .tracking(0.5)
                        }

                        ForEach(dishes) { item in
                            DishCard(item: item, allergens: allergens)
                        }
                    }
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

    private func handleRetranslation(to language: String) {
        showLanguagePicker = false
        selectedCategoryIndex = 0
        let currentMenu = activeMenu

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            isTranslating = true
            do {
                let result = try await FoundationModelAnalyzer.shared.translateMenu(
                    dishes: currentMenu.dishes,
                    restaurant: currentMenu.restaurant,
                    to: language
                )

                var updated = displayMenu ?? menu
                updated.dishes = result.dishes
                updated.restaurant = result.restaurant
                updated.menuLanguage = language
                displayMenu = updated

                let profile = profileStore.profile ?? UserProfile(nativeLanguage: "", allergenIds: [])
                displayDishes = AllergenChecker.analyze(menu: updated, profile: profile)

                if isReadOnly {
                    menuStore.updateTranslation(menu, translated: updated)
                }

                isTranslating = false
            } catch {
                isTranslating = false
                translationError = error.localizedDescription
            }
        }
    }
}

// MARK: - Dish Card

private struct DishCard: View {
    let item: AnalyzedDish
    let allergens: [Allergen]

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
        allergens.first(where: { $0.id == id })?.name ?? id
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 5)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.dish.name)
                            .font(.interSemiBold(size: 16))

                        if let description = item.dish.description, !description.isEmpty {
                            Text(description)
                                .font(.interRegular(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    if let price = item.dish.price, !price.isEmpty {
                        Text(price)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                if !item.dish.ingredients.isEmpty {
                    ingredientsText
                        .font(.interRegular(size: 13))
                        .lineLimit(2)
                }

                if isUnrecognizedDish {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .padding(.top, 3)

                        Text("Unknown dish — please ask staff about ingredients")
                            .font(.interRegular(size: 12))
                            .lineLimit(2)
                    }
                    .foregroundStyle(.orange.opacity(0.8))
                } else if hasInferredIngredients {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                                .padding(.top, 3)

                            inferredIngredientsText
                                .font(.interRegular(size: 12))
                                .lineLimit(2)
                        }
                        .foregroundStyle(.secondary.opacity(0.7))

                        if !hasExplicitIngredients {
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9))
                                    .padding(.top, 3)

                                Text("Ingredients not listed on menu — confirm with staff")
                                    .font(.interRegular(size: 11))
                                    .lineLimit(2)
                            }
                            .foregroundStyle(.orange.opacity(0.7))
                        }
                    }
                } else if !hasExplicitIngredients {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .padding(.top, 3)

                        Text("No ingredients available — please ask staff")
                            .font(.interRegular(size: 12))
                            .lineLimit(2)
                    }
                    .foregroundStyle(.orange.opacity(0.7))
                }

                if !item.isSafe {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
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
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dishAccessibilityLabel)
        .accessibilityHint(dishAccessibilityHint)
    }

    private var dishAccessibilityLabel: String {
        var label = "\(item.dish.name)"
        if let price = item.dish.price, !price.isEmpty {
            label += ", \(price)"
        }
        if isUnrecognizedDish {
            label += ". Unknown dish, please ask staff about ingredients"
        } else if !hasExplicitIngredients && hasInferredIngredients {
            label += ". Ingredients not listed on menu, AI suggests: \(item.dish.inferredIngredients.joined(separator: ", "))"
        }
        if item.isSafe {
            label += ", safe to eat"
        } else if item.isDanger {
            label += ", not recommended. Contains allergens or not safe for your condition: \(dangerSummary)"
        } else if item.isAdvisory {
            label += ", may cause intolerance or not compatible: \(advisorySummary)"
        }
        return label
    }

    private var dishAccessibilityHint: String {
        if isUnrecognizedDish || !hasExplicitIngredients {
            return "Ingredients were not listed on the menu. Please confirm with restaurant staff"
        }
        if item.isSafe {
            return "No dietary restrictions match this dish"
        }
        if item.isDanger {
            return "Contains ingredients that may cause an allergic reaction or are not safe for your medical condition"
        }
        return "May cause intolerance or is not compatible with your diet or situation"
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
        "fodmap": ["garlic", "onion", "wheat", "apple", "pear", "ajo", "cebolla", "trigo", "manzana", "aglio", "cipolla"]
    ]
}
