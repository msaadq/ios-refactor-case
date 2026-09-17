//
//  CitySnapshotTests.swift
//  Hot or ColdTests
//

import Foundation
import SnapshotTesting
import SwiftUI
import Testing
@testable import Hot_or_Cold

/// Baselines are device- and OS-specific — these were recorded on iPhone 17 / iOS 27.0, and an
/// unpinned run produces diff noise across the whole suite instead of one honest failure.
/// Re-record with `SNAPSHOT_RECORD=1`; a committed `record: .all` would make every test pass.
@MainActor
@Suite(
    "City screens",
    .snapshots(record: ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == nil ? .missing : .all)
)
struct CitySnapshotTests {
    private static let oslo = StubCityDataSource.sample[0]
    private static let tromso = StubCityDataSource.sample[1]
    private static let tokyo = StubCityDataSource.sample[2]

    private static let warm: [CityID: RowTemperature] = [
        oslo.id: .loaded(.fixture(celsius: 13.4)),
        tromso.id: .loaded(.fixture(celsius: -2.0)),
        tokyo.id: .failed
    ]

    private func list(
        _ viewState: CityListViewState,
        favorites: Set<CityID> = [],
        locale: Locale = Locale(identifier: "en_GB")
    ) -> some View {
        CityList(coordinator: StubCoordinator(
            list: StubListViewModel(viewState: viewState, favorites: favorites, temperatures: Self.warm)
        ))
        .environment(\.locale, locale)
    }

    private var device: Snapshotting<AnyView, UIImage> {
        .image(layout: .device(config: .iPhone13))
    }

    // MARK: - List states

    @Test("Loading")
    func loading() {
        assertSnapshot(of: AnyView(list(.loading)), as: device)
    }

    @Test("Loaded, nothing favorited — one section, no 'All cities' header")
    func loadedWithoutFavorites() {
        assertSnapshot(
            of: AnyView(list(.loaded(favorites: [], others: StubCityDataSource.sample, totalOthers: 4))),
            as: device
        )
    }

    /// Both headers, a failed row beside successful ones, and a sub-zero reading.
    @Test("Loaded with favorites — two sections")
    func loadedWithFavorites() {
        assertSnapshot(
            of: AnyView(list(
                .loaded(favorites: [Self.tromso], others: [Self.oslo, Self.tokyo], totalOthers: 2),
                favorites: [Self.tromso.id]
            )),
            as: device
        )
    }

    @Test("A query matching nothing")
    func empty() {
        assertSnapshot(of: AnyView(list(.empty(query: "zzzz"))), as: device)
    }

    @Test("A failed load")
    func error() {
        assertSnapshot(of: AnyView(list(.error(message: "The Internet connection appears to be offline."))), as: device)
    }

    /// The regression a unit test cannot see: Bokmål changes the words *and* the numbers —
    /// "Favoritter" over "13,4 °C" where English renders "Favorites" over "13.4°C".
    @Test("Loaded in Bokmål")
    func loadedInNorwegian() {
        assertSnapshot(
            of: AnyView(list(
                .loaded(favorites: [Self.tromso], others: [Self.oslo, Self.tokyo], totalOthers: 2),
                favorites: [Self.tromso.id],
                locale: Locale(identifier: "nb_NO")
            )),
            as: device
        )
    }

    // MARK: - Detail

    /// Constructed straight from its ViewModel — no `NavigationStack` to stand up and no
    /// navigation to drive, which is what the destination factory bought.
    @Test("Detail screen, favorited")
    func detailFavorited() {
        let screen = NavigationStack {
            CityDetailScreen(viewModel: StubDetailViewModel(
                city: Self.oslo,
                temperature: .loaded(.fixture(celsius: 13.4)),
                isFavorite: true
            ))
        }
        .environment(\.locale, Locale(identifier: "en_GB"))

        assertSnapshot(of: AnyView(screen), as: device)
    }
}

// MARK: - Doubles

/// A settable `viewState` is the whole point: driving the real ViewModel into `.error` would
/// mean a failing data source, and into `.loading` a network call that never returns.
@MainActor
private final class StubListViewModel: CityListViewModel {
    var viewState: CityListViewState
    var navigationPath: [CityRoute] = []

    private let favorites: Set<CityID>
    private let temperatures: [CityID: RowTemperature]

    init(viewState: CityListViewState, favorites: Set<CityID>, temperatures: [CityID: RowTemperature]) {
        self.viewState = viewState
        self.favorites = favorites
        self.temperatures = temperatures
    }

    func temperature(for city: City) -> RowTemperature { temperatures[city.id] ?? .loading }
    func isFavorite(_ city: City) -> Bool { favorites.contains(city.id) }
    func handle(_ action: CityListAction) {}
    func load() async {}
    func rowAppeared(_ city: City) async {}
}

@MainActor
private final class StubDetailViewModel: CityDetailViewModel {
    let city: City?
    let temperature: RowTemperature
    let isFavorite: Bool

    init(city: City?, temperature: RowTemperature, isFavorite: Bool) {
        self.city = city
        self.temperature = temperature
        self.isFavorite = isFavorite
    }

    func load() async {}
    func toggleFavorite() {}
}

@MainActor
private struct StubCoordinator: CityCoordinator {
    let list: any CityListViewModel

    func makeListViewModel() -> any CityListViewModel { list }

    func makeDetailViewModel(for id: CityID) -> any CityDetailViewModel {
        StubDetailViewModel(city: nil, temperature: .loading, isFavorite: false)
    }
}
