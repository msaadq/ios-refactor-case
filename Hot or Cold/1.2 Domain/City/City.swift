//
//  City.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import Foundation

// The project defaults to MainActor isolation. Domain values belong to no actor —
// without `nonisolated` their Hashable conformance is unusable from TemperatureRepository.

/// Stable across renames, unlike the display name — city names collide at scale.
nonisolated struct CityID: Hashable, Sendable, Codable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct Coordinate: Hashable, Sendable, Codable {
    let latitude: Double
    let longitude: Double
}

nonisolated struct City: Identifiable, Hashable, Sendable, Decodable {
    let id: CityID
    let name: String
    let coordinate: Coordinate
    /// Case- and diacritic-folded `name`, precomputed so filtering allocates nothing per comparison.
    let searchKey: String

    init(id: CityID, name: String, coordinate: Coordinate) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.searchKey = name.searchFolded
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude
    }

    /// `searchKey` is derived here rather than stored in JSON, so it cannot drift from `name`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(CityID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            coordinate: Coordinate(
                latitude: try container.decode(Double.self, forKey: .latitude),
                longitude: try container.decode(Double.self, forKey: .longitude)
            )
        )
    }
}

extension String {
    /// `Latin-ASCII` first: folding treats `ø`/`æ` as distinct letters rather than decorated
    /// ones, so `tromso` would never reach `Tromsø`. `locale: nil` keeps it device-independent.
    nonisolated var searchFolded: String {
        (applyingTransform(StringTransform("Latin-ASCII"), reverse: false) ?? self)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
