//
//  WeatherClient.swift
//  Hot or Cold
//

import Foundation

/// The API is asked for Celsius, so the unit is known rather than carried.
typealias Celsius = Double

nonisolated enum WeatherError: Error, Equatable {
    case invalidURL
    case transport(String)
    case badStatus(Int)
    case decoding(String)
}

nonisolated protocol WeatherClient: Sendable {
    func currentTemperature(at coordinate: Coordinate) async throws -> Celsius
}

// MARK: - Live

nonisolated struct URLSessionWeatherClient: WeatherClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func currentTemperature(at coordinate: Coordinate) async throws -> Celsius {
        guard let url = Self.makeURL(for: coordinate) else { throw WeatherError.invalidURL }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw WeatherError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherError.badStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(CurrentWeatherDTO.self, from: data).celsius
        } catch {
            throw WeatherError.decoding(error.localizedDescription)
        }
    }

    static func makeURL(for coordinate: Coordinate) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m")
        ]
        return components?.url
    }
}

// MARK: - Stub

#if DEBUG
/// Counts calls so tests can assert that concurrent requests were deduplicated.
nonisolated final class StubWeatherClient: WeatherClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    private let result: Result<Celsius, WeatherError>
    private let delay: Duration

    var callCount: Int { lock.withLock { _callCount } }

    init(result: Result<Celsius, WeatherError> = .success(15.1), delay: Duration = .zero) {
        self.result = result
        self.delay = delay
    }

    func currentTemperature(at coordinate: Coordinate) async throws -> Celsius {
        lock.withLock { _callCount += 1 }
        if delay > .zero { try? await Task.sleep(for: delay) }
        return try result.get()
    }
}
#endif
