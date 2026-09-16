//
//  TemperatureRepository.swift
//  Hot or Cold
//

import Foundation

nonisolated protocol TemperatureProviding: Sendable {
    func temperature(for city: City) async throws -> Celsius
    /// No-ops above `TemperatureRepository.prefetchThreshold`; large catalogues fetch lazily per row.
    func prefetch(_ cities: [City]) async
}

/// An actor rather than `@MainActor`: this state is only ever read from async contexts,
/// so it does not need to contend with rendering.
actor TemperatureRepository: TemperatureProviding {
    static let prefetchThreshold = 100

    private let client: WeatherClient
    private var cached: [CityID: Celsius] = [:]
    private var inFlight: [CityID: Task<Celsius, Error>] = [:]

    init(client: WeatherClient) {
        self.client = client
    }

    func temperature(for city: City) async throws -> Celsius {
        if let hit = cached[city.id] { return hit }
        if let existing = inFlight[city.id] { return try await existing.value }

        // Registered before the first `await`, so concurrent callers join this task
        // instead of starting their own — actors are re-entrant, a Bool flag would not work.
        let task = Task { [client] in
            try await client.currentTemperature(at: city.coordinate)
        }
        inFlight[city.id] = task
        defer { inFlight[city.id] = nil }

        let value = try await task.value
        cached[city.id] = value
        return value
    }

    func prefetch(_ cities: [City]) async {
        guard cities.count <= Self.prefetchThreshold else { return }

        await withTaskGroup(of: Void.self) { group in
            for city in cities {
                group.addTask { _ = try? await self.temperature(for: city) }
            }
        }
    }
}
