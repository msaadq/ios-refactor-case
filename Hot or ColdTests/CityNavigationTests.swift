//
//  CityNavigationTests.swift
//  Hot or ColdTests
//

import Foundation
import Testing
@testable import Hot_or_Cold

@MainActor
@Suite("City navigation")
struct CityNavigationTests {
    /// The shipping coordinator over test doubles, so the resolution path under test is the
    /// one the app uses rather than the preview double's fixture lookup.
    private func makeCoordinator() -> (coordinator: LiveCityCoordinator, repository: CityRepository) {
        let repository = CityRepository(dataSource: StubCityDataSource(), store: InMemoryFavoritesStore())
        return (
            LiveCityCoordinator(
                repository: repository,
                temperatureProvider: TemperatureRepository(client: StubWeatherClient())
            ),
            repository
        )
    }

    /// Previously the destination existed only inside a rendering closure, so there was nothing
    /// to assert on. Moving the path onto the ViewModel makes a push ordinary state.
    @Test("Selecting a city pushes its route onto the path")
    func selectingCityPushesDetailRoute() async throws {
        let viewModel = makeCoordinator().coordinator.makeListViewModel()
        await viewModel.load()

        viewModel.handle(.didSelectCity(CityID("tokyo-jp")))

        #expect(viewModel.navigationPath == [.detail(CityID("tokyo-jp"))])
    }

    @Test("A route's id resolves to the city the detail screen shows")
    func detailResolvesTheRoutedCity() async throws {
        let (coordinator, repository) = makeCoordinator()
        try await repository.load()

        #expect(coordinator.makeDetailViewModel(for: CityID("tromso-no")).city?.name == "Tromsø")
    }

    /// Why the route carries a `CityID` and not a `City`: a pushed value would be a snapshot
    /// taken before the star was flipped.
    @Test("The detail screen reads favorites live, not from a pushed snapshot")
    func detailReflectsFavoriteToggledInList() async throws {
        let (coordinator, _) = makeCoordinator()
        let list = coordinator.makeListViewModel()
        await list.load()

        list.handle(.didToggleFavorite(CityID("oslo-no")))

        #expect(coordinator.makeDetailViewModel(for: CityID("oslo-no")).isFavorite)
    }

    /// The other direction, and the reason the detail screen can depend on `FavoriteToggling`
    /// alone. Re-sectioning matters as much as the flag: rows repaint from the observed
    /// repository on their own, but the favorites/others split lives in `viewState`, so a city
    /// would otherwise read as favorited while still sitting under "All cities".
    @Test("Favoriting from the detail screen re-sections the list on return")
    func detailFavoriteReachesTheListOnReturn() async throws {
        let (coordinator, repository) = makeCoordinator()
        let list = coordinator.makeListViewModel()
        await list.load()
        let paris = try #require(repository.city(id: CityID("paris-fr")))

        coordinator.makeDetailViewModel(for: paris.id).toggleFavorite()
        await list.load() // what `.task` does when the detail screen pops

        #expect(list.isFavorite(paris))
        guard case .loaded(let favorites, let others, _) = list.viewState else {
            Issue.record("expected .loaded, got \(list.viewState)")
            return
        }
        #expect(favorites.map(\.id) == [paris.id])
        #expect(!others.contains { $0.id == paris.id })
    }
}
