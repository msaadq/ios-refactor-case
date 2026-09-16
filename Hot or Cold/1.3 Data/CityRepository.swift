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

/// `@MainActor` rather than an actor: `sections(matching:)` and `isFavorite(_:)` are read
/// during SwiftUI layout, where `await` is unavailable.
@MainActor
@Observable
final class CityRepository {
    private(set) var allCities: [City] = []
    private(set) var favorites: Set<CityID> = []

    @ObservationIgnored private let dataSource: CityDataSource
    @ObservationIgnored private let store: FavoritesStore

    init(dataSource: CityDataSource, store: FavoritesStore) {
        self.dataSource = dataSource
        self.store = store
        self.favorites = (try? store.load()) ?? []
    }

    func load() async {
        allCities = (try? await dataSource.loadCities()) ?? []
    }

    func city(id: CityID) -> City? {
        allCities.first { $0.id == id }
    }

    /// Derived — `allCities` is never filtered in place, which is what made search destructive.
    func cities(matching query: String) -> [City] {
        Self.filter(allCities, query: query)
    }

    func sections(matching query: String) -> (favorites: [City], others: [City]) {
        let matches = cities(matching: query)
        var favorited: [City] = []
        var others: [City] = []
        for city in matches {
            if favorites.contains(city.id) {
                favorited.append(city)
            } else {
                others.append(city)
            }
        }
        return (favorited, others)
    }

    /// `nonisolated` so a large catalogue can be filtered off the main actor.
    nonisolated static func filter(_ cities: [City], query: String) -> [City] {
        let needle = query.searchFolded
        guard !needle.isEmpty else { return cities }
        return cities.filter { $0.searchKey.contains(needle) }
    }
}

extension CityRepository: FavoriteToggling {
    func isFavorite(_ id: CityID) -> Bool {
        favorites.contains(id)
    }

    func toggleFavorite(_ id: CityID) {
        favorites.formSymmetricDifference([id])
        try? store.save(favorites)
    }
}
