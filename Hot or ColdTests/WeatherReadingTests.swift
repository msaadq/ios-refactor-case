//
//  WeatherReadingTests.swift
//  Hot or ColdTests
//

import Foundation
import Testing
@testable import Hot_or_Cold

@Suite("Weather reading")
struct WeatherReadingTests {
    @Test("A reading expires at the end of the window the server stated")
    func freshnessFollowsTheServersInterval() {
        let observedAt = Date(timeIntervalSince1970: 1_000_000)
        let reading = WeatherReading.fixture(observedAt: observedAt, validFor: .seconds(900))

        #expect(reading.isFresh(at: observedAt.addingTimeInterval(899)))
        #expect(!reading.isFresh(at: observedAt.addingTimeInterval(901)))
    }

    /// The unit, timestamp and interval were decoded but unread until now. Having modelled the
    /// response faithfully then is why freshness cost no networking change.
    @Test("The wire format maps to a reading, unit and validity included")
    func wireFormatMapsToAReading() throws {
        let json = Data("""
        {"current_units": {"temperature_2m": "°C"},
         "current": {"time": "2026-09-16T21:00", "interval": 900, "temperature_2m": 15.1}}
        """.utf8)

        let reading = try JSONDecoder().decode(CurrentWeatherDTO.self, from: json).reading()

        #expect(reading.temperature == Measurement(value: 15.1, unit: UnitTemperature.celsius))
        #expect(reading.validFor == .seconds(900))
        #expect(reading.observedAt == ISO8601DateFormatter().date(from: "2026-09-16T21:00:00Z"))
    }

    /// We always request Celsius, so another symbol means the API changed under us — better to
    /// fail the decode than to relabel Fahrenheit as °C.
    @Test("An unrecognised unit fails the decode rather than assuming Celsius")
    func unknownUnitThrows() throws {
        let json = Data("""
        {"current_units": {"temperature_2m": "°R"},
         "current": {"time": "2026-09-16T21:00", "interval": 900, "temperature_2m": 15.1}}
        """.utf8)
        let dto = try JSONDecoder().decode(CurrentWeatherDTO.self, from: json)

        #expect(throws: WeatherError.self) { try dto.reading() }
    }

    /// Unit conversion is presentation, not transport: one Celsius reading renders as °F for a
    /// US reader with no second request. open-meteo's `temperature_unit` is global and
    /// single-valued, so fetching both would cost two round trips per city.
    @Test("One reading renders in each locale's own unit and separator")
    func readingFormatsPerLocale() {
        let reading = WeatherReading.fixture(celsius: 15.1)

        // The gap is U+00A0, not a space: Foundation keeps the unit from wrapping off the number.
        #expect(reading.localizedTemperature(in: Locale(identifier: "nb_NO")) == "15,1\u{00A0}°C")
        // 59.18 rounded by the fraction limit — a conversion must not invent precision.
        #expect(reading.localizedTemperature(in: Locale(identifier: "en_US")) == "59.2°F")
    }
}
