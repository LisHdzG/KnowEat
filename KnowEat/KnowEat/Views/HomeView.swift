//
//  HomeView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(UserProfileStore.self) private var profileStore
    @State private var viewModel = HomeViewModel()

    var body: some View {
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
                    Button {
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .tint(Color("SecondaryGray"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "doc.viewfinder")
                    }
                    .tint(Color("PrimaryOrange"))
                }
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

        return Button {
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Active filters")
                        .font(.interRegular(size: 13))
                        .foregroundStyle(Color("SecondaryGray"))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color("SecondaryGray"))
                }

                if filters.isEmpty {
                    Text("No filters set")
                        .font(.interRegular(size: 13))
                        .foregroundStyle(Color("SecondaryGray").opacity(0.6))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters) { allergen in
                                Text(allergen.name)
                                    .font(.interMedium(size: 13))
                                    .foregroundStyle(.white)
                                    .fixedSize()
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(Color("PrimaryOrange"))
                                    )
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private var menuListSection: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
            }
            .padding(.horizontal, 24)
        }
        .frame(maxHeight: .infinity)
        .overlay {
            emptyMenuPlaceholder
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
    let store = UserProfileStore()
    store.profile = UserProfile(nativeLanguage: "English", allergenIds: ["gluten", "dairy", "peanuts"])
    return HomeView()
        .environment(store)
}
