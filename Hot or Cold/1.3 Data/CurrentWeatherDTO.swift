//
//  CurrentWeatherDTO.swift
//  Hot or Cold
//

import Foundation

/// Mirrors open-meteo's wire format so its vocabulary stops here. `time`, `interval`
/// and `currentUnits` are decoded though currently unused — `interval` is the server's
/// own validity window, and re-deriving them later would mean revisiting this layer.
nonisolated struct CurrentWeatherDTO: Decodable {
    struct Current: Decodable {
        let time: String
        let interval: Int
        let temperature2m: Double

        enum CodingKeys: String, CodingKey {
            case time, interval
            case temperature2m = "temperature_2m"
        }
    }

    struct Units: Decodable {
        let temperature2m: String

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
        }
    }

    let current: Current
    let currentUnits: Units

    enum CodingKeys: String, CodingKey {
        case current
        case currentUnits = "current_units"
    }
}

nonisolated extension CurrentWeatherDTO {
    var celsius: Celsius { current.temperature2m }
}
