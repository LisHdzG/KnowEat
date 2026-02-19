//
//  Allergen.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import Foundation

struct Allergen: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let icon: String
}
