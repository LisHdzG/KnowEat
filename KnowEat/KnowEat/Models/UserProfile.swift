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
}
