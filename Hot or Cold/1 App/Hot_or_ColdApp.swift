//
//  Hot_or_ColdApp.swift
//  Hot or Cold
//
//  Created by Sindre L. Øyen on 04/05/2026.
//

import SwiftUI

@main
struct Hot_or_ColdApp: App {
    @State private var coordinator: any CityCoordinator = LiveCityCoordinator.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
        }
    }
}
