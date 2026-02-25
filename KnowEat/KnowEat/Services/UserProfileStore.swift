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
    private static let disclaimerKey = "has_accepted_analysis_disclaimer"
    private static let privacyVersionKey = "accepted_privacy_version"

    var profile: UserProfile? {
        didSet { persist() }
    }

    var hasCompletedOnboarding: Bool {
        profile != nil
    }

    private(set) var hasAcceptedAnalysisDisclaimer: Bool = false {
        didSet {
            UserDefaults.standard.set(hasAcceptedAnalysisDisclaimer, forKey: Self.disclaimerKey)
        }
    }

    private(set) var acceptedPrivacyVersion: String? {
        didSet {
            UserDefaults.standard.set(acceptedPrivacyVersion, forKey: Self.privacyVersionKey)
        }
    }

    func needsPrivacyUpdate(remoteVersion: String?) -> Bool {
        guard let remoteVersion else { return false }
        guard let accepted = acceptedPrivacyVersion else { return true }
        return accepted != remoteVersion
    }

    init() {
        load()
        loadDisclaimerState()
        loadAcceptedPrivacyVersion()
        migrateExistingUserDisclaimer()
    }

    private func loadDisclaimerState() {
        hasAcceptedAnalysisDisclaimer = UserDefaults.standard.bool(forKey: Self.disclaimerKey)
    }

    private func loadAcceptedPrivacyVersion() {
        acceptedPrivacyVersion = UserDefaults.standard.string(forKey: Self.privacyVersionKey)
    }

    /// Existing users (profile loaded from storage before disclaimer feature) skip the disclaimer.
    private func migrateExistingUserDisclaimer() {
        guard profile != nil else { return }
        if UserDefaults.standard.object(forKey: Self.disclaimerKey) == nil {
            hasAcceptedAnalysisDisclaimer = true
        }
    }

    func acceptAnalysisDisclaimer() {
        hasAcceptedAnalysisDisclaimer = true
        if let version = PrivacyConfigService.shared.privacyNotice?.version {
            acceptedPrivacyVersion = version
        }
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
