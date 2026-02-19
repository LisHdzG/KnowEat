//
//  UserProfile.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

struct UserProfile: Codable {
    var nativeLanguage: String
    var allergenIds: [String]
    var saveHistory: Bool

    init(nativeLanguage: String, allergenIds: [String], saveHistory: Bool = true) {
        self.nativeLanguage = nativeLanguage
        self.allergenIds = allergenIds
        self.saveHistory = saveHistory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nativeLanguage = try container.decode(String.self, forKey: .nativeLanguage)
        allergenIds = try container.decode([String].self, forKey: .allergenIds)
        saveHistory = try container.decodeIfPresent(Bool.self, forKey: .saveHistory) ?? true
    }
}
