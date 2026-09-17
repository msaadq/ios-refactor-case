//
//  CityDetailScreen.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

struct CityDetailScreen: View {
    @State private var viewModel: any CityDetailViewModel

    /// Taken from the environment rather than `.autoupdatingCurrent`, so a locale override
    /// reaches the number as well as the words.
    @Environment(\.locale) private var locale

    init(viewModel: any CityDetailViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        content
            // `Text(_:)` over the string overload: the name is data, the fallback is a key.
            .navigationTitle(Text(viewModel.city?.name ?? String(localized: "cityDetail.title.fallback")))
            .toolbar { favoriteButton }
            .task { await viewModel.load() }
    }

    @ToolbarContentBuilder
    private var favoriteButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.city != nil {
                Button {
                    viewModel.toggleFavorite()
                } label: {
                    Label(
                        viewModel.isFavorite ? "city.favorite.remove" : "city.favorite.add",
                        systemImage: viewModel.isFavorite ? "star.fill" : "star"
                    )
                }
                .tint(.yellow)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.city != nil {
            VStack(spacing: 32) {
                temperature
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
            .padding(.horizontal)
        } else {
            // Reachable only if the catalogue changed under a pushed route.
            ContentUnavailableView("cityDetail.unavailable", systemImage: "mappin.slash")
        }
    }

    @ViewBuilder
    private var temperature: some View {
        switch viewModel.temperature {
        case .loading:
            ProgressView().controlSize(.large)
        case .loaded(let reading):
            Text(reading.localizedTemperature(in: locale))
                .font(.system(size: 80, weight: .thin))
                .contentTransition(.numericText())
        case .failed:
            Label("city.temperature.unavailable", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        CityDetailScreen(viewModel: PreviewCityCoordinator().makeDetailViewModel(for: CityID("oslo-no")))
    }
}
