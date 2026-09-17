//
//  WeatherReading+Formatted.swift
//  Hot or Cold
//

import Foundation

nonisolated extension WeatherReading {
    /// `usage: .weather` resolves the unit from the locale, so a US reader sees °F from the same
    /// Celsius reading. The fraction limit stops that conversion inventing precision the
    /// instrument never had.
    func localizedTemperature(in locale: Locale = .autoupdatingCurrent) -> String {
        temperature.formatted(
            .measurement(
                width: .abbreviated,
                usage: .weather,
                numberFormatStyle: .number.precision(.fractionLength(0...1))
            )
            .locale(locale)
        )
    }
}
