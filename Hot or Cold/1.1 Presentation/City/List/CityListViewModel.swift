//
//  CityListViewModel.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

@MainActor
protocol CityListViewModel {
    var cities: [City] { get }
    // TODO: When filtering favorites, treat the list of cities as if it had 200.000 entries. Make sure the UI would remain responsive.
    var favorites: Set<CityID> { get }
    var isLoading: Bool { get }

    func temperature(for city: City) -> Celsius?

    func loadCities() async
    func warmUpCache() async
    func fetchTemperature(for city: City) async
    func toggleFavorite(_ city: City)
    func filterCities(query: String)
}

@MainActor
@Observable
final class CityListViewModelImpl: CityListViewModel {
    private(set) var isLoading = false
    private(set) var temperatures: [CityID: Celsius] = [:]
    private var query = ""

    @ObservationIgnored private let repository: CityRepository
    @ObservationIgnored private let temperatureProvider: TemperatureProviding

    init(repository: CityRepository, temperatureProvider: TemperatureProviding) {
        self.repository = repository
        self.temperatureProvider = temperatureProvider
    }

    /// Derived on read, so the catalogue is never filtered in place.
    var cities: [City] {
        repository.cities(matching: query)
    }

    var favorites: Set<CityID> {
        repository.favorites
    }

    func temperature(for city: City) -> Celsius? {
        temperatures[city.id]
    }

    func loadCities() async {
        isLoading = true
        await repository.load()
        isLoading = false
    }

    func warmUpCache() async {
        await temperatureProvider.prefetch(repository.allCities)
    }

    func fetchTemperature(for city: City) async {
        guard temperatures[city.id] == nil else { return }
        if let value = try? await temperatureProvider.temperature(for: city) {
            temperatures[city.id] = value
        }
    }

    func toggleFavorite(_ city: City) {
        repository.toggleFavorite(city.id)
    }

    func filterCities(query: String) {
        // TODO: Implement this search. The search should be debounced for 300 ms to avoid filtering on every keystroke.
        self.query = query
    }
}
