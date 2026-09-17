//
//  WeatherReading.swift
//  Hot or Cold
//

import Foundation

/// A temperature that knows its unit and its age. The server states how long a reading stands,
/// so the expiry is read from the response rather than guessed at by a constant here.
nonisolated struct WeatherReading: Hashable, Sendable {
    let temperature: Measurement<UnitTemperature>
    let observedAt: Date
    let validFor: Duration

    func isFresh(at now: Date) -> Bool {
        now.timeIntervalSince(observedAt) < TimeInterval(validFor.components.seconds)
    }
}

#if DEBUG
nonisolated extension WeatherReading {
    /// Tests and previews only. Production readings carry the server's own `interval`.
    static func fixture(
        celsius: Double = 15.1,
        observedAt: Date = .now,
        validFor: Duration = .seconds(900)
    ) -> WeatherReading {
        WeatherReading(
            temperature: Measurement(value: celsius, unit: .celsius),
            observedAt: observedAt,
            validFor: validFor
        )
    }
}
#endif
