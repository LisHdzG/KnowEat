//
//  HomeView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(UserProfileStore.self) private var profileStore

    var body: some View {
        VStack(spacing: 24) {
            Text("Home")
                .font(.interSemiBold(size: 28))

            if let profile = profileStore.profile {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Native Language: \(profile.nativeLanguage)")
                        .font(.interRegular(size: 16))

                    Text("Allergens: \(profile.allergenIds.joined(separator: ", "))")
                        .font(.interRegular(size: 16))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.top, 60)
    }
}

#Preview {
    let store = UserProfileStore()
    store.profile = UserProfile(nativeLanguage: "English", allergenIds: ["gluten", "dairy", "peanuts"])
    return HomeView()
        .environment(store)
}
