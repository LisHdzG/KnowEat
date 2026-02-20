//
//  SettingsView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(MenuStore.self) private var menuStore
    @State private var viewModel = SettingsViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showFinalConfirmation = false

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
            footer: "KnowEat will highlight these allergens when scanning menus."
        ) {
            NavigationLink {
                allergenEditorView
            } label: {
                let count = profileStore.profile?.allergenIds.count ?? 0
                settingsRow(
                    icon: "exclamationmark.shield.fill",
                    title: "My Allergens",
                    trailing: count > 0 ? "\(count) active" : nil,
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    private let allergenColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var allergenEditorView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select the allergens you want KnowEat to watch for when scanning menus.")
                    .font(.interRegular(size: 15))
                    .foregroundStyle(Color("SecondaryGray"))
                    .lineSpacing(3)
                    .padding(.horizontal, 24)

                LazyVGrid(columns: allergenColumns, spacing: 12) {
                    ForEach(viewModel.allergens) { allergen in
                        AllergenChipView(
                            allergen: allergen,
                            isSelected: viewModel.isSelected(allergen.id)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggleAllergen(allergen.id)
                                profileStore.profile?.allergenIds = Array(viewModel.selectedAllergens)
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
        .navigationTitle("My Allergens")
        .navigationBarTitleDisplayMode(.large)
    }

    private var historySection: some View {
        sectionContainer(header: "History") {
            VStack(spacing: 0) {
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

                if !menuStore.menus.isEmpty {
                    Divider()
                        .padding(.leading, 62)

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        settingsRow(
                            icon: "trash.fill",
                            title: "Delete all menus",
                            trailing: "\(menuStore.menus.count)"
                        )
                    }
                    .buttonStyle(.plain)
                    .alert("Delete All Menus?", isPresented: $showDeleteConfirmation) {
                        Button("Delete All", role: .destructive) {
                            showFinalConfirmation = true
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all \(menuStore.menus.count) saved menus.")
                    }
                    .alert("Are you sure?", isPresented: $showFinalConfirmation) {
                        Button("Yes, delete everything", role: .destructive) {
                            withAnimation { menuStore.deleteAll() }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This action cannot be undone.")
                    }
                }
            }
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
