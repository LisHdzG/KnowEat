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

    private var strings: AppStrings {
        AppStrings(viewModel.selectedLanguage)
    }

    private var sections: [(DietaryCategory, String, String, String, [Allergen])] {
        [
            (.allergens, strings.allergens, "exclamationmark.shield.fill", strings.foodAllergensDesc, viewModel.allergens),
            (.intolerances, strings.intolerances, "pills.fill", strings.intolerancesDesc, viewModel.intolerances),
            (.conditions, strings.medicalConditions, "heart.text.clipboard.fill", strings.conditionsDesc, viewModel.conditions),
            (.diets, strings.diets, "fork.knife", strings.dietsDesc, viewModel.diets),
            (.situations, strings.situations, "figure.and.child.holdinghands", strings.situationsDesc, viewModel.situations),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    dataPrivacyReminderView

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
            .background(Color(.systemBackground))
            .navigationTitle(strings.dietaryProfile)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(strings.done) {
                        syncAllToProfile()
                        onProfileUpdated?()
                        dismiss()
                    }
                    .font(.interMedium(size: 16))
                    .tint(Color("PrimaryOrange"))
                    .accessibilityLabel(strings.done)
                    .accessibilityHint("Saves your dietary profile and closes the editor")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(Color("SecondaryGray"))
                    .accessibilityLabel(strings.close)
                    .accessibilityHint("Dismisses the dietary profile editor")
                }
            }
            .onAppear {
                if let profile = profileStore.profile {
                    viewModel.load(from: profile)
                } else {
                    viewModel.selectedLanguage = Self.devicePreferredLanguage
                }
            }
        }
    }

    private var dataPrivacyReminderView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color("PrimaryOrange").opacity(0.8))
            Text(strings.dataPrivacyReminder)
                .font(.interRegular(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground).opacity(0.5))
        )
    }

    private static var devicePreferredLanguage: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("es") { return "Español" }
        if preferred.hasPrefix("it") { return "Italiano" }
        return "English"
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
                        isSelected: viewModel.isSelected(item.id, category: category),
                        displayName: strings.localizedAllergenName(item.id)
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
        var profile = profileStore.profile ?? UserProfile(
            nativeLanguage: viewModel.selectedLanguage,
            allergenIds: []
        )
        profile.nativeLanguage = viewModel.selectedLanguage
        profile.allergenIds = Array(viewModel.selectedIds(for: .allergens))
        profile.intoleranceIds = Array(viewModel.selectedIds(for: .intolerances))
        profile.conditionIds = Array(viewModel.selectedIds(for: .conditions))
        profile.dietIds = Array(viewModel.selectedIds(for: .diets))
        profile.situationIds = Array(viewModel.selectedIds(for: .situations))
        profileStore.profile = profile
    }
}
