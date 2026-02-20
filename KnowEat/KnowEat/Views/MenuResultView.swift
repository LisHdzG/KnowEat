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
    let onDismiss: () -> Void

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
        var result = activeDishes

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
        ZStack {
        NavigationStack {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(Color("SecondaryGray"))
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
                    } else {
                        Button {
                            handleSave()
                        } label: {
                            Text("Save")
                                .font(.interMedium(size: 16))
                        }
                        .tint(Color("PrimaryOrange"))
                    }
                }
            }
            .onAppear {
                if selectedLanguage.isEmpty {
                    selectedLanguage = profileStore.profile?.nativeLanguage ?? "English"
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
        }

        if showLanguagePicker {
            LanguagePickerOverlay(
                selectedLanguage: $selectedLanguage,
                languages: availableLanguages,
                isPresented: $showLanguagePicker
            )
        }

        if isTranslating {
            LoaderView(phrases: [
                "Translating dishes…",
                "Adapting ingredients…",
                "Updating your menu…",
                "Almost ready…"
            ])
            .transition(.opacity)
            .ignoresSafeArea()
        }
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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 16))
                .padding(.top, 1)

            Text("These results are AI-generated recommendations. Always verify with the restaurant staff if you have severe allergies.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                withAnimation { showDisclaimer = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
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
        isTranslating = true
        selectedCategoryIndex = 0
        let sourceDishes = activeMenu.dishes

        Task { @MainActor in
            do {
                let translated = try await OpenAIService.shared.retranslateMenu(dishes: sourceDishes, to: language)

                var updated = displayMenu ?? menu
                updated.dishes = translated
                updated.menuLanguage = language
                displayMenu = updated

                let profile = profileStore.profile ?? UserProfile(nativeLanguage: "", allergenIds: [])
                displayDishes = AllergenChecker.analyze(menu: updated, profile: profile)

                if isReadOnly {
                    menuStore.updateTranslation(menu, dishes: translated, menuLanguage: language)
                }

                isTranslating = false
            } catch {
                isTranslating = false
            }
        }
    }
}

// MARK: - Dish Card

private struct DishCard: View {
    let item: AnalyzedDish
    let allergens: [Allergen]

    private static let allergenIDs: Set<String> = [
        "gluten", "crustaceans", "eggs", "fish", "peanuts",
        "soy", "dairy", "tree_nuts", "celery", "mustard",
        "sesame", "sulfites", "lupins", "mollusks"
    ]

    private var matchedAllergens: [String] {
        item.matchedAllergenIds.filter { Self.allergenIDs.contains($0) }
    }

    private var advisoryRestrictions: [String] {
        item.matchedAllergenIds
            .filter { !Self.allergenIDs.contains($0) }
            .compactMap { id in allergens.first(where: { $0.id == id })?.name }
    }

    private var hasAllergenDanger: Bool { !matchedAllergens.isEmpty }
    private var hasAdvisoryOnly: Bool { !item.isSafe && matchedAllergens.isEmpty }

    private var accentColor: Color {
        if item.isSafe { return .green }
        if hasAllergenDanger { return .red }
        return .yellow
    }

    private var statusColor: Color { accentColor }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 6)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let original = item.dish.description, !original.isEmpty {
                            Text(original)
                                .font(.interSemiBold(size: 16))
                                .foregroundStyle(.primary)

                            Text(item.dish.name)
                                .font(.interRegular(size: 13))
                                .foregroundStyle(Color("SecondaryGray"))
                                .italic()
                        } else {
                            Text(item.dish.name)
                                .font(.interSemiBold(size: 16))
                                .foregroundStyle(.primary)
                        }
                    }

                    Spacer()
                }

                if !item.dish.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ingredients")
                            .font(.interMedium(size: 12))
                            .foregroundStyle(Color("SecondaryGray").opacity(0.5))

                        ingredientsText
                            .font(.interRegular(size: 13))
                            .lineLimit(2)
                    }
                }

                if !item.isSafe, !advisoryRestrictions.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow)
                            .padding(.top, 1)

                        Text("Not recommended for: \(advisoryRestrictions.joined(separator: ", "))")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.yellow.opacity(0.08))
                    )
                    .padding(.top, 2)
                }

                if let price = item.dish.price, !price.isEmpty {
                    HStack {
                        Spacer()
                        Text(price)
                            .font(.interMedium(size: 14))
                            .foregroundStyle(Color("SecondaryGray").opacity(0.45))
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    private var ingredientsText: Text {
        let safe = Color("SecondaryGray").opacity(0.85)
        let ingredients = item.dish.ingredients
        var result = Text("")
        for (i, ingredient) in ingredients.enumerated() {
            let color: Color = isIngredientFlagged(ingredient) ? statusColor : safe
            result = Text("\(result)\(Text(ingredient).foregroundColor(color))")
            if i < ingredients.count - 1 {
                result = Text("\(result)\(Text(", ").foregroundColor(safe))")
            }
        }
        return result
    }

    private func isIngredientFlagged(_ ingredient: String) -> Bool {
        let lower = ingredient.lowercased()
        return item.matchedAllergenIds.contains { id in
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
