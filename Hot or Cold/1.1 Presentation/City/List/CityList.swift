//
//  CityList.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

/// Row identity is scoped per section. `List` diffs identities across the whole list, so a
/// bare `city.id` in both sections reads as a move and flies the cell over its neighbours.
private enum RowID: Hashable {
    case favorite(CityID)
    case other(CityID)
}

struct CityList: View {
    @State private var viewModel: any CityListViewModel
    @State private var searchQuery = ""

    private let coordinator: any CityCoordinator

    init(coordinator: any CityCoordinator) {
        self.coordinator = coordinator
        self.viewModel = coordinator.makeListViewModel()
    }

    var body: some View {
        NavigationStack(path: navigationPath) {
            content
                .navigationTitle("Cities")
                .toolbarTitleDisplayMode(.inline)
                .toolbar { refreshButton }
                .navigationDestination(for: CityRoute.self) { destination(for: $0) }
                .searchable(text: $searchQuery, placement: .automatic, prompt: Text("Search cities"))
                .onChange(of: searchQuery) { _, newValue in viewModel.handle(.didChangeQuery(newValue)) }
                .task { await viewModel.load() }
        }
    }

    /// Written by hand rather than `$viewModel.navigationPath`: the ViewModel is held as an
    /// existential, which has no writable key path to project through.
    private var navigationPath: Binding<[CityRoute]> {
        Binding { viewModel.navigationPath } set: { viewModel.navigationPath = $0 }
    }

    @ViewBuilder
    private func destination(for route: CityRoute) -> some View {
        switch route {
        case .detail(let id):
            CityDetailScreen(viewModel: coordinator.makeDetailViewModel(for: id))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .initial, .loading:
            ProgressView()
        case .empty(let query):
            ContentUnavailableView.search(text: query)
        case .error(let message):
            ContentUnavailableView("Couldn't load cities", systemImage: "exclamationmark.triangle", description: Text(message))
        case .loaded(let favorites, let others, let totalOthers):
            List {
                if !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(favorites) {
                            CityRow(city: $0, viewModel: viewModel).id(RowID.favorite($0.id))
                        }
                    }
                }
                if !others.isEmpty {
                    Section(favorites.isEmpty ? "Cities" : "All cities") {
                        ForEach(others) {
                            CityRow(city: $0, viewModel: viewModel).id(RowID.other($0.id))
                        }

                        if others.count < totalOthers {
                            loadMoreFooter(shown: others.count, total: totalOthers)
                        }
                    }
                }
            }
        }
    }

    /// Its own row rather than `.onAppear` on the last city, so recycling cities cannot
    /// trigger a page load.
    private func loadMoreFooter(shown: Int, total: Int) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                ProgressView()
                Text("\(shown.formatted()) of \(total.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
        .onAppear { viewModel.handle(.didReachListEnd) }
    }

    @ToolbarContentBuilder
    private var refreshButton: some ToolbarContent {
        ToolbarItem {
            if viewModel.viewState == .loading {
                ProgressView()
            } else {
                Button { viewModel.handle(.didTapRefresh) } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
        }
    }
}

private struct CityRow: View {
    let city: City
    let viewModel: any CityListViewModel

    /// A `Button` rather than a `NavigationLink`, so the push goes through `handle(_:)` and is
    /// assertable without rendering. The chevron is what the link would have drawn for free.
    var body: some View {
        Button {
            viewModel.handle(.didSelectCity(city.id))
        } label: {
            HStack {
                Text(city.name)
                    .font(.headline)

                Spacer()

                temperature

                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: isFavorite ? .destructive : nil) {
                viewModel.handle(.didToggleFavorite(city.id))
            } label: {
                Label(favoriteActionTitle, systemImage: isFavorite ? "star.slash" : "star")
            }
            .tint(isFavorite ? .red : .yellow)
        }
        // The swipe is invisible to VoiceOver, so the same action is exposed to the rotor.
        .accessibilityAction(named: favoriteActionTitle) { viewModel.handle(.didToggleFavorite(city.id)) }
        .task { await viewModel.rowAppeared(city) }
    }

    private var isFavorite: Bool { viewModel.isFavorite(city) }

    private var favoriteActionTitle: String {
        isFavorite ? "Remove from favorites" : "Add to favorites"
    }

    @ViewBuilder
    private var temperature: some View {
        switch viewModel.temperature(for: city) {
        case .loading:
            ProgressView().controlSize(.small)
        case .loaded(let reading):
            Text(reading.localizedTemperature())
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Temperature unavailable")
        }
    }
}
