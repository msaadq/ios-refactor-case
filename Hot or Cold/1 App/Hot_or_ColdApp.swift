//
//  Hot_or_ColdApp.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

@main
struct Hot_or_ColdApp: App {
    @State private var viewModel = Hot_or_ColdApp.makeCityListViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }

    /// Composition root — the only place concrete implementations are chosen.
    private static func makeCityListViewModel() -> CityListViewModelImpl {
        var dataSource: CityDataSource = BundledCityDataSource()
        #if DEBUG
        if let synthetic = SyntheticCityDataSource.fromLaunchArguments {
            dataSource = synthetic
        }
        #endif

        return CityListViewModelImpl(
            repository: CityRepository(dataSource: dataSource, store: UserDefaultsFavoritesStore()),
            temperatureProvider: TemperatureRepository(client: URLSessionWeatherClient())
        )
    }
}
