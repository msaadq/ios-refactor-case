//
//  ContentView.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

struct ContentView: View {
    let coordinator: any CityCoordinator

    var body: some View {
        CityList(coordinator: coordinator)
    }
}

#Preview {
    ContentView(coordinator: PreviewCityCoordinator())
}
