//
//  WelcomeView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(UserProfileStore.self) private var profileStore
    @State private var viewModel = OnboardingViewModel()
    @State private var showLanguagePicker = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var sections: [(DietaryCategory, String, String, [Allergen])] {
        [
            (.allergens, "Allergens", "Most common food allergens.", viewModel.allergens),
            (.intolerances, "Intolerances", "Foods your body has trouble digesting.", viewModel.intolerances),
            (.conditions, "Medical Conditions", "Conditions that affect your diet.", viewModel.conditions),
            (.diets, "Diets", "Lifestyle or religious diets.", viewModel.diets),
            (.situations, "Situations", "Temporary situations.", viewModel.situations),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    descriptionText
                    languageSection

                    ForEach(sections, id: \.0) { category, title, description, items in
                        if !items.isEmpty {
                            dietarySectionView(
                                category: category,
                                title: title,
                                description: description,
                                items: items
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 24)
            }

            continueButton
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .overlay {
            if showLanguagePicker {
                LanguagePickerOverlay(
                    selectedLanguage: $viewModel.selectedLanguage,
                    languages: viewModel.availableLanguages,
                    isPresented: $showLanguagePicker
                )
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 2) {
            Text("Welcome to")
                .font(.interRegular(size: 20))
                .foregroundStyle(Color("SecondaryGray"))

            Text("KnowEat")
                .font(.italianno(size: 56))
                .foregroundStyle(Color("PrimaryOrange"))
        }
        .frame(maxWidth: .infinity)
    }

    private var descriptionText: some View {
        Text("Set up your dietary profile. You can always change it later in Settings.")
            .font(.interRegular(size: 15))
            .foregroundStyle(Color("SecondaryGray"))
            .lineSpacing(3)
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Primary language")
                .font(.interMedium(size: 13))
                .foregroundStyle(Color("SecondaryGray"))

            Button {
                showLanguagePicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 22))
                        .foregroundStyle(Color("PrimaryOrange"))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color("PrimaryOrange").opacity(0.12))
                        )

                    Text("Native Language")
                        .font(.interSemiBold(size: 16))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(viewModel.selectedLanguage)
                        .font(.interRegular(size: 15))
                        .foregroundStyle(Color("SecondaryGray"))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color("SecondaryGray"))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Dietary Sections

    private func dietarySectionView(
        category: DietaryCategory,
        title: String,
        description: String,
        items: [Allergen]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.interMedium(size: 13))
                .foregroundStyle(Color("SecondaryGray"))

            Text(description)
                .font(.interRegular(size: 13))
                .foregroundStyle(Color("SecondaryGray").opacity(0.7))

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

    private var continueButton: some View {
        Button {
            profileStore.profile = viewModel.buildProfile()
        } label: {
            Text("Continue")
                .font(.interSemiBold(size: 18))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color("PrimaryOrange"))
                )
        }
    }
}

#Preview {
    WelcomeView()
        .environment(UserProfileStore())
}
