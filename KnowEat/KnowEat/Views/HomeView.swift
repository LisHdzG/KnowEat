//
//  HomeView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(MenuStore.self) private var menuStore
    @State private var viewModel = HomeViewModel()
    @State private var scanVM = MenuScanViewModel()
    @State private var selectedMenu: ScannedMenu?

    private var groupedMenus: [(String, [ScannedMenu])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: menuStore.menus) { menu -> String in
            if calendar.isDateInToday(menu.scannedAt) {
                return "Today"
            } else if calendar.isDateInYesterday(menu.scannedAt) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd MMM yyyy"
                return formatter.string(from: menu.scannedAt)
            }
        }

        let order: (String) -> Date = { key in
            grouped[key]?.first?.scannedAt ?? .distantPast
        }

        return grouped.sorted { order($0.key) > order($1.key) }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    titleSection
                        .padding(.horizontal, 24)

                    if let profile = profileStore.profile {
                        activeFiltersCard(for: profile)
                            .padding(.horizontal, 24)
                    }

                    menuListSection
                }
                .padding(.top, 8)
                .background(Color(.systemBackground))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .tint(Color("SecondaryGray"))
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            scanVM.openScanner()
                        } label: {
                            Image(systemName: "doc.viewfinder")
                        }
                        .tint(Color("PrimaryOrange"))
                    }
                }
                .fullScreenCover(isPresented: $scanVM.isShowingScanner) {
                    CameraView(
                        onPhotosReady: { images in
                            let allergenIds = profileStore.profile?.allergenIds ?? []
                            let language = profileStore.profile?.nativeLanguage ?? "English"
                            scanVM.handleScannedImages(images, userAllergenIds: allergenIds, userLanguage: language)
                        },
                        onCancelled: {
                            scanVM.handleScanCancelled()
                        }
                    )
                }
                .fullScreenCover(isPresented: $scanVM.showResults) {
                    if let menu = scanVM.scannedMenu {
                        MenuResultView(
                            menu: menu,
                            analyzedDishes: scanVM.analyzedDishes,
                            allergens: viewModel.allergens,
                            activeFilters: viewModel.activeFilters(for: profileStore.profile ?? UserProfile(nativeLanguage: "", allergenIds: [])),
                            onSave: { savedMenu in
                                menuStore.save(savedMenu)
                                scanVM.dismissResults()
                            },
                            onDismiss: { scanVM.dismissResults() }
                        )
                    }
                }
                .fullScreenCover(item: $selectedMenu) { menu in
                    let userAllergenIds = profileStore.profile?.allergenIds ?? []
                    let analyzed = AllergenChecker.analyze(menu: menu, userAllergenIds: userAllergenIds)
                    MenuResultView(
                        menu: menu,
                        analyzedDishes: analyzed,
                        allergens: viewModel.allergens,
                        activeFilters: viewModel.activeFilters(for: profileStore.profile ?? UserProfile(nativeLanguage: "", allergenIds: [])),
                        onDismiss: { selectedMenu = nil }
                    )
                }
                .alert("Error", isPresented: .init(
                    get: { scanVM.errorMessage != nil },
                    set: { if !$0 { scanVM.errorMessage = nil } }
                )) {
                    Button("OK") { scanVM.errorMessage = nil }
                } message: {
                    Text(scanVM.errorMessage ?? "")
                }
                .alert("Camera Access Required", isPresented: $scanVM.showPermissionDeniedAlert) {
                    Button("Open Settings") {
                        scanVM.openAppSettings()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("KnowEat needs camera access to scan menus. Please enable it in Settings.")
                }
            }

            if scanVM.isAnalyzing {
                LoaderView()
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
    }

    private var titleSection: some View {
        Text("Recent Menus")
            .font(.interSemiBold(size: 28))
            .foregroundStyle(Color("PrimaryOrange"))
    }

    private func activeFiltersCard(for profile: UserProfile) -> some View {
        let filters = viewModel.activeFilters(for: profile)
        return ActiveFiltersCard(filters: filters) {
            // TODO: Navigate to allergen editor
        }
    }

    // MARK: - Menu List

    private var menuListSection: some View {
        ScrollView(showsIndicators: false) {
            if menuStore.menus.isEmpty {
                emptyMenuPlaceholder
                    .padding(.top, 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedMenus, id: \.0) { dateLabel, menus in
                        Section {
                            ForEach(menus) { menu in
                                Button {
                                    selectedMenu = menu
                                } label: {
                                    MenuCell(menu: menu)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(dateLabel)
                                .font(.interSemiBold(size: 16))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyMenuPlaceholder: some View {
        ContentUnavailableView {
            Label("No menus yet", systemImage: "menucard")
                .foregroundStyle(Color("SecondaryGray").opacity(0.45))
        } description: {
            Text("Scan a menu to get started")
                .font(.interRegular(size: 15))
                .foregroundStyle(Color("SecondaryGray").opacity(0.5))
        } actions: {
            Button {
                scanVM.openScanner()
            } label: {
                Text("Scan Menu")
                    .font(.interSemiBold(size: 16))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("PrimaryOrange"))
        }
    }

}

#Preview {
    let profileStore = UserProfileStore()
    profileStore.profile = UserProfile(nativeLanguage: "English", allergenIds: ["gluten", "dairy", "peanuts"])
    return HomeView()
        .environment(profileStore)
        .environment(MenuStore())
}
