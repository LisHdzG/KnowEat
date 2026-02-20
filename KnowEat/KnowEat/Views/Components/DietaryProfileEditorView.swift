//
//  DietaryProfileEditorView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct DietaryProfileEditorView: View {
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SettingsViewModel()
    var onProfileUpdated: (() -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var sections: [(DietaryCategory, String, String, String, [Allergen])] {
        [
            (.allergens, "Allergens", "exclamationmark.shield.fill", "Food allergens that can cause reactions.", viewModel.allergens),
            (.intolerances, "Intolerances", "pills.fill", "Foods your body has trouble digesting.", viewModel.intolerances),
            (.conditions, "Medical Conditions", "heart.text.clipboard.fill", "Conditions that affect your diet.", viewModel.conditions),
            (.diets, "Diets", "fork.knife", "Lifestyle or religious diets.", viewModel.diets),
            (.situations, "Situations", "figure.and.child.holdinghands", "Temporary situations.", viewModel.situations),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(sections, id: \.0) { category, title, icon, description, items in
                        if !items.isEmpty {
                            sectionView(
                                category: category,
                                title: title,
                                icon: icon,
                                description: description,
                                items: items
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dietary Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        syncAllToProfile()
                        onProfileUpdated?()
                        dismiss()
                    }
                    .font(.interMedium(size: 16))
                    .tint(Color("PrimaryOrange"))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(Color("SecondaryGray"))
                }
            }
            .onAppear {
                if let profile = profileStore.profile {
                    viewModel.load(from: profile)
                }
            }
        }
    }

    private func sectionView(
        category: DietaryCategory,
        title: String,
        icon: String,
        description: String,
        items: [Allergen]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color("PrimaryOrange"))

                Text(title)
                    .font(.interSemiBold(size: 16))
                    .foregroundStyle(.primary)
            }

            Text(description)
                .font(.interRegular(size: 13))
                .foregroundStyle(Color("SecondaryGray"))

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    AllergenChipView(
                        allergen: item,
                        isSelected: viewModel.isSelected(item.id, category: category)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggle(item.id, category: category)
                        }
                    }
                }
            }
        }
    }

    private func syncAllToProfile() {
        profileStore.profile?.allergenIds = Array(viewModel.selectedIds(for: .allergens))
        profileStore.profile?.intoleranceIds = Array(viewModel.selectedIds(for: .intolerances))
        profileStore.profile?.conditionIds = Array(viewModel.selectedIds(for: .conditions))
        profileStore.profile?.dietIds = Array(viewModel.selectedIds(for: .diets))
        profileStore.profile?.situationIds = Array(viewModel.selectedIds(for: .situations))
    }
}
