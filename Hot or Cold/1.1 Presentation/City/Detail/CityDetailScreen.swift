//
//  CityDetailScreen.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

struct CityDetailScreen: View {
    @State private var viewModel: any CityDetailViewModel

    init(viewModel: any CityDetailViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        content
            .navigationTitle(viewModel.city?.name ?? "City")
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.city != nil {
            VStack(spacing: 32) {
                temperature
                favoriteButton
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
            .padding(.horizontal)
        } else {
            // Reachable only if the catalogue changed under a pushed route.
            ContentUnavailableView("City unavailable", systemImage: "mappin.slash")
        }
    }

    @ViewBuilder
    private var temperature: some View {
        switch viewModel.temperature {
        case .loading:
            ProgressView().controlSize(.large)
        case .loaded(let celsius):
            Text("\(celsius, specifier: "%.1f")°")
                .font(.system(size: 80, weight: .thin))
                .contentTransition(.numericText())
        case .failed:
            Label("Temperature unavailable", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }

    private var favoriteButton: some View {
        Button {
            viewModel.toggleFavorite()
        } label: {
            Label(
                viewModel.isFavorite ? "Remove from favorites" : "Add to favorites",
                systemImage: viewModel.isFavorite ? "star.fill" : "star"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.isFavorite ? .red : .yellow)
    }
}

#Preview {
    NavigationStack {
        CityDetailScreen(viewModel: PreviewCityCoordinator().makeDetailViewModel(for: CityID("oslo-no")))
    }
}
