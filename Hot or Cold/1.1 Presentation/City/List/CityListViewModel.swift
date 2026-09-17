//
//  CityListViewModel.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

@MainActor
protocol CityListViewModel: AnyObject {
    var viewState: CityListViewState { get }
    var navigationPath: [CityRoute] { get set }

    func temperature(for city: City) -> RowTemperature
    func isFavorite(_ city: City) -> Bool

    func handle(_ action: CityListAction)

    /// Safe to call repeatedly — `.task` re-runs on every navigation.
    func load() async
    func rowAppeared(_ city: City) async
}

/// User intent, not view lifecycle. `.task` hooks stay `async` methods above, because those
/// contexts own their cancellation and the ViewModel should not re-spawn work it cannot tie
/// to the view's lifetime.
nonisolated enum CityListAction: Equatable, Sendable {
    case didChangeQuery(String)
    case didSelectCity(CityID)
    case didToggleFavorite(CityID)
    case didReachListEnd
    case didTapRefresh
}

nonisolated enum CityListViewState: Equatable, Sendable {
    case initial
    case loading
    /// `others` is the rendered window; `totalOthers` is how many matched in full.
    case loaded(favorites: [City], others: [City], totalOthers: Int)
    case empty(query: String)
    case error(message: String)
}

nonisolated enum RowTemperature: Equatable, Sendable {
    case loading
    case loaded(WeatherReading)
    case failed
}

@MainActor
@Observable
final class CityListViewModelImpl: CityListViewModel {
    static let searchDebounce: Duration = .milliseconds(300)
    /// Below this the paging path is inert, so the real catalogue never sees a footer.
    static let pageSize = 100

    private(set) var viewState: CityListViewState = .initial
    private(set) var temperatures: [CityID: RowTemperature] = [:]
    /// Owned here rather than by the `NavigationStack`, so a push is assertable state
    /// rather than something that only exists while rendering.
    var navigationPath: [CityRoute] = []

    private var query = ""
    private var allFavorites: [City] = []
    private var allOthers: [City] = []
    private var visibleCount = CityListViewModelImpl.pageSize
    private var hasLoaded = false

    @ObservationIgnored private let repository: CityRepository
    @ObservationIgnored private let temperatureProvider: TemperatureProviding
    @ObservationIgnored private var searchDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var sectionsTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(repository: CityRepository, temperatureProvider: TemperatureProviding) {
        self.repository = repository
        self.temperatureProvider = temperatureProvider
    }

    deinit {
        searchDebounceTask?.cancel()
        sectionsTask?.cancel()
        refreshTask?.cancel()
    }

    func handle(_ action: CityListAction) {
        switch action {
        case .didChangeQuery(let query): search(query)
        case .didSelectCity(let id): navigationPath.append(.detail(id))
        case .didToggleFavorite(let id): toggleFavorite(id)
        case .didReachListEnd: loadMore()
        case .didTapRefresh: refresh()
        }
    }

    func temperature(for city: City) -> RowTemperature {
        temperatures[city.id] ?? .loading
    }

    func isFavorite(_ city: City) -> Bool {
        repository.isFavorite(city.id)
    }

    func load() async {
        guard !hasLoaded else { return }
        await performLoad()
    }

    /// Rows re-appear constantly as the list recycles, so this refetches only once the server's
    /// own validity window has lapsed. A failed row stays failed until an explicit refresh
    /// rather than retrying on every scroll past.
    func rowAppeared(_ city: City) async {
        switch temperatures[city.id] {
        case .some(.loading), .some(.failed): return
        case .some(.loaded(let reading)) where reading.isFresh(at: .now): return
        case .none, .some(.loaded): break
        }

        temperatures[city.id] = .loading

        do {
            temperatures[city.id] = .loaded(try await temperatureProvider.temperature(for: city))
        } catch {
            temperatures[city.id] = .failed
        }
    }

    // MARK: - Actions

    /// Cancels the pending timer *and* any in-flight scan, so a superseded query can never
    /// land after a newer one.
    private func search(_ query: String) {
        searchDebounceTask?.cancel()
        sectionsTask?.cancel()

        searchDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.searchDebounce)
                guard !Task.isCancelled else { return }
                await self?.apply(query: query)
            } catch {
                // Cancelled by the next keystroke — expected, not a failure.
            }
        }
    }

    private func toggleFavorite(_ id: CityID) {
        repository.toggleFavorite(id)

        sectionsTask?.cancel()
        // Keeps the window, so the rows around the user's finger stay put.
        sectionsTask = Task { [weak self] in await self?.refreshSections(resetWindow: false) }
    }

    /// Re-windows an array we already hold — no filtering, no repository call.
    private func loadMore() {
        guard visibleCount < allOthers.count else { return }
        visibleCount += Self.pageSize
        emitState()
    }

    private func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in await self?.performLoad() }
    }

    // MARK: - Private

    private func performLoad() async {
        viewState = .loading

        do {
            try await repository.load()
        } catch {
            viewState = .error(message: error.localizedDescription)
            return
        }

        // Set only on success, so a load cancelled by navigation retries on return.
        hasLoaded = true

        await refreshSections()
        // Below the provider's threshold this warms every row up front; above it, a no-op.
        await temperatureProvider.prefetch(repository.allCities)
    }

    private func apply(query: String) async {
        self.query = query
        await refreshSections()
    }

    /// `resetWindow` is false when the catalogue is only re-partitioned, not re-queried.
    private func refreshSections(resetWindow: Bool = true) async {
        let sections: CityRepository.Sections
        do {
            sections = try await repository.sections(matching: query)
        } catch {
            return // superseded scan
        }

        // A short scan can finish before it notices cancellation, and it partitioned against
        // the favorites as they were when it started.
        guard !Task.isCancelled else { return }

        allFavorites = sections.favorites
        allOthers = sections.others
        if resetWindow { visibleCount = Self.pageSize }
        emitState()
    }

    /// Animated at the mutation site rather than with `.animation` on the List, which would put
    /// an implicit animation on the same rows the List is already diffing.
    private func emitState() {
        guard !allFavorites.isEmpty || !allOthers.isEmpty else {
            viewState = .empty(query: query)
            return
        }

        withAnimation {
            viewState = .loaded(
                favorites: allFavorites,
                others: Array(allOthers.prefix(visibleCount)),
                totalOthers: allOthers.count
            )
        }
    }
}
