//
//  ContentView.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

struct ContentView: View {
    let viewModel: CityListViewModel

    var body: some View {
        CityList(viewModel: viewModel)
    }
}

#Preview {
    ContentView(viewModel: CityListViewModelImpl(
        repository: CityRepository(dataSource: StubCityDataSource(), store: InMemoryFavoritesStore()),
        temperatureProvider: TemperatureRepository(client: StubWeatherClient())
    ))
}
