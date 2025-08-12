//
//  WeatherSuggestionView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//

import SwiftUI

struct WeatherSuggestionView: View {
    let date: Date
    var body: some View {
        Text("Weather suggestions for \(date.formatted(date: .abbreviated, time: .omitted))")
            .padding()
            .navigationTitle("Weather Ideas")
    }
}
