//
//  CityDetailViewModel.swift
//  Hot or Cold
//

import SwiftUI

@MainActor
protocol CityDetailViewModel: AnyObject {
    var city: City? { get }
    var temperature: RowTemperature { get }
    var isFavorite: Bool { get }

    func load() async
    func toggleFavorite()
}

/// Depends on `FavoriteToggling` rather than `CityRepository`: this screen flips a star, it has
/// no business reaching the catalogue. The coordinator resolves the route's id into the city.
@MainActor
@Observable
final class CityDetailViewModelImpl: CityDetailViewModel {
    let city: City?
    private(set) var temperature: RowTemperature = .loading

    @ObservationIgnored private let favorites: any FavoriteToggling
    @ObservationIgnored private let temperatureProvider: TemperatureProviding

    init(city: City?, favorites: any FavoriteToggling, temperatureProvider: TemperatureProviding) {
        self.city = city
        self.favorites = favorites
        self.temperatureProvider = temperatureProvider
    }

    /// Reads through to the repository, so a star flipped in the list is reflected here.
    var isFavorite: Bool {
        guard let city else { return false }
        return favorites.isFavorite(city.id)
    }

    func load() async {
        guard let city else { return }

        do {
            temperature = .loaded(try await temperatureProvider.temperature(for: city))
        } catch {
            temperature = .failed
        }
    }

    func toggleFavorite() {
        guard let city else { return }
        favorites.toggleFavorite(city.id)
    }
}
