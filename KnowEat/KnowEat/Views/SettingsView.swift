//
//  SettingsView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(MenuStore.self) private var menuStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SettingsViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showFinalConfirmation = false

    private var strings: AppStrings {
        AppStrings(profileStore.profile?.nativeLanguage ?? "English")
    }

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
        .background(Color(.systemBackground))
        .navigationTitle(strings.settings)
        .navigationBarTitleDisplayMode(.large)
        .tint(Color("PrimaryOrange"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .tint(Color("SecondaryGray"))
                .accessibilityLabel(strings.close)
                .accessibilityHint(strings.closeSettingsHint)
            }
        }
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
        sectionContainer(header: strings.languageSection, footer: strings.languageChangeNote) {
            Button {
                viewModel.showLanguagePicker = true
            } label: {
                settingsRow(
                    icon: "character.book.closed",
                    title: strings.nativeLanguage,
                    trailing: viewModel.selectedLanguage,
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(strings.nativeLanguage), \(viewModel.selectedLanguage)")
            .accessibilityHint(strings.languagePickerHintSettings)
        }
    }

    private var dietarySection: some View {
        sectionContainer(header: strings.dietaryProfile) {
            VStack(spacing: 0) {
                dietaryRow(
                    icon: "exclamationmark.shield.fill",
                    title: strings.allergens,
                    editorTitle: strings.myAllergens,
                    description: strings.selectAllergensDesc,
                    items: viewModel.allergens,
                    category: .allergens,
                    count: profileStore.profile?.allergenIds.count ?? 0
                )

                sectionDivider

                dietaryRow(
                    icon: "pills.fill",
                    title: strings.intolerances,
                    editorTitle: strings.intolerances,
                    description: strings.selectIntolerancesDesc,
                    items: viewModel.intolerances,
                    category: .intolerances,
                    count: profileStore.profile?.intoleranceIds.count ?? 0
                )

                sectionDivider

                dietaryRow(
                    icon: "heart.text.clipboard.fill",
                    title: strings.medicalConditions,
                    editorTitle: strings.medicalConditions,
                    description: strings.selectConditionsDesc,
                    items: viewModel.conditions,
                    category: .conditions,
                    count: profileStore.profile?.conditionIds.count ?? 0
                )

                sectionDivider

                dietaryRow(
                    icon: "fork.knife",
                    title: strings.diets,
                    editorTitle: strings.diets,
                    description: strings.selectDietsDesc,
                    items: viewModel.diets,
                    category: .diets,
                    count: profileStore.profile?.dietIds.count ?? 0
                )

                sectionDivider

                dietaryRow(
                    icon: "figure.and.child.holdinghands",
                    title: strings.situations,
                    editorTitle: strings.situations,
                    description: strings.selectSituationsDesc,
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
                trailing: count > 0 ? strings.activeCount(count) : nil,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count > 0 ? "\(count) selected" : "none selected")")
        .accessibilityHint("Opens editor to configure your \(title.lowercased())")
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
                            isSelected: viewModel.isSelected(item.id, category: category),
                            displayName: strings.localizedAllergenName(item.id)
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
        .background(Color(.systemBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }

    private func syncProfile(category: DietaryCategory) {
        guard var profile = profileStore.profile else { return }
        let ids = Array(viewModel.selectedIds(for: category))
        switch category {
        case .allergens: profile.allergenIds = ids
        case .intolerances: profile.intoleranceIds = ids
        case .conditions: profile.conditionIds = ids
        case .diets: profile.dietIds = ids
        case .situations: profile.situationIds = ids
        }
        profileStore.profile = profile
    }

    private var historySection: some View {
        sectionContainer(header: strings.history, footer: strings.dataLocalNote) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    settingsIcon("clock.arrow.circlepath")

                    Text(strings.saveHistory)
                        .font(.interRegular(size: 16))

                    Spacer()

                    Toggle("", isOn: saveHistoryBinding)
                        .labelsHidden()
                        .tint(Color("PrimaryOrange"))
                        .accessibilityLabel(strings.saveHistory)
                        .accessibilityHint("When on, scanned menus are saved to your history")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if !menuStore.menus.isEmpty {
                    Divider()
                        .padding(.leading, 62)

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        settingsRow(
                            icon: "trash.fill",
                            title: strings.deleteAllMenus,
                            trailing: "\(menuStore.menus.count)"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(strings.deleteAllMenusA11yLabel(menuStore.menus.count))
                    .accessibilityHint(strings.deleteAllMenusHint)
                    .alert(strings.deleteAllMenusConfirm, isPresented: $showDeleteConfirmation) {
                        Button(strings.deleteAllButton, role: .destructive) {
                            showFinalConfirmation = true
                        }
                        Button(strings.cancel, role: .cancel) {}
                    } message: {
                        Text(strings.deleteAllMessage(menuStore.menus.count))
                    }
                    .alert(strings.areYouSure, isPresented: $showFinalConfirmation) {
                        Button(strings.yesDeleteAll, role: .destructive) {
                            if reduceMotion {
                                menuStore.deleteAll()
                            } else {
                                withAnimation { menuStore.deleteAll() }
                            }
                        }
                        Button(strings.cancel, role: .cancel) {}
                    } message: {
                        Text(strings.cannotBeUndone)
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        sectionContainer(header: strings.about) {
            VStack(spacing: 0) {
                Button {
                    if let urlString = PrivacyConfigService.shared.privacyNotice?.url,
                       let url = URL(string: urlString) {
                        openURL(url)
                    }
                } label: {
                    settingsRow(
                        icon: "lock.fill",
                        title: strings.privacyPolicy,
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(strings.privacyPolicy)
                .accessibilityHint(strings.opensPrivacyInSafari)

                Divider()
                    .padding(.leading, 62)

                Button {
                    requestReview()
                } label: {
                    settingsRow(
                        icon: "star.fill",
                        title: strings.rateKnowEat
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(strings.rateKnowEat)
                .accessibilityHint(strings.rateKnowEatHint)
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
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

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
            .environment(MenuStore())
    }
}
