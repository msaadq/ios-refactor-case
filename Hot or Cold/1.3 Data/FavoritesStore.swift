//
//  FavoritesStore.swift
//  Hot or Cold
//

import Foundation
import Synchronization

/// Ordered: position is the order the user favorited them, so the array is the data,
/// not an arbitrary serialisation of a set. Throws so a failed write can drive rollback.
nonisolated protocol FavoritesStore: Sendable {
    func load() throws -> [CityID]
    func save(_ ids: [CityID]) throws
}

/// `@unchecked` because `UserDefaults` is documented thread-safe but not marked `Sendable`.
nonisolated struct UserDefaultsFavoritesStore: FavoritesStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "favorites.cityIDs") {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> [CityID] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([CityID].self, from: data)
    }

    func save(_ ids: [CityID]) throws {
        defaults.set(try JSONEncoder().encode(ids), forKey: key)
    }
}

nonisolated final class InMemoryFavoritesStore: FavoritesStore {
    private let storage: Mutex<[CityID]>
    private let failOnSave: Bool

    init(initial: [CityID] = [], failOnSave: Bool = false) {
        self.storage = Mutex(initial)
        self.failOnSave = failOnSave
    }

    struct SaveFailure: Error {}

    func load() throws -> [CityID] {
        storage.withLock { $0 }
    }

    func save(_ ids: [CityID]) throws {
        if failOnSave { throw SaveFailure() }
        storage.withLock { $0 = ids }
    }
}
