//
//  FavoritesStore.swift
//  Hot or Cold
//

import Foundation
import Synchronization

/// Throws rather than returning optionals so a failed write can drive the caller's rollback.
nonisolated protocol FavoritesStore: Sendable {
    func load() throws -> Set<CityID>
    func save(_ ids: Set<CityID>) throws
}

/// `@unchecked` because `UserDefaults` is documented thread-safe but not marked `Sendable`.
nonisolated struct UserDefaultsFavoritesStore: FavoritesStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "favorites.cityIDs") {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> Set<CityID> {
        guard let data = defaults.data(forKey: key) else { return [] }
        return Set(try JSONDecoder().decode([CityID].self, from: data))
    }

    func save(_ ids: Set<CityID>) throws {
        let sorted = ids.map(\.rawValue).sorted().map(CityID.init)
        defaults.set(try JSONEncoder().encode(sorted), forKey: key)
    }
}

nonisolated final class InMemoryFavoritesStore: FavoritesStore {
    private let storage: Mutex<Set<CityID>>
    private let failOnSave: Bool

    init(initial: Set<CityID> = [], failOnSave: Bool = false) {
        self.storage = Mutex(initial)
        self.failOnSave = failOnSave
    }

    struct SaveFailure: Error {}

    func load() throws -> Set<CityID> {
        storage.withLock { $0 }
    }

    func save(_ ids: Set<CityID>) throws {
        if failOnSave { throw SaveFailure() }
        storage.withLock { $0 = ids }
    }
}
