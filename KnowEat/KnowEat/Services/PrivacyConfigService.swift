//
//  PrivacyConfigService.swift
//  KnowEat
//
//  Created by Lisette HG on 25/02/26.
//

import Foundation
import FirebaseRemoteConfig

struct PrivacyNotice {
    let version: String
    let url: String
}

@Observable
final class PrivacyConfigService {
    static let shared = PrivacyConfigService()

    private(set) var privacyNotice: PrivacyNotice?
    private(set) var isLoaded = false

    private let remoteConfig = RemoteConfig.remoteConfig()

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
    }

    func fetch() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            if status == .successFetchedFromRemote || status == .successUsingPreFetchedData {
                parsePrivacyNotice()
            }
        } catch {
            parsePrivacyNotice()
        }
        isLoaded = true
    }

    private func parsePrivacyNotice() {
        let json = remoteConfig.configValue(forKey: "privacyNotice").stringValue ?? ""
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = dict["version"] as? String,
              let url = dict["url"] as? String else { return }
        privacyNotice = PrivacyNotice(version: version, url: url)
    }
}
