//
//  CityListViewModelTests.swift
//  Hot or ColdTests
//

import Foundation
import Testing
@testable import Hot_or_Cold

@MainActor
@Suite("City list view model")
struct CityListViewModelTests {
    private func makeViewModel(cities: [City] = StubCityDataSource.sample) -> CityListViewModelImpl {
        CityListViewModelImpl(
            repository: CityRepository(dataSource: StubCityDataSource(cities), store: InMemoryFavoritesStore()),
            temperatureProvider: TemperatureRepository(client: StubWeatherClient())
        )
    }

    private static func loaded(
        _ state: CityListViewState
    ) -> (favorites: [City], others: [City], totalOthers: Int)? {
        guard case .loaded(let favorites, let others, let totalOthers) = state else { return nil }
        return (favorites, others, totalOthers)
    }

    @Test("Search waits out the debounce interval before filtering")
    func searchIsDebounced() async throws {
        let viewModel = makeViewModel()
        await viewModel.load()
        let before = viewModel.viewState

        viewModel.search("tok")
        try await Task.sleep(for: .milliseconds(120))
        #expect(viewModel.viewState == before, "filtered before the debounce elapsed")

        try await Task.sleep(for: .milliseconds(400))
        #expect(Self.loaded(viewModel.viewState)?.others.map(\.name) == ["Tokyo"])
    }

    /// The reported bug: filtering wrote back into its own source list, so deleting a character
    /// never restored anything.
    @Test("Clearing the query restores the full catalogue")
    func clearingTheQueryRestoresEverything() async throws {
        let viewModel = makeViewModel()
        await viewModel.load()

        viewModel.search("tok")
        try await Task.sleep(for: .milliseconds(500))
        viewModel.search("")
        try await Task.sleep(for: .milliseconds(500))

        #expect(Self.loaded(viewModel.viewState)?.others.count == StubCityDataSource.sample.count)
    }

    /// Handing `ForEach` 200k rows is what made the list lag; the window is the fix.
    @Test("The list renders a page at a time and extends on demand")
    func loadMoreExtendsTheWindow() async throws {
        let cities = (0..<250).map {
            City(id: CityID("c\($0)"), name: "City \($0)", coordinate: Coordinate(latitude: 0, longitude: 0))
        }
        let viewModel = makeViewModel(cities: cities)
        await viewModel.load()

        #expect(Self.loaded(viewModel.viewState)?.others.count == CityListViewModelImpl.pageSize)
        #expect(Self.loaded(viewModel.viewState)?.totalOthers == 250)

        viewModel.loadMore()

        #expect(Self.loaded(viewModel.viewState)?.others.count == 200)
    }
}
