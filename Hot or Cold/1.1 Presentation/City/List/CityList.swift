//
//  CityList.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

struct CityList: View {
    @State private var viewModel: CityListViewModel
    @State private var searchQuery = ""

    init(viewModel: CityListViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            List {
                // TODO: Show me this list in two sections.
                // TODO: The first section should show the favorited cities, and the second section should show the rest of the cities.
                ForEach(viewModel.cities) { city in
                    NavigationLink(value: city) {
                        HStack {
                            Text(city.name)
                                .font(.headline)

                            Spacer()

                            if let temperature = viewModel.temperature(for: city) {
                                Text("\(temperature, specifier: "%.1f")°")
                            }

                            // TODO: I want this to be swipeable instead, so that I can swipe left on a city to reveal the favorite button.
                            Button(action: { viewModel.toggleFavorite(city) }) {
                                Image(systemName: viewModel.favorites.contains(city.id) ? "star.fill" : "star")
                            }
                        }
                    }
                    .task {
                        await viewModel.fetchTemperature(for: city)
                    }
                }
            }
            .navigationTitle("Cities")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.loadCities() }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .navigationDestination(for: City.self) { city in
                CityDetailScreen(city: city)
            }
            .searchable(text: $searchQuery, placement: .automatic, prompt: Text("Search cities"))
            .onChange(of: searchQuery) { _, newValue in
                viewModel.filterCities(query: newValue)
            }
            .task {
                await viewModel.loadCities()
                await viewModel.warmUpCache()
            }
        }
    }
}
