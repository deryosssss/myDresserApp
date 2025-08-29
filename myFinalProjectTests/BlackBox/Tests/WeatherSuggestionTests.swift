//
//  WeatherSuggestionTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//


import XCTest

// WeatherSuggestionTests is a UI test suite for the weather-based outfit suggestion feature. It validates:
// Happy path: weather cards load and the base dress code locks after the first choice (FR15-01).
// API fallback: if the remote weather API is offline, the app falls back to a local generator and still shows cards (FR15-02).
// Cold weather bias: when the temperature is low (e.g., 5 °C), outfits prefer to include outerwear (FR15-03).
// It relies on WeatherRobot and launch flags to simulate different weather conditions

@MainActor
final class WeatherSuggestionTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]
        app.launch()
        NavRobot(app: app).gotoWeather()
    }

    // BB-WEATHER-FR15-01 — API happy path
    func test_BB_WEATHER_FR15_01_cards_appear_and_base_locks() {
        let wr = WeatherRobot(app: app)
        wr.assertCardsAppear()
        wr.assertDressCodeLockedAfterFirstPick()
    }

    // BB-WEATHER-FR15-02 — API fallback to local
    func test_BB_WEATHER_FR15_02_fallback_to_local_generator() {
        app.terminate()
        app.launchArguments = ["UI_TEST_MODE=1", "--weatherApi=offline"]
        app.launch()
        NavRobot(app: app).gotoWeather()
        WeatherRobot(app: app).assertCardsAppear()
    }

    // BB-WEATHER-FR15-03 — Cold bias outerwear
    func test_BB_WEATHER_FR15_03_cold_bias_prefers_outerwear() {
        app.terminate()
        app.launchArguments = ["UI_TEST_MODE=1", "--tempC=5"]
        app.launch()
        NavRobot(app: app).gotoWeather()
        XCTAssertTrue(app.images["weather.slot.outerwear.image"].waitForExistence(timeout: 8),
                      "Outerwear not included on cold bias")
    }
}
