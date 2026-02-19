//
//  RecipeRecommenderApp.swift
//  RecipeRecommender
//
//  Created by 岡崎隼斗 on 2026/02/17.
//

import SwiftUI

@main
struct RecipeRecommenderApp: App {
    @State private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
                .onAppear {
                    locationManager.requestPermission()
                }
        }
    }
}
