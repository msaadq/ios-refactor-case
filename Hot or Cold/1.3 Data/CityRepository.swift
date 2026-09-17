//
//  CityRepository.swift
//  Hot or Cold
//

import Foundation

/// Narrow surface for screens that only flip a star, so they need not depend on the catalogue.
protocol FavoriteToggling: AnyObject {
    func isFavorite(_ id: CityID) -> Bool
    func toggleFavorite(_ id: CityID)
}

/// `@MainActor` rather than an actor: `favorites` and `allCities` are read during SwiftUI
/// layout, where `await` is unavailable.
@MainActor
@Observable
final class CityRepository {
    typealias Sections = (favorites: [City], others: [City])

    private(set) var allCities: [City] = []
    /// Ordered by when each was favorited; the list surfaces them newest first.
    private(set) var favorites: [CityID] = []

    /// Membership and ordering in one lookup, rebuilt whenever `favorites` changes.
    /// Observed, not ignored: `isFavorite(_:)` reads it during layout, so rows must
    /// re-render the instant a star is toggled.
    private var favoriteRanks: [CityID: Int] = [:]

    @ObservationIgnored private let dataSource: CityDataSource
    @ObservationIgnored private let store: FavoritesStore

    init(dataSource: CityDataSource, store: FavoritesStore) {
        self.dataSource = dataSource
        self.store = store
        setFavorites((try? store.load()) ?? [])
    }

    func load() async throws {
        allCities = try await dataSource.loadCities()
    }

    func city(id: CityID) -> City? {
        allCities.first { $0.id == id }
    }

    /// Derived — `allCities` is never filtered in place, which is what made search destructive.
    func sections(matching query: String) async throws -> Sections {
        try await Self.sections(in: allCities, matching: query, favoriteRanks: favoriteRanks)
    }

    /// `@concurrent` forces this off the caller's actor. Without it, a `nonisolated async`
    /// function runs on the caller's executor — which would put a 200k scan on the main thread.
    @concurrent
    nonisolated static func sections(
        in cities: [City],
        matching query: String,
        favoriteRanks: [CityID: Int]
    ) async throws -> Sections {
        let needle = query.searchFolded
        var favorited: [(rank: Int, city: City)] = []
        var others: [City] = []

        for (index, city) in cities.enumerated() {
            // Superseded queries abandon their scan rather than compete with the current one.
            if index.isMultiple(of: 4096) { try Task.checkCancellation() }
            guard needle.isEmpty || city.searchKey.contains(needle) else { continue }

            if let rank = favoriteRanks[city.id] {
                favorited.append((rank, city))
            } else {
                others.append(city)
            }
        }

        // Most recently favorited first, not catalogue order.
        return (favorited.sorted { $0.rank > $1.rank }.map(\.city), others)
    }

    private func setFavorites(_ ids: [CityID]) {
        favorites = ids
        favoriteRanks = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
    }
}

extension CityRepository: FavoriteToggling {
    func isFavorite(_ id: CityID) -> Bool {
        favoriteRanks[id] != nil
    }

    /// Optimistic: the star flips before the write, and reverts if it fails.
    func toggleFavorite(_ id: CityID) {
        let previous = favorites
        setFavorites(isFavorite(id) ? favorites.filter { $0 != id } : favorites + [id])

        do {
            try store.save(favorites)
        } catch {
            setFavorites(previous)
        }
    }
}
