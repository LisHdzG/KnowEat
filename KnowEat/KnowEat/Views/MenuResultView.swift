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
    let activeFilters: [Allergen]
    var onSave: ((ScannedMenu) -> Void)? = nil
    let onDismiss: () -> Void

    @State private var showNamePrompt = false
    @State private var alertNameInput = ""
    @State private var searchText = ""
    @State private var selectedCategoryIndex = 0
    @State private var showDisclaimer = true

    private var isReadOnly: Bool { onSave == nil }

    private var categories: [String] {
        let cats = Set(analyzedDishes.compactMap { $0.dish.category })
        return ["All"] + cats.sorted()
    }

    private var selectedCategory: String? {
        guard selectedCategoryIndex > 0, selectedCategoryIndex < categories.count else { return nil }
        return categories[selectedCategoryIndex]
    }

    private var filteredDishes: [AnalyzedDish] {
        var result = analyzedDishes

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

                        ActiveFiltersCard(filters: activeFilters) {
                            // TODO: Navigate to allergen editor
                        }
                        .padding(.horizontal, 24)

                        searchBar
                            .padding(.horizontal, 24)

                        dishList
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(Color("SecondaryGray"))
                }
                if !isReadOnly {
                    ToolbarItem(placement: .topBarTrailing) {
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
            .alert("Restaurant Name", isPresented: $showNamePrompt) {
                TextField("Enter restaurant name", text: $alertNameInput)
                    .onChange(of: alertNameInput) { _, newValue in
                        if newValue.count > 20 { alertNameInput = String(newValue.prefix(20)) }
                    }
                Button("Save") {
                    let name = alertNameInput.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        let savedMenu = ScannedMenu(restaurant: name, dishes: menu.dishes, categoryIcon: menu.categoryIcon, menuLanguage: menu.menuLanguage)
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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            let name = menu.restaurant.trimmingCharacters(in: .whitespacesAndNewlines)
            let isUnknown = name.isEmpty || name.lowercased() == "unknown"

            if !isUnknown {
                Text(name)
                    .font(.interSemiBold(size: 28))
                    .foregroundStyle(Color("PrimaryOrange"))
            }

            Text("\(analyzedDishes.count) dishes found")
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

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))

            TextField("Search dishes...", text: $searchText)
                .font(.interRegular(size: 15))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
        let name = menu.restaurant.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUnknown = name.isEmpty || name.lowercased() == "unknown"

        if isUnknown {
            alertNameInput = ""
            showNamePrompt = true
        } else {
            onSave?(menu)
        }
    }
}

// MARK: - Dish Card

private struct DishCard: View {
    let item: AnalyzedDish
    let allergens: [Allergen]

    private var accentColor: Color {
        item.isSafe ? .green : Color("PrimaryOrange")
    }

    private var statusIcon: String {
        if item.isSafe {
            return "checkmark.circle.fill"
        }
        return item.matchedAllergenIds.count >= 3
            ? "xmark.circle.fill"
            : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        if item.isSafe {
            return .green
        }
        return item.matchedAllergenIds.count >= 3 ? .red : Color("PrimaryOrange")
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 6)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.dish.name)
                            .font(.interSemiBold(size: 16))
                            .foregroundStyle(.primary)

                        if let description = item.dish.description, !description.isEmpty {
                            Text(description)
                                .font(.interRegular(size: 12))
                                .foregroundStyle(Color("SecondaryGray"))
                                .italic()
                        }
                    }

                    Spacer()

                    Image(systemName: statusIcon)
                        .font(.system(size: 24))
                        .foregroundStyle(statusColor)
                }

                if !item.dish.ingredients.isEmpty {
                    Text(item.dish.ingredients.joined(separator: ", "))
                        .font(.interRegular(size: 13))
                        .foregroundStyle(Color("SecondaryGray").opacity(0.9))
                        .lineLimit(2)
                }

                if let price = item.dish.price, !price.isEmpty {
                    HStack {
                        Spacer()
                        Text(price)
                            .font(.interMedium(size: 14))
                            .foregroundStyle(Color("SecondaryGray"))
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
}
