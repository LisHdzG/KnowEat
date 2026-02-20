//
//  MenuStore.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI

@Observable
final class MenuStore {
    private static let storageKey = "saved_menus"

    private(set) var menus: [ScannedMenu] = []

    init() {
        load()
    }

    func save(_ menu: ScannedMenu) {
        menus.insert(menu, at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        menus.remove(atOffsets: offsets)
        persist()
    }

    func delete(_ menu: ScannedMenu) {
        menus.removeAll { $0.id == menu.id }
        persist()
    }

    func rename(_ menu: ScannedMenu, to newName: String) {
        guard let index = menus.firstIndex(where: { $0.id == menu.id }) else { return }
        menus[index].restaurant = newName
        persist()
    }

    func deleteAll() {
        menus.removeAll()
        persist()
    }

    func updateTranslation(_ menu: ScannedMenu, dishes: [Dish], menuLanguage: String) {
        guard let index = menus.firstIndex(where: { $0.id == menu.id }) else { return }
        menus[index].dishes = dishes
        menus[index].menuLanguage = menuLanguage
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([ScannedMenu].self, from: data) else { return }
        menus = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(menus) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
