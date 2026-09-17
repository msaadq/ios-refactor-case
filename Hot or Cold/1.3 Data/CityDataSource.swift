//
//  CityDataSource.swift
//  Hot or Cold
//

import Foundation

nonisolated protocol CityDataSource: Sendable {
    func loadCities() async throws -> [City]
}

// MARK: - Bundled

nonisolated struct BundledCityDataSource: CityDataSource {
    private let bundle: Bundle
    private let resource: String

    init(bundle: Bundle = .main, resource: String = "cities") {
        self.bundle = bundle
        self.resource = resource
    }

    /// `@concurrent` keeps decoding off the caller's actor — a `nonisolated async` function
    /// would otherwise inherit it and run the parse on the main thread.
    @concurrent
    func loadCities() async throws -> [City] {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            // A missing bundled resource is a build error, not a runtime condition the user can retry.
            assertionFailure("cities.json missing from \(bundle.bundleIdentifier ?? "bundle")")
            return []
        }

        do {
            return try JSONDecoder().decode([City].self, from: try Data(contentsOf: url))
        } catch {
            assertionFailure("cities.json failed to decode: \(error)")
            return []
        }
    }
}

// MARK: - Synthetic

#if DEBUG
/// Generates a large catalogue in memory so the 200k case can be exercised without
/// committing a ~10MB fixture. Driven by the `-StressCityCount` launch argument.
nonisolated struct SyntheticCityDataSource: CityDataSource {
    let count: Int

    static var fromLaunchArguments: SyntheticCityDataSource? {
        let value = UserDefaults.standard.integer(forKey: "StressCityCount")
        return value > 0 ? SyntheticCityDataSource(count: value) : nil
    }

    @concurrent
    func loadCities() async throws -> [City] {
        (0..<count).map { index in
            City(
                id: CityID("synthetic-\(index)"),
                name: Self.name(for: index),
                coordinate: Coordinate(
                    latitude: Double((index % 180) - 90),
                    longitude: Double((index % 360) - 180)
                )
            )
        }
    }

    private static let stems = [
        "Bergen", "Trondheim", "Stavanger", "Tromsø", "Ålesund",
        "Springfield", "Portland", "Richmond", "Salem", "Georgetown"
    ]

    private static func name(for index: Int) -> String {
        "\(stems[index % stems.count]) \(index / stems.count)"
    }
}

// MARK: - Stub

nonisolated struct StubCityDataSource: CityDataSource {
    let cities: [City]

    init(_ cities: [City] = StubCityDataSource.sample) {
        self.cities = cities
    }

    func loadCities() async throws -> [City] { cities }

    static let sample: [City] = [
        City(id: CityID("oslo-no"), name: "Oslo", coordinate: Coordinate(latitude: 59.91, longitude: 10.75)),
        City(id: CityID("tromso-no"), name: "Tromsø", coordinate: Coordinate(latitude: 69.65, longitude: 18.96)),
        City(id: CityID("tokyo-jp"), name: "Tokyo", coordinate: Coordinate(latitude: 35.68, longitude: 139.69)),
        City(id: CityID("paris-fr"), name: "Paris", coordinate: Coordinate(latitude: 48.85, longitude: 2.35))
    ]
}
#endif
