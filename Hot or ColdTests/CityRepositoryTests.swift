//
//  CityRepositoryTests.swift
//  Hot or ColdTests
//

import Foundation
import Testing
@testable import Hot_or_Cold

@MainActor
@Suite("City repository")
struct CityRepositoryTests {
    private func makeRepository(
        cities: [City] = StubCityDataSource.sample,
        store: FavoritesStore = InMemoryFavoritesStore()
    ) -> CityRepository {
        CityRepository(dataSource: StubCityDataSource(cities), store: store)
    }

    // MARK: - Sections

    @Test("Favorites are partitioned out of the main list")
    func favoritesArePartitionedFromOthers() async throws {
        let repository = makeRepository()
        try await repository.load()
        repository.toggleFavorite(CityID("tokyo-jp"))

        let sections = try await repository.sections(matching: "")

        #expect(sections.favorites.map(\.id) == [CityID("tokyo-jp")])
        #expect(!sections.others.contains { $0.id == CityID("tokyo-jp") })
    }

    /// The brief did not specify an ordering; newest-first is a deliberate choice, and it is why
    /// favorites are an ordered `[CityID]` rather than a `Set`.
    @Test("Favorites surface newest first, not in catalogue order")
    func favoritesAreOrderedNewestFirst() async throws {
        let repository = makeRepository()
        try await repository.load()
        repository.toggleFavorite(CityID("oslo-no"))
        repository.toggleFavorite(CityID("paris-fr"))

        let sections = try await repository.sections(matching: "")

        #expect(sections.favorites.map(\.id) == [CityID("paris-fr"), CityID("oslo-no")])
    }

    // MARK: - Persistence

    /// A second repository over the same store stands in for a relaunch. Uses the shipping
    /// `UserDefaults` store rather than the double — the ordering bug this guards lived in it.
    @Test("Favorites survive a relaunch, in the order they were added")
    func favoritesSurviveRelaunch() async throws {
        let suite = "favorites.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsFavoritesStore(defaults: defaults)

        let first = makeRepository(store: store)
        try await first.load()
        first.toggleFavorite(CityID("paris-fr"))
        first.toggleFavorite(CityID("oslo-no"))

        #expect(makeRepository(store: store).favorites == [CityID("paris-fr"), CityID("oslo-no")])
    }

    /// The star flips before the write lands, so a failed write has to put it back.
    @Test("A failed write rolls the optimistic toggle back")
    func failedSaveRollsBackOptimisticToggle() async throws {
        let repository = makeRepository(store: InMemoryFavoritesStore(failOnSave: true))
        try await repository.load()

        repository.toggleFavorite(CityID("oslo-no"))

        #expect(repository.isFavorite(CityID("oslo-no")) == false)
    }

    // MARK: - Search

    /// `ø` has no canonical decomposition, so `folding` alone leaves it intact. This failed when
    /// first written, and is what the `Latin-ASCII` transform in `searchFolded` exists for.
    @Test("Search reaches Norwegian letters typed as plain ASCII")
    func searchFoldsNordicLetters() async throws {
        let repository = makeRepository()
        try await repository.load()

        let sections = try await repository.sections(matching: "tromso")

        #expect(sections.others.map(\.name) == ["Tromsø"])
    }

    // MARK: - Scale

    /// The only assertion that catches `@concurrent` being dropped: the scan would still return
    /// the right answer, just on the main thread. Spins a main-actor counter to tell them apart.
    @Test("The 200k scan leaves the main actor free")
    func largeScanStaysOffTheMainActor() async throws {
        let cities = (0..<200_000).map {
            City(id: CityID("c\($0)"), name: "City \($0)", coordinate: Coordinate(latitude: 0, longitude: 0))
        }
        let ticker = MainActorTicker()
        ticker.start()
        await Task.yield()
        ticker.reset()

        let sections = try await CityRepository.sections(in: cities, matching: "city 1", favoriteRanks: [:])
        let ticks = ticker.stop()

        #expect(!sections.others.isEmpty)
        #expect(ticks > 100, "main actor was starved during the scan — only \(ticks) ticks")
    }
}

/// Spins the main actor so a scan that blocks it can be told apart from one that does not.
@MainActor
private final class MainActorTicker {
    private var count = 0
    private var task: Task<Void, Never>?

    func start() {
        task = Task { @MainActor in
            while !Task.isCancelled {
                count += 1
                await Task.yield()
            }
        }
    }

    func reset() { count = 0 }

    func stop() -> Int {
        task?.cancel()
        return count
    }
}
