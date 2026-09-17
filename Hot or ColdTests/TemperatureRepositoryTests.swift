//
//  TemperatureRepositoryTests.swift
//  Hot or ColdTests
//

import Foundation
import Testing
@testable import Hot_or_Cold

@Suite("Temperature repository")
struct TemperatureRepositoryTests {
    /// The in-flight task is registered before the first `await`. Actors are re-entrant, so a
    /// `Bool` guard would let all fifteen callers past before any of them stored a result.
    @Test("Concurrent requests for one city share a single network call")
    func concurrentRequestsForSameCityDeduplicate() async throws {
        let client = StubWeatherClient(result: .success(12.5), delay: .milliseconds(50))
        let repository = TemperatureRepository(client: client)
        let city = StubCityDataSource.sample[0]

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<15 {
                group.addTask { _ = try? await repository.temperature(for: city) }
            }
        }

        #expect(client.callCount == 1)
    }

    /// The batch/lazy split: small catalogues warm up front, large ones fetch per row as they
    /// scroll into view. Batching 200k cities would be 200k requests on launch.
    @Test("Prefetch warms a small catalogue but no-ops above the threshold")
    func prefetchSwitchesStrategyAtTheThreshold() async throws {
        let small = StubWeatherClient()
        await TemperatureRepository(client: small).prefetch(StubCityDataSource.sample)
        #expect(small.callCount == StubCityDataSource.sample.count)

        let large = StubWeatherClient()
        let cities = (0...TemperatureRepository.prefetchThreshold).map {
            City(id: CityID("c\($0)"), name: "City \($0)", coordinate: Coordinate(latitude: 0, longitude: 0))
        }
        await TemperatureRepository(client: large).prefetch(cities)
        #expect(large.callCount == 0)
    }
}
