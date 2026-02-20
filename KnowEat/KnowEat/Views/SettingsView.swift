//
//  SettingsView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(UserProfileStore.self) private var profileStore
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                translationSection
                dietarySection
                historySection
                aboutSection
                versionLabel
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .tint(Color("PrimaryOrange"))
        .onAppear {
            if let profile = profileStore.profile {
                viewModel.load(from: profile)
            }
        }
        .overlay {
            if viewModel.showLanguagePicker {
                LanguagePickerOverlay(
                    selectedLanguage: $viewModel.selectedLanguage,
                    languages: viewModel.availableLanguages,
                    isPresented: $viewModel.showLanguagePicker
                )
                .onChange(of: viewModel.selectedLanguage) { _, newValue in
                    profileStore.profile?.nativeLanguage = newValue
                }
            }
        }
    }

    // MARK: - Sections

    private var translationSection: some View {
        sectionContainer(header: "Translation preferences") {
            Button {
                viewModel.showLanguagePicker = true
            } label: {
                settingsRow(
                    icon: "character.book.closed",
                    title: "Native Language",
                    trailing: viewModel.selectedLanguage,
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var dietarySection: some View {
        sectionContainer(
            header: "Dietary Profile",
            footer: "KnowEat will consider all your dietary restrictions when scanning menus."
        ) {
            VStack(spacing: 0) {
                dietaryRow(
                    icon: "exclamationmark.shield.fill",
                    title: "Allergens",
                    editorTitle: "My Allergens",
                    description: "Select the allergens you want KnowEat to watch for when scanning menus.",
                    items: viewModel.allergens,
                    category: .allergens,
                    count: profileStore.profile?.allergenIds.count ?? 0
                )

                sectionDivider

                dietaryRow(
                    icon: "pills.fill",
                    title: "Intolerances",
                    editorTitle: "Intolerances",
                    description: "Select food intolerances so KnowEat can flag problematic ingredients.",
                    items: viewModel.intolerances,
                    category: .intolerances,
                    count: profileStore.profile?.intoleranceIds.count ?? 0
                )

                sectionDivider

                dietaryRow(
                    icon: "heart.text.clipboard.fill",
                    title: "Medical Conditions",
                    editorTitle: "Medical Conditions",
                    description: "Select medical conditions that affect your diet so KnowEat can give better recommendations.",
                    items: viewModel.conditions,
                    category: .conditions,
                    count: profileStore.profile?.conditionIds.count ?? 0
                )

                sectionDivider

                dietaryRow(
                    icon: "fork.knife",
                    title: "Diets",
                    editorTitle: "Diets",
                    description: "Select lifestyle or religious diets you follow.",
                    items: viewModel.diets,
                    category: .diets,
                    count: profileStore.profile?.dietIds.count ?? 0
                )

                sectionDivider

                dietaryRow(
                    icon: "figure.and.child.holdinghands",
                    title: "Situations",
                    editorTitle: "Situations",
                    description: "Select temporary situations that may affect what you should eat.",
                    items: viewModel.situations,
                    category: .situations,
                    count: profileStore.profile?.situationIds.count ?? 0
                )
            }
        }
    }

    private func dietaryRow(
        icon: String,
        title: String,
        editorTitle: String,
        description: String,
        items: [Allergen],
        category: DietaryCategory,
        count: Int
    ) -> some View {
        NavigationLink {
            dietaryEditorView(
                title: editorTitle,
                description: description,
                items: items,
                category: category
            )
        } label: {
            settingsRow(
                icon: icon,
                title: title,
                trailing: count > 0 ? "\(count) active" : nil,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.leading, 62)
    }

    // MARK: - Generic Dietary Editor

    private let editorColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private func dietaryEditorView(
        title: String,
        description: String,
        items: [Allergen],
        category: DietaryCategory
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(description)
                    .font(.interRegular(size: 15))
                    .foregroundStyle(Color("SecondaryGray"))
                    .lineSpacing(3)
                    .padding(.horizontal, 24)

                LazyVGrid(columns: editorColumns, spacing: 12) {
                    ForEach(items) { item in
                        AllergenChipView(
                            allergen: item,
                            isSelected: viewModel.isSelected(item.id, category: category)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggle(item.id, category: category)
                                syncProfile(category: category)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }

    private func syncProfile(category: DietaryCategory) {
        let ids = Array(viewModel.selectedIds(for: category))
        switch category {
        case .allergens: profileStore.profile?.allergenIds = ids
        case .intolerances: profileStore.profile?.intoleranceIds = ids
        case .conditions: profileStore.profile?.conditionIds = ids
        case .diets: profileStore.profile?.dietIds = ids
        case .situations: profileStore.profile?.situationIds = ids
        }
    }

    private var historySection: some View {
        sectionContainer(header: "History") {
            HStack(spacing: 14) {
                settingsIcon("clock.arrow.circlepath")

                Text("Save history")
                    .font(.interRegular(size: 16))

                Spacer()

                Toggle("", isOn: saveHistoryBinding)
                    .labelsHidden()
                    .tint(Color("PrimaryOrange"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var aboutSection: some View {
        sectionContainer(header: "About") {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "lock.fill",
                    title: "Privacy Policy",
                    showChevron: true
                )

                Divider()
                    .padding(.leading, 62)

                settingsRow(
                    icon: "star.fill",
                    title: "Rate KnowEat",
                    showChevron: true
                )
            }
        }
    }

    private var versionLabel: some View {
        Text(viewModel.appVersion())
            .font(.interRegular(size: 13))
            .foregroundStyle(Color("SecondaryGray").opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    // MARK: - Reusable Components

    private func sectionContainer<Content: View>(
        header: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header.uppercased())
                .font(.interRegular(size: 13))
                .foregroundStyle(Color("SecondaryGray"))
                .padding(.leading, 4)

            content()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if let footer {
                Text(footer)
                    .font(.interRegular(size: 13))
                    .foregroundStyle(Color("SecondaryGray").opacity(0.7))
                    .padding(.leading, 4)
                    .padding(.top, 2)
            }
        }
    }

    private func settingsRow(
        icon: String,
        title: String,
        trailing: String? = nil,
        showChevron: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            settingsIcon(icon)

            Text(title)
                .font(.interRegular(size: 16))
                .foregroundStyle(.primary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.interRegular(size: 15))
                    .foregroundStyle(Color("SecondaryGray"))
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func settingsIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17))
            .foregroundStyle(Color("SecondaryGray").opacity(0.7))
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("SecondaryGray").opacity(0.1))
            )
    }

    private var saveHistoryBinding: Binding<Bool> {
        Binding(
            get: { profileStore.profile?.saveHistory ?? true },
            set: { profileStore.profile?.saveHistory = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(UserProfileStore())
    }
}
