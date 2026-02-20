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
    var intoleranceIds: [String]
    var conditionIds: [String]
    var dietIds: [String]
    var situationIds: [String]
    var saveHistory: Bool

    init(
        nativeLanguage: String,
        allergenIds: [String],
        intoleranceIds: [String] = [],
        conditionIds: [String] = [],
        dietIds: [String] = [],
        situationIds: [String] = [],
        saveHistory: Bool = true
    ) {
        self.nativeLanguage = nativeLanguage
        self.allergenIds = allergenIds
        self.intoleranceIds = intoleranceIds
        self.conditionIds = conditionIds
        self.dietIds = dietIds
        self.situationIds = situationIds
        self.saveHistory = saveHistory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nativeLanguage = try container.decode(String.self, forKey: .nativeLanguage)
        allergenIds = try container.decode([String].self, forKey: .allergenIds)
        intoleranceIds = try container.decodeIfPresent([String].self, forKey: .intoleranceIds) ?? []
        conditionIds = try container.decodeIfPresent([String].self, forKey: .conditionIds) ?? []
        dietIds = try container.decodeIfPresent([String].self, forKey: .dietIds) ?? []
        situationIds = try container.decodeIfPresent([String].self, forKey: .situationIds) ?? []
        saveHistory = try container.decodeIfPresent(Bool.self, forKey: .saveHistory) ?? true
    }

    var allRestrictionCount: Int {
        allergenIds.count + intoleranceIds.count + conditionIds.count + dietIds.count + situationIds.count
    }
}
