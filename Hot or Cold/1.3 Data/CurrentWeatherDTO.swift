//
//  CurrentWeatherDTO.swift
//  Hot or Cold
//

import Foundation

/// Mirrors open-meteo's wire format so its vocabulary stops here — `temperature_2m` and
/// `current_units` never reach the domain.
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
    func reading() throws -> WeatherReading {
        guard let unit = Self.unit(for: currentUnits.temperature2m) else {
            throw WeatherError.decoding("unrecognised temperature unit '\(currentUnits.temperature2m)'")
        }
        guard let observedAt = Self.timestampFormatter.date(from: current.time) else {
            throw WeatherError.decoding("unparseable timestamp '\(current.time)'")
        }

        return WeatherReading(
            temperature: Measurement(value: current.temperature2m, unit: unit),
            observedAt: observedAt,
            validFor: .seconds(current.interval)
        )
    }

    private static func unit(for symbol: String) -> UnitTemperature? {
        switch symbol {
        case "°C": .celsius
        case "°F": .fahrenheit
        case "K": .kelvin
        default: nil
        }
    }

    /// Built per call because `DateFormatter` is not `Sendable`; this runs once per response,
    /// not per row. open-meteo omits the offset and defaults to GMT, so the zone is pinned here.
    private static var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }
}
