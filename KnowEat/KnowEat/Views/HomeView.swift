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
    @State private var showSettings = false
    @State private var menuToRename: ScannedMenu?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var searchText = ""

    private var groupedMenus: [(String, [ScannedMenu])] {
        let calendar = Calendar.current
        let source = searchText.isEmpty
            ? menuStore.menus
            : menuStore.menus.filter { $0.restaurant.localizedCaseInsensitiveContains(searchText) }
        let grouped = Dictionary(grouping: source) { menu -> String in
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

                    menuListSection
                }
                .padding(.top, 8)
                .background(Color(.systemBackground))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .tint(Color("SecondaryGray"))
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Opens app settings and dietary profile")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            scanVM.openScanner()
                        } label: {
                            Image(systemName: "doc.viewfinder")
                        }
                        .tint(Color("PrimaryOrange"))
                        .accessibilityLabel("Scan menu")
                        .accessibilityHint("Opens the camera to scan a restaurant menu")
                    }
                }
                .fullScreenCover(isPresented: $scanVM.isShowingScanner) {
                    CameraView(
                        onPhotosReady: { images in
                            let profile = profileStore.profile ?? UserProfile(nativeLanguage: "English", allergenIds: [])
                            scanVM.handleScannedImages(images, profile: profile)
                        },
                        onCancelled: {
                            scanVM.handleScanCancelled()
                        }
                    )
                }
                .fullScreenCover(isPresented: $scanVM.showResults) {
                    if let menu = scanVM.scannedMenu {
                        let profile = profileStore.profile ?? UserProfile(nativeLanguage: "", allergenIds: [])
                        MenuResultView(
                            menu: menu,
                            analyzedDishes: scanVM.analyzedDishes,
                            allergens: viewModel.allDietaryItems,
                            filterGroups: viewModel.groupedFilters(for: profile),
                            onSave: { savedMenu in
                                menuStore.save(savedMenu)
                                scanVM.dismissResults()
                            },
                            onDismiss: { scanVM.dismissResults() }
                        )
                    }
                }
                .navigationDestination(isPresented: Binding(
                    get: { selectedMenu != nil },
                    set: { if !$0 { selectedMenu = nil } }
                )) {
                    if let menu = selectedMenu {
                        let profile = profileStore.profile ?? UserProfile(nativeLanguage: "", allergenIds: [])
                        let analyzed = AllergenChecker.analyze(menu: menu, profile: profile)
                        MenuResultView(
                            menu: menu,
                            analyzedDishes: analyzed,
                            allergens: viewModel.allDietaryItems,
                            filterGroups: viewModel.groupedFilters(for: profile),
                            onDismiss: { selectedMenu = nil },
                            isPushed: true
                        )
                    }
                }
                .fullScreenCover(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView()
                    }
                }
                .alert("Camera Access Required", isPresented: $scanVM.showPermissionDeniedAlert) {
                    Button("Open Settings") {
                        scanVM.openAppSettings()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("KnowEat needs camera access to scan menus. Please enable it in Settings.")
                }
                .alert("Rename Menu", isPresented: $showRenameAlert) {
                    TextField("Restaurant name", text: $renameText)
                        .onChange(of: renameText) { _, newValue in
                            if newValue.count > 20 { renameText = String(newValue.prefix(20)) }
                        }
                    Button("Save") {
                        if let menu = menuToRename,
                           !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                            menuStore.rename(menu, to: renameText)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            if scanVM.isAnalyzing {
                LoaderView(progress: scanVM.analysisProgress, stage: scanVM.analysisStage)
                    .transition(.opacity)
                    .ignoresSafeArea()
            }

        }
        .sheet(isPresented: Binding(
            get: { scanVM.errorMessage != nil },
            set: { if !$0 { scanVM.errorMessage = nil } }
        )) {
            scanErrorSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
        }
    }

    private var titleSection: some View {
        Text("Recent Menus")
            .font(.interSemiBold(size: 28))
            .foregroundStyle(Color("PrimaryOrange"))
    }

    // MARK: - Menu List

    private var menuListSection: some View {
        Group {
            if menuStore.menus.isEmpty {
                ScrollView {
                    emptyMenuPlaceholder
                        .padding(.top, 60)
                }
            } else {
                List {
                    if !menuStore.menus.isEmpty && groupedMenus.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(groupedMenus, id: \.0) { dateLabel, menus in
                        Section {
                            ForEach(menus) { menu in
                                Button {
                                    selectedMenu = menu
                                } label: {
                                    MenuCell(menu: menu)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(menu.restaurant), \(menu.dishes.count) dishes, \(menu.menuLanguage)")
                                .accessibilityHint("Opens menu analysis and allergen check")
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { menuStore.delete(menu) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        renameText = menu.restaurant
                                        menuToRename = menu
                                        showRenameAlert = true
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .tint(Color("PrimaryOrange"))
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                            }
                        } header: {
                            Text(dateLabel)
                                .font(.interSemiBold(size: 16))
                                .foregroundStyle(.secondary)
                                .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 0, trailing: 24))
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search menus...")
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Scan Error Sheet

    private var scanErrorSheet: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: errorIcon)
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                    )
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    Text(scanVM.errorTitle)
                        .font(.interSemiBold(size: 20))

                    Text(scanVM.errorMessage ?? "")
                        .font(.interRegular(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    errorTipRow(icon: "menucard", text: "Photograph a food menu with text")
                    errorTipRow(icon: "sun.max", text: "Use good lighting, avoid shadows")
                    errorTipRow(icon: "camera.metering.center.weighted", text: "Keep text in focus and fully visible")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    scanVM.retakePhoto()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Retake Photo")
                            .font(.interSemiBold(size: 16))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color("PrimaryOrange"), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var errorIcon: String {
        switch scanVM.errorTitle {
        case "No Menu Text Found": return "doc.text.magnifyingglass"
        case "Couldn't Read Text": return "text.magnifyingglass"
        case "Analysis Failed": return "fork.knife.circle"
        default: return "exclamationmark.triangle"
        }
    }

    private func errorTipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color("PrimaryOrange"))
                .frame(width: 22)

            Text(text)
                .font(.interRegular(size: 14))
                .foregroundStyle(.primary)
        }
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
            .accessibilityLabel("Scan menu")
            .accessibilityHint("Opens the camera to scan your first restaurant menu")
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
