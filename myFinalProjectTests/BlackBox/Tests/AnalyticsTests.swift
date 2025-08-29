//
//  AnalyticsTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//


import XCTest

@MainActor
final class AnalyticsTests: XCTestCase {
    var app: XCUIApplication!
    let emu = FirebaseEmulator()        // re-use your emulator helper if needed
    let fx  = Fixtures.self

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]
        app.launch()
    }

    // BB-AN-FR19-01 — Distribution chart populated
    func test_BB_AN_FR19_01_distribution_chart_populated() {
        let S = StatsRobot(app: app)
        S.gotoProfile().openStats()
        S.assertDistributionChartsRender()
    }

    // BB-AN-FR19-02 — Most/least worn sections present
    func test_BB_AN_FR19_02_most_least_worn_sections_present() {
        let S = StatsRobot(app: app)
        S.gotoProfile().openStats()
        S.assertUsageSectionsPresent()
    }

    // BB-AN-FR19-03 — Zero-data graceful (new user, no items)
    func test_BB_AN_FR19_03_zero_data_graceful() async throws {
        // Fresh account
        let email = fx.uniq("statsEmpty")
        try await emu.createUser(email: email, password: fx.strong)

        // Relaunch & sign in
        app.terminate()
        app.launchArguments = ["UI_TEST_MODE=1"]
        app.launch()
        AuthRobot(app: app)
            .enterSignin(email: email, password: fx.strong)
            .submitSignin()

        // Open Stats and assert empty states
        let S = StatsRobot(app: app)
        S.gotoProfile().openStats()
        S.assertZeroDataState()
    }

    // BB-AN-FR19-04 — Legend drill-down opens filter sheet
    func test_BB_AN_FR19_04_legend_drilldown_opens_sheet() {
        let S = StatsRobot(app: app)
        S.gotoProfile().openStats()
        S.tapFirstLegendAndAssertSheet()
    }

    // BB-AN-FR19-05 — Center label/selection behavior
    func test_BB_AN_FR19_05_center_label_selection_behavior() {
        let S = StatsRobot(app: app)
        S.gotoProfile().openStats()
        S.assertCenterLabelSelectionBehavior()
    }
}
