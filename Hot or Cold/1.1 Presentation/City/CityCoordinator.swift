//
//  CityCoordinator.swift
//  Hot or Cold
//

import Foundation

/// An identity token, not a data carrier. Carrying a whole `City` would capture a snapshot at
/// push time and tie navigation identity to `City`'s `Hashable`, which includes `searchKey`.
nonisolated enum CityRoute: Hashable {
    case detail(CityID)
}

/// Turns a route into the screen it names, so views never construct their own dependencies.
@MainActor
protocol CityCoordinator {
    func makeListViewModel() -> any CityListViewModel
    func makeDetailViewModel(for id: CityID) -> any CityDetailViewModel
}

// MARK: - Live

@MainActor
struct LiveCityCoordinator: CityCoordinator {
    private let repository: CityRepository
    private let temperatureProvider: TemperatureProviding

    init(repository: CityRepository, temperatureProvider: TemperatureProviding) {
        self.repository = repository
        self.temperatureProvider = temperatureProvider
    }

    /// Composition root — the only place concrete implementations are chosen.
    static func makeDefault() -> LiveCityCoordinator {
        var dataSource: CityDataSource = BundledCityDataSource()
        #if DEBUG
        if let synthetic = SyntheticCityDataSource.fromLaunchArguments {
            dataSource = synthetic
        }
        #endif

        return LiveCityCoordinator(
            repository: CityRepository(dataSource: dataSource, store: UserDefaultsFavoritesStore()),
            temperatureProvider: TemperatureRepository(client: URLSessionWeatherClient())
        )
    }

    func makeListViewModel() -> any CityListViewModel {
        CityListViewModelImpl(repository: repository, temperatureProvider: temperatureProvider)
    }

    /// Resolves the id here so the detail screen depends on `FavoriteToggling` rather than
    /// on the whole catalogue.
    func makeDetailViewModel(for id: CityID) -> any CityDetailViewModel {
        CityDetailViewModelImpl(
            city: repository.city(id: id),
            favorites: repository,
            temperatureProvider: temperatureProvider
        )
    }
}

// MARK: - Preview

#if DEBUG
@MainActor
struct PreviewCityCoordinator: CityCoordinator {
    private let cities: [City]
    private let repository: CityRepository
    private let temperatureProvider: TemperatureProviding

    init(
        cities: [City] = StubCityDataSource.sample,
        favorites: [CityID] = [],
        temperature: Result<Celsius, WeatherError> = .success(15.1)
    ) {
        self.cities = cities
        self.repository = CityRepository(
            dataSource: StubCityDataSource(cities),
            store: InMemoryFavoritesStore(initial: favorites)
        )
        self.temperatureProvider = TemperatureRepository(client: StubWeatherClient(result: temperature))
    }

    func makeListViewModel() -> any CityListViewModel {
        CityListViewModelImpl(repository: repository, temperatureProvider: temperatureProvider)
    }

    /// Resolves from the fixture rather than the repository, so a detail preview renders
    /// without a list having loaded the catalogue first.
    func makeDetailViewModel(for id: CityID) -> any CityDetailViewModel {
        CityDetailViewModelImpl(
            city: cities.first { $0.id == id },
            favorites: repository,
            temperatureProvider: temperatureProvider
        )
    }
}
#endif
