//
//  CityListViewModel.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

protocol CityListViewModel {
    var cities: [City] { get }
    // TODO: When filtering favorites, treat the list of cities as if it had 200.000 entries. Make sure the UI would remain responsive.
    var favorites: Set<String> { get }
    var isLoading: Bool { get }

    func loadCities()
    func warmUpCache() async
    func fetchTemperature(for city: City, completion: @escaping @Sendable (Double?) -> Void)
    func toggleFavorite(_ city: City)
    func filterCities(query: String)
}

@Observable
class CityListViewModelImpl: CityListViewModel {
    var cities: [City] = []
    var favorites: Set<String> = []
    var isLoading: Bool = false

    func loadCities() {
        Thread.printCurrentThreadInfo(prefix: "Loading cities")
        isLoading = true

        cities = [
            City(name: "Oslo", lat: 59.91, lon: 10.75),
            City(name: "Tokyo", lat: 35.68, lon: 139.69),
            City(name: "Lisbon", lat: 38.72, lon: -9.14),
            City(name: "New York", lat: 40.71, lon: -74.01),
            City(name: "Sydney", lat: -33.87, lon: 151.21),
            City(name: "Cairo", lat: 30.04, lon: 31.23),
            City(name: "Moscow", lat: 55.75, lon: 37.62),
            City(name: "Rio de Janeiro", lat: -22.91, lon: -43.17),
            City(name: "Cape Town", lat: -33.92, lon: 18.42),
            City(name: "Paris", lat: 48.85, lon: 2.35),
            City(name: "Berlin", lat: 52.52, lon: 13.40),
            City(name: "Madrid", lat: 40.42, lon: -3.70),
            City(name: "Rome", lat: 41.90, lon: 12.49),
            City(name: "Bangkok", lat: 13.75, lon: 100.51),
            City(name: "Dubai", lat: 25.20, lon: 55.27)
        ]

        isLoading = false
    }

    func warmUpCache() async {
        // Pre-warm the temperature cache so the first scroll feels snappy.
        try? await Task.sleep(for: .seconds(2))
        print("Cache warm-up complete")
    }

    func fetchTemperature(for city: City, completion: @escaping @Sendable (Double?) -> Void) {
        isLoading = true

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.lat)),
            URLQueryItem(name: "longitude", value: String(city.lon)),
            URLQueryItem(name: "current", value: "temperature_2m")
        ]
        guard let url = components?.url else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            Thread.printCurrentThreadInfo(prefix: "Fetching temperature for \(city.name).")

            self?.isLoading = false

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let temp = current["temperature_2m"] as? Double else {
                completion(nil)
                return
            }

            completion(temp)
        }.resume()
    }
    
    func toggleFavorite(_ city: City) {
        // TODO: Implement across-session persistence of favorites using your prefered method.
        if favorites.contains(city.name) {
            favorites.remove(city.name)
        } else {
            favorites.insert(city.name)
        }
    }
    
    func filterCities(query: String) {
        // TODO: Implement this search. The search should be debounced for 300 ms to avoid filtering on every keystroke.
        // Also, why is this behaving so weird? Fix it please 🙌
        print("Queried for: \(query)")
        self.cities = cities.filter {
            $0.name.lowercased().contains(query.lowercased())
        }
    }
}
