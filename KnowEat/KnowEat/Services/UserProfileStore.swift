//
//  UserProfileStore.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

@Observable
final class UserProfileStore {
    private static let storageKey = "user_profile"

    var profile: UserProfile? {
        didSet { persist() }
    }

    var hasCompletedOnboarding: Bool {
        profile != nil
    }

    init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) else { return }
        profile = decoded
    }

    private func persist() {
        guard let profile,
              let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
