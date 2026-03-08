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
    @State private var showProfileSetup = false

    private var strings: AppStrings {
        AppStrings(profileStore.profile?.nativeLanguage ?? "English")
    }

    private var groupedMenus: [(String, [ScannedMenu])] {
        let calendar = Calendar.current
        let source = searchText.isEmpty
            ? menuStore.menus
            : menuStore.menus.filter { $0.restaurant.localizedCaseInsensitiveContains(searchText) }
        let grouped = Dictionary(grouping: source) { menu -> String in
            if calendar.isDateInToday(menu.scannedAt) {
                return strings.today
            } else if calendar.isDateInYesterday(menu.scannedAt) {
                return strings.yesterday
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

                    if profileStore.profile == nil {
                        profileSetupBanner
                            .padding(.horizontal, 24)
                    }

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
                        .accessibilityLabel(strings.settings)
                        .accessibilityHint("Opens app settings and dietary profile")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            scanVM.openScanner()
                        } label: {
                            Image(systemName: "doc.viewfinder")
                        }
                        .tint(Color("PrimaryOrange"))
                        .accessibilityLabel(strings.scanMenu)
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
                .onChange(of: scanVM.showResults) { _, new in
                    if new, let menu = scanVM.scannedMenu {
                        selectedMenu = menu
                    }
                }
                .navigationDestination(isPresented: Binding(
                    get: { selectedMenu != nil },
                    set: { isPresented in
                        if !isPresented {
                            let id = selectedMenu?.id
                            selectedMenu = nil
                            if id == scanVM.scannedMenu?.id {
                                scanVM.dismissResults()
                            }
                        }
                    }
                )) {
                    if let menu = selectedMenu {
                        let profile = profileStore.profile ?? UserProfile(nativeLanguage: "", allergenIds: [])
                        let isFromScan = menu.id == scanVM.scannedMenu?.id
                        let analyzed = isFromScan ? scanVM.analyzedDishes : AllergenChecker.analyze(menu: menu, profile: profile)
                        MenuResultView(
                            menu: menu,
                            analyzedDishes: analyzed,
                            allergens: viewModel.allDietaryItems,
                            filterGroups: viewModel.groupedFilters(for: profile),
                            onSave: isFromScan ? { savedMenu in
                                menuStore.save(savedMenu)
                                selectedMenu = nil
                                scanVM.dismissResults()
                            } : nil,
                            onDismiss: { },
                            isPushed: true
                        )
                    }
                }
                .fullScreenCover(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView()
                    }
                }
                .alert(strings.cameraAccessRequired, isPresented: $scanVM.showPermissionDeniedAlert) {
                    Button(strings.openSettings) {
                        scanVM.openAppSettings()
                    }
                    Button(strings.cancel, role: .cancel) {}
                } message: {
                    Text(strings.cameraAccessMessage)
                }
                .alert(strings.renameMenu, isPresented: $showRenameAlert) {
                    TextField(strings.restaurantName, text: $renameText)
                        .onChange(of: renameText) { _, newValue in
                            if newValue.count > 20 { renameText = String(newValue.prefix(20)) }
                        }
                    Button(strings.save) {
                        if let menu = menuToRename,
                           !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                            menuStore.rename(menu, to: renameText)
                        }
                    }
                    Button(strings.cancel, role: .cancel) {}
                }
            }

            if scanVM.isAnalyzing {
                LoaderView(progress: scanVM.analysisProgress, stage: scanVM.analysisStage)
                    .ignoresSafeArea()
                    .zIndex(10)
            }

        }
        .sheet(isPresented: $showProfileSetup) {
            DietaryProfileEditorView()
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
        Text(strings.recentMenus)
            .font(.interSemiBold(size: 28))
            .foregroundStyle(Color("PrimaryOrange"))
    }

    // MARK: - Profile Setup Banner

    private var profileSetupBanner: some View {
        Button {
            showProfileSetup = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 30))
                    .foregroundStyle(Color("PrimaryOrange"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(strings.setupProfileTitle)
                        .font(.interSemiBold(size: 15))
                        .foregroundStyle(.primary)

                    Text(strings.setupProfileSubtitle)
                        .font(.interRegular(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color("PrimaryOrange").opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color("PrimaryOrange").opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(strings.setupProfileTitle)
        .accessibilityHint(strings.setupProfileSubtitle)
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
                                .accessibilityLabel("\(menu.restaurant), \(strings.dishesCount(menu.dishes.count))")
                                .accessibilityHint("Opens menu analysis and allergen check")
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { menuStore.delete(menu) }
                                    } label: {
                                        Label(strings.delete, systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        renameText = menu.restaurant
                                        menuToRename = menu
                                        showRenameAlert = true
                                    } label: {
                                        Label(strings.rename, systemImage: "pencil")
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
                .searchable(text: $searchText, prompt: strings.searchMenus)
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
                    errorTipRow(icon: "menucard", text: strings.photographMenuTip)
                    errorTipRow(icon: "sun.max", text: strings.goodLightingTip)
                    errorTipRow(icon: "camera.metering.center.weighted", text: strings.keepFocusTip)
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
                        Text(strings.retakePhoto)
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
        let title = scanVM.errorTitle
        if title == strings.noMenuTextFoundTitle { return "doc.text.magnifyingglass" }
        if title == strings.couldntReadTextTitle { return "text.magnifyingglass" }
        if title == strings.analysisFailedTitle { return "fork.knife.circle" }
        return "exclamationmark.triangle"
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
            Label(strings.noMenusYet, systemImage: "menucard")
                .foregroundStyle(Color("SecondaryGray").opacity(0.45))
        } description: {
            Text(strings.scanToGetStarted)
                .font(.interRegular(size: 15))
                .foregroundStyle(Color("SecondaryGray").opacity(0.5))
        } actions: {
            Button {
                scanVM.openScanner()
            } label: {
                Text(strings.scanMenu)
                    .font(.interSemiBold(size: 16))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("PrimaryOrange"))
            .accessibilityLabel(strings.scanMenu)
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
